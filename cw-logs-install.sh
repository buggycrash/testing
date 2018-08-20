#!/bin/bash
cd /opt/extra
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/AgentDependencies.tar.gz -O
tar xvf AgentDependencies.tar.gz -C /tmp/
sudo python ./awslogs-agent-setup.py --region us-gov-west-1 --dependency-path /tmp/AgentDependencies
rm /opt/extra/awslogs-agent-setup.py
rm /opt/extra/AgentDependencies.tar.gz
rm -rf /tmp/AgentDependencies*
