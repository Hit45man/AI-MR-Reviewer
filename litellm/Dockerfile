# Optional Dockerfile if you bake config into a custom image.
# Prefer mounting ConfigMap and using ghcr.io/berriai/litellm officially.
FROM ghcr.io/berriai/litellm:main-stable
COPY proxy_config.yaml /app/config.yaml
ENV LITELLM_CONFIG=/app/config.yaml
EXPOSE 4000
CMD ["--config", "/app/config.yaml", "--port", "4000"]
