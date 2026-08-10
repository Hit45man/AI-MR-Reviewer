variable "project" { type = string }
variable "env" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_username" { type = string }
variable "allowed_sg_ids" { type = list(string) }
variable "kms_key_arn" { type = string }

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.env}-pg"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project}-${var.env}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name       = "${var.project}-${var.env}-database-url"
  kms_key_id = var.kms_key_arn
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project}-${var.env}-pgvector"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.medium"

  allocated_storage     = 50
  max_allocated_storage = 200
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "mr_reviewer"
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false

  # After create: CREATE EXTENSION vector; (bootstrap job / manual)
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = "mr_reviewer"
    url      = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.this.address}:5432/mr_reviewer"
  })
}

output "endpoint" { value = aws_db_instance.this.address }
output "db_secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "security_group_id" { value = aws_security_group.rds.id }
