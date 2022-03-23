# Dentist App

AWS serverless microservice to set and review your next checkup.

# Infrastructure
Application uses [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli), an Infrastructure 
as Code tool, which supports AWS resources as well as building and packaging required dependencies.  

Lambda function code written in [Python](https://www.python.org/downloads/).

**Database** [`database.tf`](https://github.com/kmanoleff/dentist-app/blob/main/database.tf)
- Builds a MySQL RDS instance
- Creates a Secrets Manager entry to obscure sensitive credentials as well as store them for use by the Lambda 
function code
- Defines an IAM policy that allows the Lambda function to query Secrets Manager for the credentials

**Lambda Function** [`lambda.tf`](https://github.com/kmanoleff/dentist-app/blob/main/lambda.tf)
- `pip` installs the necessary dependencies to be packaged within the Lambda function
- Bundles the dependencies and function code within a `.zip` file
- Creates an S3 bucket to store the archive (`.zip`) file and uploads
- Creates the Lambda execution IAM role
- Enables CloudWatch logging from the Lambda function code

**API Gateway** [`gateway.tf`](https://github.com/kmanoleff/dentist-app/blob/main/gateway.tf)
- Creates an API gateway for the Lambda function
- Creates permissions for the Lambda function code to be executed by API gateway
- Defines the API gateway routes and method endpoints
- Enables CloudWatch logging from the gateway

**Auth** [`cognito.tf`](https://github.com/kmanoleff/dentist-app/blob/main/cognito.tf)
- Creates a Cognito user pool
- Defines the Auth flows
- Attaches the Cognito authorizer to the API gateway using JWT

# Database Structure
`user` table
- `user_id` - PK
- `username` - the logged-in user's username
- `user_type` - FK to `user_type` table
- `email` , `phone`

`user_type` table
- `user_type_id` - PK
- `description` - can be of type `PATIENT` , `DOCTOR` , `RECEPTIONIST`

`appointment` table
- `appointment_id` - PK
- `patient_id` - FK to `user` table of the `PATIENT` requesting the appointment
- `doctor_id` - FK to `user` table of the `DOCTOR` performing the checkup
- `receptionist_id` - FK to `user` table of the `RECEPTIONIST` who scheduled the appointment

<img src="/demo_files/db.PNG" width="350" height="400">

# Function Code
Python lambda function code contained within `/lambda_function` directory

`handler.py` 
Entry point for the API.  Uses [Lambda Powertools Python](https://awslabs.github.io/aws-lambda-powertools-python/latest/)
to assist in digesting the Lambda event information such as the user (from the Cognito auth) and the http method.

Currently two simple endpoints exist `GET /appointment` and `POST /appointment`.  Based on the http method used in the 
request it will route to gather the appropriate data.

`dao.db_connect.py`
A common database connection module which defines the credentials (from Secrets Manager) and some common database
functions.  

`dao.dentist_repo.py`
Contains the SQL implementations for the database queries need to support the app.  For example, when retrieving appointments
it would get the `user.user_id` and the `user_type.description` linked to the Cognito user.  Then it would query the `appointment`
table for that user based on the proper FK (reference Database Structure section).

`utils.custom_excptions.py`
Custom exceptions that can be defined by developers to catch possible errors and give end users more detailed info
on the problem.

# Proof of Concept
This project has been deployed with terraform to my personal AWS account.  So some quick examples of the API in action, for example 

## No Auth
<img src="/demo_files/noauth.png" width="550" height="400">


## Getting Appointments
<img src="/demo_files/success.png" width="550" height="400">
