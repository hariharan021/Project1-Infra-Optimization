
#create three ec2 instances
resource "aws_instance" "instance_1" {

  ami             = "ami-0557a15b87f6559cf" # Ubuntu 20.04 LTS // us-east-1

  instance_type   = "t2.micro"

  security_groups = [aws_security_group.instances.name] 

  tags = {
    
    Name        = "Master"
  }

}
resource "aws_instance" "instance_2" {

  ami             = "ami-0557a15b87f6559cf" # Ubuntu 20.04 LTS // us-east-1

  instance_type   = "t2.micro"

  security_groups = [aws_security_group.instances.name]

  tags = {
    
    Name        = "Worker1"
  }

}
resource "aws_instance" "instance_3" {

  ami             = "ami-0557a15b87f6559cf" # Ubuntu 20.04 LTS // us-east-1

  instance_type   = "t2.micro"

  security_groups = [aws_security_group.instances.name] 

  tags = {
    
    Name        = "worker2"
  }

}

#Adding elastci ip to instances
resource "aws_eip" "add_eip-1" {
   instance = aws_instance.instance_1.id
   vpc = true
}
resource "aws_eip" "add_eip-2" {
   instance = aws_instance.instance_2.id
   vpc = true
}

resource "aws_eip" "add_eip-3" {
   instance = aws_instance.instance_3.id
   vpc = true
}

#using the default VPC

data "aws_vpc" "default_vpc" {

  default = true

}

data "aws_subnet_ids" "default_subnet" {

  vpc_id = data.aws_vpc.default_vpc.id

}


# creating security group rules for ingress and egress

resource "aws_security_group" "instances" {

  name = "instance-security-group"

}

resource "aws_security_group_rule" "allow_http_inbound" {

  type              = "ingress"

  security_group_id = aws_security_group.instances.id

  from_port   = 22

  to_port     = 22

  protocol    = "tcp"

  cidr_blocks = ["0.0.0.0/0"]

}
resource "aws_vpc_security_group_egress_rule" "egress" {

  security_group_id = aws_security_group.instances.id

  cidr_ipv4   = "0.0.0.0/0"

  from_port   = 0

  ip_protocol = "-1"

  to_port     = 0

}

#creating key-pair for ssh

resource "aws_key_pair" "key_tf" {

  key_name   = "tf_key"

  public_key = tls_private_key.rsa.public_key_openssh

}



# RSA key of size 4096 bits

resource "tls_private_key" "rsa" {

  algorithm = "RSA"

  rsa_bits  = 4096

}


#saving pem file locally

resource "local_file" "key_tf" {

  content  = tls_private_key.rsa.private_key_pem

  filename = "tf_key"

}

#creating target group for load balancer

resource "aws_lb_target_group" "loadbalancer-tg" {

  name     = "load-balancer-tg"

  port     = 80

  protocol = "HTTP"

  vpc_id   =  data.aws_vpc.default_vpc.id

  health_check {

    enabled             = true

    healthy_threshold   = 3

    interval            = 10

    matcher             = 200

    path                = "/"

    port                = "traffic-port"

    protocol            = "HTTP"

    timeout             = 3

    unhealthy_threshold = 2
  }

}

#attaching the target group with the instance

resource "aws_lb_target_group_attachment" "attachment-1" {

  target_group_arn = aws_lb_target_group.loadbalancer-tg.arn

  target_id        = aws_instance.instance_1.id
  port             = 80

}

#creating load balancer

resource "aws_lb" "front" {

  name               = "front"

  internal           = false

  load_balancer_type = "application"

  security_groups    = [aws_security_group.instances.id]

  subnets            = ["subnet-07d5dffeb841f1ea7","subnet-0a2a2b9fba499f7ec","subnet-04d1b0ff61787e58e","subnet-08f018f71b03fcded","subnet-0c49dfaca738fd614","subnet-0be65f730486736c6"] --- # put your subnets 
  
  enable_deletion_protection = false



  tags = {

    Environment = "front"

  }

}

#load balancer listener

resource "aws_lb_listener" "front_end" {

  load_balancer_arn = aws_lb.front.arn

  port              = "80"

  protocol          = "HTTP"



  default_action {

    type             = "forward"

    target_group_arn = aws_lb_target_group.loadbalancer-tg.arn

  }

}

