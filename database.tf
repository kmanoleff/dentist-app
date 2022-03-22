# generate a random password
resource "random_password" "master_password" {
  length  = 16
  special = false
}

# create the mysql rds instance
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  db_name              = "dentist"
  username             = "admin"
  password             = random_password.master_password.result
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  publicly_accessible  = true
}

# create secrets manager for the database credentials
resource "aws_secretsmanager_secret" "db_creds" {
  name = "db_creds"
}
resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id     = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
  "username": aws_db_instance.default.username,
  "password": random_password.master_password.result,
  "engine": "mysql",
  "host": aws_db_instance.default.address,
  "port": aws_db_instance.default.port,
  "database": aws_db_instance.default.db_name
  })
}