import boto3
import os
import zipfile


from mypy_boto3_codepipeline import Client as CodePipelineClient
from mypy_boto3_s3 import Client as S3Client, ServiceResource as S3Resource

codepipeline: 'CodePipelineClient' = boto3.client('codepipeline')
s3: 'S3Client' = boto3.client('s3')
s3Resource: 'S3Resource' = boto3.resource('s3')

pipeline_name = ''
pipeline_source_bucket = ''
pipeline_source_key_path = ''
tmp_dir = 'c:/my projects'


def get_git_change_list():
    git_change_list = set()

    dev_pipeline_state = codepipeline.list_pipeline_executions(pipelineName=pipeline_name)
    execution_summaries = sorted(dev_pipeline_state['pipelineExecutionSummaries'], key=lambda e: e['startTime'], reverse=True)
    for execution in execution_summaries:
        if execution['status'] == 'Failed':
            break
        else:
            pass
            # s3_bucket: str = source_artifact_dict["location"]["s3Location"]["bucketName"]
            # s3_key_path: str = source_artifact_dict["location"]["s3Location"]["objectKey"]

        revision_id = execution["sourceRevisions"][0]["revisionId"]
        for file_name in get_s3_source_git_change_list(revision_id):
            git_change_list.add(file_name)
    print(git_change_list)


def get_s3_source_git_change_list(version_id):
    zip_path = f''
    s3.download_file(pipeline_source_bucket, pipeline_source_key_path, zip_path, ExtraArgs={'VersionId': version_id})

    with zipfile.ZipFile(zip_path) as zip_file:
        folder_path = zip_path.replace('.zip', '')
        zip_file.extractall(path=folder_path)
        file_output_dir = os.fsencode(f'')

        for file in os.listdir(file_output_dir):
            file_name = os.fsdecode(file)
            file_path = os.path.join(file_output_dir.decode("utf-8"), file_name)
            with open(file_path, encoding="utf-8-sig") as f:
                return [line.rstrip().lower() for line in f]


# execution = codepipeline.get_pipeline_execution(pipelineName='bswift-aws-pipeline-uat', pipelineExecutionId="51ed02c5-1f71-49e7-a50a-95f57655580e")
# objVers = s3Resource.ObjectVersion(bucket_name='bswift-aws-cdk-pipeline-nonprod-repo', object_key='uat/bswift-aws.zip', id='vYexXytPPjRl0342x5620NnJpTvc.jOr')
# print(objVers.get())

get_git_change_list()
