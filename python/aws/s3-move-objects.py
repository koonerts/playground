import boto3
from mypy_boto3_s3 import ServiceResource as S3Resource


s3Resource: S3Resource = boto3.resource('s3')
bucket = s3Resource.Bucket("113700261421-s3-logs")
toBucketName = ""
# objects = list(bucket.objects.all())
for obj in bucket.objects.filter(Prefix=toBucketName):
    if '/' not in obj.key:
        new_obj = s3Resource.Object(obj.bucket_name, f'{toBucketName}/{obj.key}').copy_from(CopySource={'Bucket': obj.bucket_name, 'Key': obj.key})
        print(f'Moved {obj.key} to {toBucketName}/{obj.key}')
        obj.delete()
        print(f'Deleted {obj.key}')
