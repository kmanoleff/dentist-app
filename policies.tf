# the iam role policies and permissions needed for this app

# lambda execution role
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"
  assume_role_policy = jsonencode({
    Version     = "2012-10-17"
    Statement   = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Sid       = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# permission for execution from api gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dentist_app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# policy for retrieving database credentials from secrets manager
data "aws_iam_policy_document" "lambda_policies" {
  statement {
    actions   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_creds.arn]
    effect    = "Allow"
  }
}
resource "aws_iam_role_policy" "iam_policies" {
  policy = data.aws_iam_policy_document.lambda_policies.json
  role   = aws_iam_role.lambda_exec.id
}