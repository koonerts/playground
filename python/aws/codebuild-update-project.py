import boto3

codebuild = boto3.client('codebuild')
codebuild.update_project(name='', cache={'type':'NO_CACHE'})
