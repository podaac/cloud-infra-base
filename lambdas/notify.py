#!/usr/bin/env python3
import boto3
from os import environ
import json
import logging
import re

logging.basicConfig(level=logging.INFO)
SNS_TOPIC_ARN = environ.get("SNS_TOPIC_ARN")

ec2_client = boto3.client("ec2")
ssm_client = boto3.client("ssm")
sns_client = boto3.client("sns")
lambda_client = boto3.client("lambda")

status_check_fail_re = re.compile(r'taken out of service in response to an EC2 instance status checks failure\.$')


def lambda_handler(event, context):
    tags = lambda_client.list_tags(
        Resource=context.invoked_function_arn
    )['Tags']

    environment = tags.get("Environment", "Unknown Environment")

    for record in event.get("Records"):
        event = json.loads(record.get("Sns", {}).get("Message", "{}"))
        process_message(event, environment)


def process_message(message, environment):
    if 'Service' not in message or message['Service'] != 'AWS Auto Scaling':
        logging.warning("Ignoring event from unsupported service")
        return

    logging.info(f"Processing event: {json.dumps(message)}")
    if message['Event'] != 'autoscaling:EC2_INSTANCE_TERMINATE':
        logging.warning(f"Ignoring unsupported event {message['Event']}")
        return

    if status_check_fail_re.search(message['Cause']):
        logging.info(f'Instance {message["EC2InstanceId"]} was terminated because it was unhealthy')
        logging.info(f'Sending notification to SNS topic: {SNS_TOPIC_ARN}')

        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'[{environment}] Unhealthy Instance Termination',
            Message=f'Carpathia instance {message["EC2InstanceId"]} in {environment} was terminated due to health check failure.'
        )
