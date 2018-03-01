#!/bin/bash

AWS_REGION=us-east-1
FUNCTION_NAME=POCLambdaFunction

info() {
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
	echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::$1"
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
}

info "Checking for CloudWatch log streams"
aws logs describe-log-streams \
    --log-group-name /aws/lambda/${FUNCTION_NAME} \
    --query 'logStreams[*].logStreamName' \
    --output table

info "Getting CloudWatch log stream entries"
aws logs describe-log-streams \
    --log-group-name /aws/lambda/${FUNCTION_NAME} \
    --query 'logStreams[*].logStreamName' \
    --output table | awk '{print $2}' | grep -v ^$ | tail -n +2 | \
        while read LOG_STREAM_NAME; do aws logs get-log-events \
        --log-group-name /aws/lambda/${FUNCTION_NAME} \
        --log-stream-name ${LOG_STREAM_NAME} --output text; done
