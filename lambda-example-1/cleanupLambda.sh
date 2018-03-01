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

info() {
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
	echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::$1"
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
}

info "Deleting local lambda bundle file: ${BUNDLE_FILE}"
rm -f ${BUNDLE_FILE} 

info "Deleting lambda function: ${FUNCTION_NAME}"
aws lambda delete-function \
    --region ${AWS_REGION} \
    --function-name ${FUNCTION_NAME} 

info "Deleting attached role policy: ${LAMBDA_IAM_ROLE_POLICY}"
aws iam delete-role-policy \
    --role-name ${LAMBDA_IAM_ROLE} \
    --policy-name ${LAMBDA_IAM_ROLE_POLICY}

rm -f ${LAMBDA_IAM_ROLE_POLICY}.json

info "Deleting role: ${LAMBDA_IAM_ROLE}"
aws iam delete-role \
    --role-name ${LAMBDA_IAM_ROLE}

rm -f ${LAMBDA_IAM_ROLE}.json

info "Purging S3 bucket notification configuration: ${REPO_NAME}"
aws s3api put-bucket-notification-configuration \
    --bucket ${REPO_NAME} \
    --notification-configuration="{}"

rm -f ${BUCKET_NOTIFICATION_CONFIG}.json

info "Deleting S3 bundle file: ${BUNDLE_FILE}"
aws s3 rm s3://${REPO_NAME}/${BUNDLE_FILE}

info "Deleting S3 bucket policy: ${REPO_NAME}"
aws s3api delete-bucket-policy --bucket ${REPO_NAME}

rm -f ${BUCKET_POLICY}.json

info "Deleting CloudWatch log streams"
aws logs describe-log-streams \
    --log-group-name /aws/lambda/${FUNCTION_NAME} \
    --query 'logStreams[*].logStreamName' \
    --output table | awk '{print $2}' | grep -v ^$ | tail -n +2 | \
        while read LOG_STREAM_NAME; do aws logs delete-log-stream \
        --log-group-name /aws/lambda/${FUNCTION_NAME} \
        --log-stream-name ${LOG_STREAM_NAME}; done

info "Checking for CloudWatch log streams"
aws logs describe-log-streams \
    --log-group-name /aws/lambda/${FUNCTION_NAME} \
    --query 'logStreams[*].logStreamName' \
    --output table
