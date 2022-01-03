provider "aws" {
    region = "us-west-1"
    access_key = "AKIAUZYDTIE3J42KN75V"
    secret_key = "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"
}

# Importing Cloudformation outputs to use as varivable

data "aws_cloudformation_export" "PrivateSubnet" {
  name = "Project-PrivateId"
}

data "aws_cloudformation_export" "PublicSubnet" {
    name = "Project-PubicId"
}

data "aws_cloudformation_export" "VPC" {
    name = "Project-VpcId"
}

# Launch Configuration

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = "ami-009726b835c24a3aa" # Ubuntu 18.04, SSD Volume Type
  instance_type = "t2.micro"
  key_name = "Sumi23"

  security_groups = [
    aws_security_group.elb_sg.id
  ]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/sh
    sudo apt-get update
    sudo apt-get install unzip tree
    sudo apt-get install -y python-pip
    pip install boto3
    sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6IK9BIT856h1MzACWCG43xC13uAf8z4ujp4zJn0aXt3/1Sp3mtKfba9XgPU7M9DaZocC+DEmTgBHTKKBGDg2uYCj/9DLVMRbT9gUbPQe6NxF7A6jQ+RWCEzzQuh0vvhi7Eecb3w5JWQM7V5Jiyc1mGx68NI44kzrdAOg5lO4iGIBIxX7I+n4LUI99jNsqRN9I0Xdmo28ib0C4lLtgboULuWk3VcHS9Gu1V7FWrC+1ycglDG5RATe0putsBl2ZIc4Hc4/5oSyT1Mal3PqESZa82Sz6u3rslgFHz3Tw0B4pGSMXriMPWv3Sr1Jd9vXptjv5GcUIMt5IVzFLKBbhyFnZ ubuntu@ip-10-50-0-49" >> /home/ubuntu/.ssh/authorized_keys
    EOF


  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scalling Group Creation

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 2
  desired_capacity     = 2
  max_size             = 5
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [ data.aws_cloudformation_export.PublicSubnet.value ]

  
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}

# ASG Policy

resource "aws_autoscaling_policy" "policy_up" {
  name = "policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_up" {
  alarm_name = "cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.policy_up.arn ]
}

resource "aws_autoscaling_policy" "policy_down" {
  name = "policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_down" {
  alarm_name = "cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.policy_down.arn ]
}

#Creating DB instance

resource "aws_instance" "ec2_private" {
  ami                         = "ami-009726b835c24a3aa"
  associate_public_ip_address = false
  instance_type               = "t2.micro"
  key_name                    = "vpc"
  subnet_id                   =  data.aws_cloudformation_export.PrivateSubnet.value 
  vpc_security_group_ids      = [
    aws_security_group.elb_sg.id
  ]

  user_data = <<-EOF
    #!/bin/sh
    sudo apt-get update
    sudo apt-get install unzip tree
    sudo apt-get install -y python-pip
    pip install boto3
    sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6IK9BIT856h1MzACWCG43xC13uAf8z4ujp4zJn0aXt3/1Sp3mtKfba9XgPU7M9DaZocC+DEmTgBHTKKBGDg2uYCj/9DLVMRbT9gUbPQe6NxF7A6jQ+RWCEzzQuh0vvhi7Eecb3w5JWQM7V5Jiyc1mGx68NI44kzrdAOg5lO4iGIBIxX7I+n4LUI99jNsqRN9I0Xdmo28ib0C4lLtgboULuWk3VcHS9Gu1V7FWrC+1ycglDG5RATe0putsBl2ZIc4Hc4/5oSyT1Mal3PqESZa82Sz6u3rslgFHz3Tw0B4pGSMXriMPWv3Sr1Jd9vXptjv5GcUIMt5IVzFLKBbhyFnZ ubuntu@ip-10-50-0-49" >> /home/ubuntu/.ssh/authorized_keys
    EOF

  tags = {
    "Name" = "DB Server"
  }

}

#Creating Elastic Load Balancer

resource "aws_security_group" "elb_sg" {
  name        = "elb_sg"
  description = "Allow HTTP traffic"
  vpc_id = data.aws_cloudformation_export.VPC.value

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ELB Security Group"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_sg.id
  ]
  subnets =  [ data.aws_cloudformation_export.PublicSubnet.value ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "TCP:22"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}


# End of Terraform