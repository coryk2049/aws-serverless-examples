
#!/bin/bash

AWS_REGION=us-east-1
REPO_NAME=coryk-poc-repo
TEST_DATA=pcrf1.example.com_edr_B25_20170101000000_20170101000014.csv

info() {
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
	echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::$1"
    echo -e "[`date '+%m/%d/%Y-%H:%M:%S'`]::INFO::---------------------------------------------------"
}

info "Deleting [${TEST_DATA}] from S3 bucket: ${REPO_NAME}"
aws s3 rm s3://${REPO_NAME}/${TEST_DATA}

info "Uploading [${TEST_DATA}] to S3 bucket: ${REPO_NAME}"
aws s3 cp ${TEST_DATA} s3://${REPO_NAME}
