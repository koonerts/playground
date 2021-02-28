import boto3
from mypy_boto3_lambda import Client as LambdaClient

client: LambdaClient = boto3.client('lambda')

layer_names = ['tj-test-dotnet-nonopt', 'tj-test-dotnet-opt']

for layer_name in layer_names:
    layer_versions = client.list_layer_versions(LayerName=layer_name)['LayerVersions']

    for lv in layer_versions:
        print(f'Deleting layer version: {layer_name}:{lv["Version"]}')
        client.delete_layer_version(LayerName=layer_name, VersionNumber=lv['Version'])
    print()

print('Finished')


