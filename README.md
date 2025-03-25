AWS EC2 Start/Stop using Lambda & EventBridge
----------------------------------------------
This Terraform project provisions an AWS infrastructure where:

=> A Lambda function starts/stops an EC2 instance<br>
=> EventBridge triggers the Lambda function on a schedule<br>
=> CloudWatch Logs store execution logs<br>

Architecute Diagram
-------------------
![EC2-Lambda (1)](https://github.com/user-attachments/assets/77d18654-16fe-42e6-abbf-5b4cf1a04c57)

Resources Created
------------------
=> VPC with public and private subnets<br>
=> EC2 Instance in the public subnet<br>
=> Security Group allowing SSH and HTTP access<br>
=> IAM Role & Policy for Lambda to control EC2<br>
=> Lambda Function to start/stop EC2<br>
=> EventBridge Rules to trigger Lambda<br>

Prerequisites
-------------
=> AWS CLI configured<br>
=> Terraform installed<br>
=> AWS account with necessary permissions<br>
