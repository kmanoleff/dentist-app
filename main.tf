provider "aws" {
  region = var.aws_region
}

locals {
  lambda_src_path = "${path.module}/lambda_function"
}

# Compute the source code hash, only taking into
# consideration the actual application code files
# and the dependencies list.
resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(local.lambda_src_path, "*.py"),
      fileset(local.lambda_src_path, "requirements.txt"),
      fileset(local.lambda_src_path, "core/**/*.py")
    ):
    filename => filemd5("${local.lambda_src_path}/${filename}")
  }
}

# install dependencies to be packaged with the Lambda function
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ${local.lambda_src_path}/requirements.txt -t ${local.lambda_src_path}/ --upgrade"
  }
  # re-run this if the dependencies or their versions have changed
  triggers = {
    dependencies_versions = filemd5("${local.lambda_src_path}/requirements.txt")
  }
}

# bucket to host lambda function code
resource "random_pet" "lambda_bucket_name" {
  prefix = "l"
  length = 1
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
  force_destroy = true
}

# create an archive form the Lambda source code
data "archive_file" "lambda_source_package" {
  type        = "zip"
  source_dir  = local.lambda_src_path
  output_path = "${path.module}/.tmp/${random_uuid.lambda_src_hash.result}.zip"

  excludes    = [
    "__pycache__",
    "core/__pycache__",
    "tests"
  ]
  # make sure dependencies are installed before creating archive
  depends_on = [null_resource.install_dependencies]
}

resource "aws_s3_object" "lambda_dentist_app" {
  depends_on = [null_resource.install_dependencies]
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "dentist-app.zip"
  source = data.archive_file.lambda_source_package.output_path
}

resource "aws_lambda_function" "dentist_app" {
  function_name = var.function_name
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_dentist_app.key
  runtime = "python3.8"
  handler = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_source_package.output_base64sha256
  role = aws_iam_role.lambda_exec.arn
}

# enable cloudwatch logs lambda function
resource "aws_cloudwatch_log_group" "dentist-app" {
  name = "/aws/lambda/${aws_lambda_function.dentist_app.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "dentist_app" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.dentist_app.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# gateway routes
resource "aws_apigatewayv2_route" "get_appointment" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /appointment"
  target    = "integrations/${aws_apigatewayv2_integration.dentist_app.id}"
}

resource "aws_apigatewayv2_route" "set_appointment" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /appointment"
  target    = "integrations/${aws_apigatewayv2_integration.dentist_app.id}"
}

# gateway logs
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dentist_app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "random_password" "master_password" {
  length  = 16
  special = false
}

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

resource "aws_secretsmanager_secret" "db_creds" {
  name = "db_creds"
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id     = aws_secretsmanager_secret.db_creds.id
  secret_string = <<EOF
{
  "username": "${aws_db_instance.default.username}",
  "password": "${random_password.master_password.result}",
  "engine": "mysql",
  "host": "${aws_db_instance.default.address}",
  "port": ${aws_db_instance.default.port},
  "database": "${aws_db_instance.default.db_name}"
}
EOF
}

# add secrets manager policy to role so secrets can be obtained thru code
resource "aws_iam_role_policy" "secret_manager_policy" {
  name = "secret_manager_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": "secretsmanager:DescribeSecret",
        "Resource": aws_secretsmanager_secret.db_creds.arn
    }]
  })
}

resource "aws_iam_role_policy" "secret_manager_policy_2" {
  name = "secret_manager_policy_2"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": "secretsmanager:GetSecretValue",
        "Resource": aws_secretsmanager_secret.db_creds.arn
    }]
  })
}


