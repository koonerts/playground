import boto3

s3 = boto3.resource('s3')
bucket = s3.Bucket("")

print('Begin: Deleting bucket objects..')
bucket.object_versions.delete()
print ('Finished')

print('Deleting bucket')
bucket.delete()
print('Finished')