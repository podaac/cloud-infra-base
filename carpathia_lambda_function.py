#!/usr/bin/env python3
import json
import boto3
import os
import sys

ssm_client = boto3.client("ssm")
ec2_client = boto3.client("ec2")
autoscaling_client = boto3.client("autoscaling")

SSM_AMI_PARAMETER = os.environ.get("SSM_PARAMETER_FOR_AMI",False)
LAUNCH_TEMPLATE_NAME = os.environ.get("LAUNCH_TEMPLATE_NAME",False)
AUTO_SCALING_GROUP_NAME = os.environ.get("AUTO_SCALING_GROUP_NAME",False)

def lambda_handler(event, context):
    try:
        response = ssm_client.get_parameter(
            Name=SSM_AMI_PARAMETER, WithDecryption=True)
        new_ami_id = response["Parameter"]["Value"]
        print(f"NEW AMI ID: {new_ami_id}")

        try:
            lt_response = ec2_client.describe_launch_templates(
                LaunchTemplateNames=[LAUNCH_TEMPLATE_NAME]
            )

            launch_template_id = lt_response['LaunchTemplates'][0]['LaunchTemplateId']

            version_response = ec2_client.describe_launch_template_versions(
                LaunchTemplateId=launch_template_id,
                Versions=['$Latest']
            )

            launch_template_data = version_response['LaunchTemplateVersions'][0]['LaunchTemplateData']
            ami_id = launch_template_data.get('ImageId')
            print(f"CURRENT AMI ID {ami_id}")
        except Exception as e:
            print(f"Error checking launch template: {str(e)}")

        if new_ami_id == ami_id:
            return {"statusCode": 200, "body": f"Launch template '{LAUNCH_TEMPLATE_NAME}' already updated with AMI {new_ami_id}"}
        else:
            update_launch_template(new_ami_id)
            print(f"Starting ASG Instance Refresh")
            autoscaling_client.start_instance_refresh(
                AutoScalingGroupName=AUTO_SCALING_GROUP_NAME
            )

        return {"statusCode": 200, "body": f"Launch template '{LAUNCH_TEMPLATE_NAME}' updated with AMI {new_ami_id}"}

    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": "Internal Server Error"}

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
