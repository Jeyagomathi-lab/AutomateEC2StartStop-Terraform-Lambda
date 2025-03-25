# 1) Create vpc
resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/24"
}

# 2) Create public and private subnet for 2 AZ
/*
CIDR calculation
VPC = 10.0.0.0/24 --> total 256 IPs range from (10.0.0.0 - 10.0.0.255)
subnet mask = 24 so first 3 segment of IPs will static i.e 10.0.0 --> static last segment will change from 0-255
2^(32-subnetmask) 
2^(32-24) =256

Subnet --> split into 2 public and private so 256/2 = 128 each
Subnet 1 (public)--> 128 --> 10.0.0.0/25 --> 2^(32-25) = 128 --> IP Range 10.0.0.0 - 10.0.0.127
Subnet 2 (private)--> 128 --> 10.0.0.128/25 --> 2^(32-25) = 128 --> IP Range 10.0.0.128 - 10.0.0.255

*/
resource "aws_subnet" "my_public_subnet" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.0.0/25"
    availability_zone = var.az_one
}

resource "aws_subnet" "my_private_subnet" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.0.128/25"
    availability_zone = var.az_two
}

# 3) Create security group
resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow inbound SSH access (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTP access (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 4) Launch EC2
resource "aws_instance" "my_ec2" {
    instance_type = var.instance_type
    ami = var.ami
    vpc_security_group_ids = [aws_security_group.my_sg.id]
    subnet_id = aws_subnet.my_public_subnet.id
    tags = {
      Name = "Dev_Instance"
    }
}

# 5) Create IAM role for lambda
resource "aws_iam_role" "my_lambda_role" {
    name = "lamba_role_test"
    assume_role_policy = jsonencode(
        {
        Version = "2012-10-17",
        Statement = {
            Effect = "Allow"
            Action = "sts:AssumeRole",
            Principal = {"Service": "lambda.amazonaws.com"}
        }
        }
    )
}

# 6) Create policy for start and stop EC2 and provide log permission to cloud watch
resource "aws_iam_policy" "ec2_start_stop" {
    name = "lambda_ec2_start_stop"
    description = "Allow Lambda to start/stop EC2"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement =[
            {
            Effect = "Allow"
            Action = [
                "ec2:StartInstances",
                "ec2:StopInstances"
                ],
            Resource = "arn:aws:ec2:ap-south-1:${var.account_id}:instance/*"
            },
            {
                Effect = "Allow",
                Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
                ],
                Resource = "arn:aws:logs:ap-south-1:${var.account_id}:*"
            }
        ]
    }) 
}

# 7) Attach policy to role
resource "aws_iam_role_policy_attachment" "lambdaPolicy" {
    role = aws_iam_role.my_lambda_role.name
    policy_arn = aws_iam_policy.ec2_start_stop.arn  
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.my_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create cloud watch log
resource "aws_cloudwatch_log_group" "lambdaLog" {
    name              = "/aws/lambda/ec2startandtop"
    retention_in_days = 7
}

# 8) Create python zip for lambda function
data "archive_file" "zip_file" {
    type = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"    
}


# 9) Deploy a lambda function
resource "aws_lambda_function" "ec2_lambda" {
    function_name = "ec2startandtop"
    filename = data.archive_file.zip_file.output_path
    role = aws_iam_role.my_lambda_role.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.8"
    environment {
      variables = {
        INSTANCE_ID = aws_instance.my_ec2.id
      }
    }
}

# 10) Create cloud watch rule to trigger lambda
resource "aws_cloudwatch_event_rule" "myLambdaEventstop" {
    name                = "ec2-daily-shutdown"
    schedule_expression = "cron(30 16 * * ? *)" #04:30 PM UTC
}

resource "aws_cloudwatch_event_rule" "myLambdaEventstart" {
    name                = "ec2-daily-start"
    schedule_expression = "cron(30 04 * * ? *)"  #04:30 AM UTC
}

# 11) Attach CloudWatch Rule to Lambda
resource "aws_cloudwatch_event_target" "invoke_lambda" {
    rule = aws_cloudwatch_event_rule.myLambdaEventstart.id
    arn = aws_lambda_function.ec2_lambda.arn
    target_id = "InvokeLambdaToStartEc2"
    input = jsonencode({"action": "start"})
  
}

resource "aws_cloudwatch_event_target" "invoke_stop_ec2" {
    rule = aws_cloudwatch_event_rule.myLambdaEventstop.id
    arn = aws_lambda_function.ec2_lambda.arn
    target_id = "InvokeLambdaToStopEc2"
    input = jsonencode({"action": "stop"})
  
}

# 12) Allow CloudWatch to Trigger Lambda (Add EventBridge Trigger)
resource "aws_lambda_permission" "allowcloudwatchtostop" {
  statement_id  = "AllowExecutionFromCloudWatchStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.myLambdaEventstop.arn  
}

resource "aws_lambda_permission" "allowcloudwatchtostart" {
  statement_id  = "AllowExecutionFromCloudWatchStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.myLambdaEventstart.arn  
}
