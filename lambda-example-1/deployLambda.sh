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

info "Creating role: ${LAMBDA_IAM_ROLE}"
cat > ${LAMBDA_IAM_ROLE}.json <<EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOL

aws iam create-role \
    --role-name ${LAMBDA_IAM_ROLE} \
    --assume-role-policy-document file://${LAMBDA_IAM_ROLE}.json

info "Attatching role policy: ${LAMBDA_IAM_ROLE_POLICY}"
cat > ${LAMBDA_IAM_ROLE_POLICY}.json <<EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOL

aws iam put-role-policy \
    --role-name ${LAMBDA_IAM_ROLE} \
    --policy-name ${LAMBDA_IAM_ROLE_POLICY} \
    --policy-document file://${LAMBDA_IAM_ROLE_POLICY}.json

while true; do
    PN=$(aws iam get-role-policy \
        --role-name ${LAMBDA_IAM_ROLE} \
        --policy-name ${LAMBDA_IAM_ROLE_POLICY}|jq '.PolicyName'|tr -d '"')

    if [ "${PN}" == "${LAMBDA_IAM_ROLE_POLICY}" ]; then 
        break; 
    fi
done


info "Creating local lambda bundle file: ${BUNDLE_FILE}"
rm -f ${BUNDLE_FILE} 
#cd ${VIRTUAL_ENV}/lib/${PYTHON_VERSION}/site-packages/
#zip -r9 ../../../../${BUNDLE_FILE} *.nothere
#cd      ../../../../
zip -g ${BUNDLE_FILE} lambda_function.py

info "Creating S3 bucket: ${REPO_NAME}"
aws s3 mb s3://${REPO_NAME}

info "Uploading [${BUNDLE_FILE}] to S3 bucket: ${REPO_NAME}"
aws s3 cp ${BUNDLE_FILE} s3://${REPO_NAME}

info "Attatching S3 bucket policy: ${BUCKET_POLICY}"
cat > ${BUCKET_POLICY}.json <<EOL
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Sid" : "PublicReadGetObject",
            "Effect" : "Allow",
            "Principal" : "*",
            "Action" : ["s3:GetObject"],
            "Resource" : ["arn:aws:s3:::${REPO_NAME}/*"]
        }
    ]
}
EOL

aws s3api put-bucket-policy \
    --bucket ${REPO_NAME} \
    --policy file://${BUCKET_POLICY}.json

info "Creating lambda function: ${FUNCTION_NAME}"
aws lambda create-function \
    --region ${AWS_REGION} \
    --function-name ${FUNCTION_NAME} \
    --description ${FUNCTION_NAME} \
    --zip-file fileb://${BUNDLE_FILE} \
    --role arn:aws:iam::${ACCOUNT_NO}:role/${LAMBDA_IAM_ROLE} \
    --handler lambda_function.lambda_handler \
    --runtime ${PYTHON_VERSION} \
    --timeout 15 \
    --memory-size 1024 \
    --environment Variables="{\
        SP_LOGGING_LEVEL=INFO,\
        SP_BATCH_SIZE=200,\
        SP_BATCH_SCALE=4}"

while true; do
    LFN=$(aws lambda get-function \
        --function-name ${FUNCTION_NAME}|jq '.Configuration.FunctionName'|tr -d '"')
    if [ "${LFN}" == "${FUNCTION_NAME}" ]; then 
        break; 
    fi
done

info "Adding permissions to allow S3 to trigger lambda"
aws lambda add-permission \
    --region ${AWS_REGION} \
    --function-name ${FUNCTION_NAME} \
    --statement-id "S3InvokeLambda" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::${REPO_NAME} \
    --source-account ${ACCOUNT_NO} 

FN_ARN=$(aws lambda get-function --function-name POCLambdaFunction|jq ".Configuration.FunctionArn")

info "Adding S3 bucket notification configuration to trigger lambda"
cat > ${BUCKET_NOTIFICATION_CONFIG}.json <<EOL
{
    "LambdaFunctionConfigurations": [
        {
            "Id": "S3InvokeLambda",
            "LambdaFunctionArn": ${FN_ARN},
            "Events": [
                "s3:ObjectCreated:Put",
                "s3:ObjectCreated:Post",
                "s3:ObjectCreated:Copy",
                "s3:ObjectCreated:CompleteMultipartUpload"
            ],
            "Filter": {
                "Key": {
                    "FilterRules": [
                        {
                            "Name": "suffix",
                            "Value": ".csv"
                        },
                        {
                            "Name": "prefix",
                            "Value": "pcrf"
                        }
                    ]
                }
            }
        }
    ]
}
EOL

aws s3api put-bucket-notification-configuration \
    --bucket ${REPO_NAME} \
    --notification-configuration file://${BUCKET_NOTIFICATION_CONFIG}.json
