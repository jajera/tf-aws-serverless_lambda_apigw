# tf-aws-serverless_lambda_apigw


# Commands


## Test lambda function
```sh
aws lambda invoke --region=ap-southeast-1 --function-name=$(terraform output -raw function_name) response.json
```

## Test api gateway base url
```sh
curl "$(terraform output -raw base_url)/hello"
```

## Test api gateway base url with parameter
```sh
curl "$(terraform output -raw base_url)/hello?Name=Terraform"
```
