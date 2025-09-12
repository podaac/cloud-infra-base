#!/bin/python3
import json
import subprocess
import sys
from pathlib import Path

def main():
    cw_config_path = Path('/opt/aws/amazon-cloudwatch-agent/bin/config.json')
    config_json = json.load(cw_config_path.open('r'))

    config_json['logs']['logs_collected']['files']['collect_list'].extend([{
        'file_path': '/var/log/cloud-init.log',
        'log_group_name': '/service/carpathia',
        'log_stream_name': '{instance_id}/cloud-init'
    },{
        'file_path': '/var/log/cloud-init-output.log',
        'log_group_name': '/service/carpathia',
        'log_stream_name': '{instance_id}/cloud-init-output'
    }, {
        'file_path': '/home/ssm-user/.bash_history',
        'log_group_name': '/service/carpathia',
        'log_stream_name': '{instance_id}/bash_history'
    }, {
        'file_path': '/var/log/messages',
        'log_group_name': '/service/carpathia',
        'log_stream_name': '{instance_id}/messages'
    }])

    Path('/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json').write_text(
        json.dumps(config_json, indent=4)
    )

    subprocess.run(
        ["systemctl", "restart", "amazon-cloudwatch-agent"],
        stderr=sys.stderr,
        stdout=sys.stdout,
        check=True
    )


if __name__ == "__main__":
    main()
