# Dentist App

AWS serverless microservice to set and review your next checkup.

## Infrastructure
Application uses [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli), an Infrastructure 
as Code tool, which supports AWS resources as well as building and packaging required dependencies.  

Lambda function code written in [Python](https://www.python.org/downloads/).

**Database** `database.tf`
- Builds a MySQL RDS instance
- Creates a Secrets Manager entry to obscure sensitive credentials as well as store them for use by the Lambda 
function code
- Defines an IAM policy that allows the Lambda function to query Secrets Manager for the credentials

**Lambda Function** `lambda.tf`
- `pip` installs the necessary dependencies to be packaged within the Lambda function
- Bundles the dependencies and function code within a `.zip` file
- Creates an S3 bucket to store the archive (`.zip`) file and uploads
- Creates the Lambda execution IAM role
- Enables CloudWatch logging from the Lambda function code

**API Gateway** `gateway.tf`
- Creates an API gateway for the Lambda function
- Creates permissions for the Lambda function code to be executed by API gateway
- Defines the API gateway routes and method endpoints
- Enables CloudWatch logging from the gateway

**Auth** `cognito.tf`
- Creates a Cognito user pool
- Defines the Auth flows
- Attaches the Cognito authorizer to the API gateway using JWT

### Function Code