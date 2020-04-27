import datetime
import time
from dateutil import parser
import os
import json
import boto3
import uuid
import sys
sys.path.insert(0, 'package/')

def lambda_handler(event, context):
    securityhub = boto3.client('securityhub')
    t = datetime.datetime.now()
    #s = t.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3] + "Z"
    s = t.strftime("%Y-%m-%dT%H:%M:%SZ")
    ACCOUNT_ID = context.invoked_function_arn.split(":")[4]

    findings = []
    findings.append({
        'SchemaVersion': '2018-10-08',
        'Id': (uuid.uuid1()).hex,
        'ProductArn': 'arn:aws:securityhub:{}:{}:product/{}/default'.format("eu-central-1", ACCOUNT_ID, ACCOUNT_ID),
        'GeneratorId': 'haveibeenpwned-detector',
        'AwsAccountId': ACCOUNT_ID,
        'Types': ['foo', 'bar'],
        'FirstObservedAt': s,
        'LastObservedAt': s,
        'CreatedAt': s,
        'UpdatedAt': s,
        'Severity': {
            'Product': 10.0,
            'Normalized': 100
        },
        'Confidence': 100,
        'Criticality': 100,
        'Title': "Account Compromise",
        'Description': "Foobar description.",
        'ProductFields': {
            'Domain': "Domain",
            'IsFabricated': "IsFabricated",
            'IsRetired': "IsRetired",
            'IsSensitive': "IsSensitive",
            'IsSpamList': "IsSpamList",
            'IsVerified': "IsVerified",
            'LogoPath': "LogoPath",
            'PwnCount': "PwnCount"
        },
        'Resources': [
            {
                'Id': "ayoub.umoru@zerodotfive.com",
                'Type': 'Email Address'
            }
        ]
    })

    response = securityhub.batch_import_findings(
        Findings=findings
    )
    print(response)
