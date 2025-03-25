import boto3
import os

ec2 = boto3.client('ec2', region_name="your_region")

INSTANCE_ID = os.environ['INSTANCE_ID']  # Set this as an environment variable in Lambda

def lambda_handler(event, context):
    action = event.get("action", "").lower()
    
    if action == "start":
        response = ec2.start_instances(InstanceIds=[INSTANCE_ID])
        return {"status": "EC2 instance started", "response": response}
    
    elif action == "stop":
        response = ec2.stop_instances(InstanceIds=[INSTANCE_ID])
        return {"status": "EC2 instance stopped", "response": response}
    
    else:
        return {"error": "Invalid action. Use 'start' or 'stop'."}
