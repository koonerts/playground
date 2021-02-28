import boto3
from mypy_boto3_s3 import ServiceResource as S3Resource

s3Resource: S3Resource = boto3.resource('s3')
bucket = s3Resource.Bucket("")

print('Begin: Deleting bucket objects..')
bucket.object_versions.delete()
print ('Finished')