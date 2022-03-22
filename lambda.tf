provider "aws" {
  region = var.aws_region
}

locals {
  lambda_src_path = "${path.module}/lambda_function"
}

# actual application code files and the dependencies list for project
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

# create the s3 object with function code zip
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

# define the cloudwatch log group
resource "aws_cloudwatch_log_group" "dentist-app" {
  name = "/aws/lambda/${aws_lambda_function.dentist_app.function_name}"
  retention_in_days = 30
}