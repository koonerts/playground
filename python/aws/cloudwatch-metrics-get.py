import boto3
from mypy_boto3_cloudwatch import Client as CloudWatchClient

cloudwatch: CloudWatchClient = boto3.client('cloudwatch')
cloudwatch.get_metric_data()