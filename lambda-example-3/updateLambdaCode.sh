#!/bin/bash

LAMBDA_IAM_ROLE=POCLambdaExecutionRole
LAMBDA_IAM_ROLE_POLICY=Logging
BUCKET_NOTIFICATION_CONFIG=LambdaFunctionConfigurations
BUCKET_POLICY=S3BucketPolicy

AWS_REGION=us-east-1
PYTHON_VERSION=python2.7
BUNDLE_FILE=poc-lambda.zip
FUNCTION_NAME=POCLambdaFunction
REPO_NAME=coryk-poc-repo
ACCOUNT_NO=472136333626
VIRTUAL_ENV=venv_lambda

info() {
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
	echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::$1"
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
}

info "Creating local lambda bundle file: ${BUNDLE_FILE}"
rm -f ${BUNDLE_FILE} 
cd ${VIRTUAL_ENV}/lib/${PYTHON_VERSION}/site-packages/
zip -r9 ../../../../${BUNDLE_FILE} *nothing
cd      ../../../../
zip -g ${BUNDLE_FILE} lambda_function.py

info "Uploading [${BUNDLE_FILE}] to S3 bucket: ${REPO_NAME}"
aws s3 cp ${BUNDLE_FILE} s3://${REPO_NAME}

info "Updating lambda function code: ${FUNCTION_NAME}"
aws lambda update-function-code \
    --region ${AWS_REGION} \
    --function-name ${FUNCTION_NAME} \
    --zip-file fileb://${BUNDLE_FILE} 
#    --s3-bucket ${REPO_NAME} \
#    --s3-key ${REPO_NAME}/${BUNDLE_FILE} 
