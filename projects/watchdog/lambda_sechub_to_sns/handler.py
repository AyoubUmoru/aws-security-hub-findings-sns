import sys
import boto3
import os
sys.path.insert(0, 'package/')


def lambda_handler(event, context):

    detail = event['detail']
    for finding in detail['findings']:

        severity = finding['ProductFields']['aws/securityhub/SeverityLabel']

        if severity == 'CRITICAL':
            handle_critical(finding)
        if severity == 'HIGH':
            handle_high(finding)


def generateFindingMessage(finding):
    accountid = finding['AwsAccountId']
    generatorid = finding['GeneratorId']
    title = finding['Title']
    description = finding['Description']
    ressources = finding['Resources']
    severity = finding['ProductFields']['aws/securityhub/SeverityLabel']

    findingText = ('New finding {} in {} with severity {} from {}'.format(
        title, accountid, severity, generatorid))
    print('Affected Ressources: {}'.format(ressources))

    return findingText


def handle_critical(finding):
    print('critical finding')
    findingText = generateFindingMessage(finding)
    print(findingText)

    sns = boto3.client('sns')
    response = sns.publish(
        TopicArn=os.getenv('snscritical'),
        Message=findingText,
    )


def handle_high(finding):
    print('high finding')
    findingText = generateFindingMessage(finding)
    print(findingText)

    sns = boto3.client('sns')
    response = sns.publish(
        TopicArn=os.getenv('snshigh'),
        Message=findingText,
    )

