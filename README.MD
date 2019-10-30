### Message delivery service

This project is a codebase to provision a serverless restful api to notify users and to get messages delivered to a certain user

## IaaC

This codebase does not have a CI/CD pipeline yet.

Commands used heavily are :
zip
terraform init
terraform plan
terraform apply

A pipeline should have the following steps:
npm install
npm test
zip
upload zip
deploy (terraform apply)

The project uses Terraform as a DSL with aws provider to provision an API Gateway with lambda, sns topic, cloudwatch logs and manages the security with API key

## Deployment

Export your aws access key and security ids to run the terraform deployments.

The deployment will need two inputs
user number
servie version

## Testing

Unit and integration tests are not implemented yet.

The deployment will export two outputs:
base_url
api_key

Please run the following command to test:
curl -X GET \
  api_base_url \
  -H 'x-api-key: your_api_key 