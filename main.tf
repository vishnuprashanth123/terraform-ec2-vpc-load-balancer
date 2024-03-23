provider "aws" {
  region = "us-west-2"  
}

# Define the VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}
# Define an internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyIGW"
  }
}

# Define two public subnets in different availability zones
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"  # Availability zone 1
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"  # Availability zone 2
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ2"
  }
}

# Define a default route table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}

# Associate public subnets with the route table
resource "aws_route_table_association" "subnet_association_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "subnet_association_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.my_route_table.id
}
# Define security group for EC2 instances
resource "aws_security_group" "web_sg" {
  name        = "WebSecurityGroup"
  description = "Allow inbound HTTP traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "http"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Example EC2 instance1
resource "aws_instance" "example_instance1" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_az1.id
  security_groups = [aws_security_group.web_sg.name]
  user_data              = <<-EOF
                              #!/bin/bash
                              yum update -y
                              yum install -y httpd
                              systemctl start httpd
                              systemctl enable httpd
                            EOF

  tags = {
    Name = "ExampleInstance1"
  }
}
# Example EC2 instance2
resource "aws_instance" "example_instance2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_az2.id
  security_groups = [aws_security_group.web_sg.name]
  user_data              = <<-EOF
                              #!/bin/bash
                              yum update -y
                              yum install -y httpd
                              systemctl start httpd
                              systemctl enable httpd
                            EOF

  tags = {
    Name = "ExampleInstance2"
  }
}
# Define the Application Load Balancer
resource "aws_lb" "example_alb" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  tags = {
    Name = "ExampleALB"
  }
}

# Define listener for ALB
resource "aws_lb_listener" "example_listener" {
  load_balancer_arn = aws_lb.example_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example_target_group.arn
  }
}

# Define target group for ALB
resource "aws_lb_target_group" "example_target_group" {
  name     = "example-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = 80
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Register targets with the target group
resource "aws_lb_target_group_attachment" "example_target_group_attachment_az1" {
  target_group_arn = aws_lb_target_group.example_target_group.arn
  target_id        = aws_instance.example_instance_az1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "example_target_group_attachment_az2" {
  target_group_arn = aws_lb_target_group.example_target_group.arn
  target_id        = aws_instance.example_instance_az2.id
  port             = 80
}
