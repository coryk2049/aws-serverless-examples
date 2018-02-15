## lambda-example-1

Upload test EDR file to S3 bucket that should trigger Lambda function to parse, transform, and log in CloudWatch.

A very early stage of data ETL serverless design.

### Procedure
Post ```git clone```, the files below are of importance:
- ```setupLambdaEnv.sh``` - not required for this demo, just a placeholder for now
- ```deployLambda.sh``` - deploy Lambda function including required bundle code, IAM roles, policies, and S3 notification configurations
- ```uploadTestData.sh``` - upload test EDR file to S3 bucket
- ```checkCloudWatch.sh``` - monitor progress of Lambda function
- ```cleanupLambda.sh``` - tear down and clean up Lambda deployment
