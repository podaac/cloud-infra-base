#!/usr/bin/env python3
import boto3
from os import environ
import json
import logging

logging.basicConfig(level=logging.INFO)
ec2_client = boto3.client("ec2")
ssm_client = boto3.client("ssm")
sns_client = boto3.client("sns")
lambda_client = boto3.client("lambda")

SNS_TOPIC_ARN = environ.get("SNS_TOPIC_ARN")


def lambda_handler(event,context):
    if 'Service' not in event or event['Service'] != 'AWS Auto Scaling':
        logging.warning("Ignoring event from unsupported service")
        return

    logging.info("Processing event: %s", json.dumps(event))
    if event['LifecycleTransition'] != 'autoscaling:EC2_INSTANCE_TERMINATING':
        logging.warning("Ignoring event from unsupported lifecycle transition")
        return

    instance_statuses = ec2_client.describe_instance_status(
        InstanceIds=[event['EC2InstanceId']],
        IncludeAllInstances=True
    )
    
    tags = lambda_client.list_tags(
        Resource=context.invoked_function_arn
    )['Tags']

    health_status = instance_statuses['InstanceStatuses'][0]['InstanceStatus']['Status']

    if health_status == 'impaired':
        logging.info('Instance %s was terminated because it was unhealthy', event['EC2InstanceId'])
        logging.info('Sending notification to SNS topic: %s', SNS_TOPIC_ARN)

        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'[{tags.get("Environment", "Unknown Environment")}] Unhealthy Instance Termination',
            Message=f'Carpathia instance {event["EC2InstanceId"]} in {tags.get("Environment", "Unknown Environment")} was terminated due to health check failure.'
        )
