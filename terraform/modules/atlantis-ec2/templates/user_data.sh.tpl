#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/atlantis-bootstrap.log | logger -t atlantis-bootstrap -s 2>/dev/console) 2>&1

echo "==> Atlantis EC2 bootstrap starting"

dnf update -y
dnf install -y docker jq
# AWS CLI is usually preinstalled on AL2023; install if missing
if ! command -v aws >/dev/null 2>&1; then
  dnf install -y awscli || dnf install -y aws-cli
fi
systemctl enable --now docker
usermod -aG docker ec2-user || true

install -d -m 0755 /opt/atlantis/data
install -d -m 0700 /opt/atlantis/secrets
# Official Atlantis image runs as uid 100 / gid 1000
chown -R 100:1000 /opt/atlantis/data

cat > /opt/atlantis/repos.yaml <<'REPOS_EOF'
${repos_yaml}
REPOS_EOF

cat > /opt/atlantis/config.env <<EOF
AWS_REGION=${aws_region}
SECRETS_ARN=${secrets_arn}
ATLANTIS_URL=${atlantis_url}
REPO_ALLOWLIST=${repo_allowlist}
ATLANTIS_IMAGE=${atlantis_image}
EOF
chmod 600 /opt/atlantis/config.env

cat > /opt/atlantis/start.sh <<'START_EOF'
#!/bin/bash
set -euxo pipefail

# shellcheck disable=SC1091
source /opt/atlantis/config.env

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRETS_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

GH_USER=$(echo "$SECRET_JSON" | jq -r '.gh_user // empty')
GH_TOKEN=$(echo "$SECRET_JSON" | jq -r '.gh_token // empty')
GH_WEBHOOK_SECRET=$(echo "$SECRET_JSON" | jq -r '.gh_webhook_secret // empty')
GH_APP_ID=$(echo "$SECRET_JSON" | jq -r '.gh_app_id // empty')
GH_APP_KEY=$(echo "$SECRET_JSON" | jq -r '.gh_app_key // empty')

umask 077
ENV_FILE=/opt/atlantis/atlantis.env
cat > "$ENV_FILE" <<EOF
ATLANTIS_ATLANTIS_URL=$ATLANTIS_URL
ATLANTIS_REPO_ALLOWLIST=$REPO_ALLOWLIST
ATLANTIS_PORT=4141
ATLANTIS_REPO_CONFIG=/etc/atlantis/repos.yaml
ATLANTIS_DATA_DIR=/home/atlantis/.atlantis
EOF

[[ -n "$GH_WEBHOOK_SECRET" ]] && echo "ATLANTIS_GH_WEBHOOK_SECRET=$GH_WEBHOOK_SECRET" >> "$ENV_FILE"

docker rm -f atlantis >/dev/null 2>&1 || true

EXTRA_MOUNTS=()
if [[ -n "$GH_APP_ID" && -n "$GH_APP_KEY" ]]; then
  printf '%s\n' "$GH_APP_KEY" > /opt/atlantis/secrets/github-app-key.pem
  chmod 600 /opt/atlantis/secrets/github-app-key.pem
  echo "ATLANTIS_GH_APP_ID=$GH_APP_ID" >> "$ENV_FILE"
  echo "ATLANTIS_GH_APP_KEY_FILE=/etc/atlantis/github-app-key.pem" >> "$ENV_FILE"
  EXTRA_MOUNTS+=(-v /opt/atlantis/secrets/github-app-key.pem:/etc/atlantis/github-app-key.pem:ro)
elif [[ -n "$GH_USER" && -n "$GH_TOKEN" ]]; then
  echo "ATLANTIS_GH_USER=$GH_USER" >> "$ENV_FILE"
  echo "ATLANTIS_GH_TOKEN=$GH_TOKEN" >> "$ENV_FILE"
else
  echo "ERROR: set gh_user/gh_token or gh_app_id/gh_app_key in Secrets Manager ($SECRETS_ARN)"
  exit 1
fi

docker pull "$ATLANTIS_IMAGE"

# Data dir must be writable by the container user (uid 100)
install -d -m 0755 /opt/atlantis/data
chown -R 100:1000 /opt/atlantis/data

docker run -d --name atlantis --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -p 4141:4141 \
  -v /opt/atlantis/data:/home/atlantis/.atlantis \
  -v /opt/atlantis/repos.yaml:/etc/atlantis/repos.yaml:ro \
  "$${EXTRA_MOUNTS[@]}" \
  "$ATLANTIS_IMAGE" server

echo "Atlantis listening at $ATLANTIS_URL (webhook: $ATLANTIS_URL/events)"
START_EOF
chmod 0700 /opt/atlantis/start.sh

cat > /etc/systemd/system/atlantis.service <<'UNIT_EOF'
[Unit]
Description=Atlantis (Docker)
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/atlantis/start.sh
ExecStop=/usr/bin/docker stop atlantis
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT_EOF

systemctl daemon-reload
systemctl enable atlantis.service

# Retry a few times — secret version may land just after first boot
for i in $(seq 1 12); do
  if systemctl start atlantis.service; then
    echo "==> Atlantis started"
    break
  fi
  echo "Atlantis start attempt $i failed; retrying in 10s (set GitHub secrets if missing)"
  sleep 10
done

echo "==> Atlantis EC2 bootstrap complete"
echo "Webhook URL: ${atlantis_url}/events"
