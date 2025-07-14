#!/usr/bin/env python3
import boto3
from datetime import datetime, timedelta, timezone
from os import environ

ssm_client = boto3.client("ssm")
ec2_client = boto3.client("ec2")
autoscaling_client = boto3.client("autoscaling")
sns_client = boto3.client("sns")
lambda_client = boto3.client("lambda")

SSM_AMI_PARAMETER = environ.get("SSM_PARAMETER_FOR_AMI", False)
LAUNCH_TEMPLATE_NAME = environ.get("LAUNCH_TEMPLATE_NAME", False)
AUTO_SCALING_GROUP_NAME = environ.get("AUTO_SCALING_GROUP_NAME", False)
ROTATION_PERIOD = timedelta(days=int(environ.get("ROTATION_PERIOD", 1)))


def lambda_handler(event, context):
    if ROTATION_PERIOD.days == 0:
        print(
            'Rotation period is set to 0 days. This function should not have '
            'been invoked. Please check your EventBridge rule configuration.'
        )
        return

    response = ssm_client.get_parameter(
        Name=SSM_AMI_PARAMETER, WithDecryption=True)
    new_ami_id = response["Parameter"]["Value"]
    print(f"NEW AMI ID: {new_ami_id}")

    template_versions = ec2_client.describe_launch_template_versions(
        LaunchTemplateName=LAUNCH_TEMPLATE_NAME,
        Versions=['$Latest']
    )

    latest_version = template_versions['LaunchTemplateVersions'][0]

    create_time = latest_version['CreateTime']
    current_time = datetime.now(timezone.utc)

    if create_time + ROTATION_PERIOD > current_time:
        print(
            f"Launch template '{LAUNCH_TEMPLATE_NAME}' was updated within the last {ROTATION_PERIOD.days} days. No update needed.")
        return

    launch_template_data = latest_version['LaunchTemplateData']
    ami_id = launch_template_data['ImageId']
    print(f"CURRENT AMI ID: {ami_id}")

    if new_ami_id == ami_id:
        print(
            f"Launch template '{LAUNCH_TEMPLATE_NAME}' already uses AMI {new_ami_id}. No update needed.")
    else:
        update_launch_template(new_ami_id)
        
        tags = lambda_client.list_tags(
            Resource=context.invoked_function_arn
        )['Tags']
        sns_client.publish(
            TopicArn=environ.get("SNS_TOPIC_ARN"),
            Subject=f"[{tags['Environment']}] AMI Rotation Notification",
            Message=(
                f"Updated launch template '{LAUNCH_TEMPLATE_NAME}' with new AMI: {new_ami_id}"
            )
        )

        print(f"Starting ASG Instance Refresh")
        autoscaling_client.start_instance_refresh(
            AutoScalingGroupName=AUTO_SCALING_GROUP_NAME
        )


def update_launch_template(ami_id):
    response = ec2_client.create_launch_template_version(
        LaunchTemplateName=LAUNCH_TEMPLATE_NAME,
        SourceVersion='$Latest',
        LaunchTemplateData={"ImageId": ami_id}
    )

    desc_response = ec2_client.describe_launch_templates(
        LaunchTemplateNames=[LAUNCH_TEMPLATE_NAME]
    )
    latest_version = desc_response["LaunchTemplates"][0]["LatestVersionNumber"]

    print(f"latest version: {latest_version}, {LAUNCH_TEMPLATE_NAME}")
    ec2_client.modify_launch_template(
        LaunchTemplateName=LAUNCH_TEMPLATE_NAME,
        DefaultVersion=str(latest_version)
    )
    print(
        f"Updated launch template '{LAUNCH_TEMPLATE_NAME}' with new AMI {ami_id}")
    return response
