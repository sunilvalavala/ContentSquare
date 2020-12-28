provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "region" {
description = "region to create aws resources"
type = string
}

variable "access_key" {
description = "access key login"
type = string
}

variable "secret_key" {
description = "secret access key"
type = string
}

variable "vpc_cidr_block" {
  description = "cidr block for your desired vpc"
  type = string
}

variable "aws_subnet_Prod01" {
  description = "cidr block for 1st subnet of production"
  }
  
  variable "availability_zone01_prod" {
    description = "AZ-1 of production"
  }      
  

variable "aws_subnet_Prod02" {
  description = "cidr block for 2nd subnet of production"
  }
  
  variable "availability_zone02_prod" {
    description = "AZ-2 of production"
  }      

   variable "availability_zone" {
    description = "All AZs used"
  }   

   variable "key_name" {
    description = "login pem file to be used"
  }   

   variable "ami" {
    description = "ami of your desired image"
  }   

  variable "ssl_certificate_id" {
    description = "arn of your ssl certificate"
  }
  
# create vpc
resource "aws_vpc" "VPC" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"
  tags = {
    Name = "ContentSquare"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.VPC.id
}

# Create Route Table
resource "aws_route_table" "RouteTable" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "CSRouteTable"
  }
}

# Create two production subnets
resource "aws_subnet" "Prod01" {
  vpc_id                  = aws_vpc.VPC.id
  #cidr_block = var.subnet_prefix
  cidr_block              = var.aws_subnet_Prod01
  availability_zone       = var.availability_zone01_prod
  map_public_ip_on_launch = true
  tags = {
    Name = "Prod01"
  }
}

resource "aws_subnet" "Prod02" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = var.aws_subnet_Prod02
  availability_zone       = var.availability_zone02_prod
  map_public_ip_on_launch = true
  tags = {
    Name = "Prod02"
  }
}

#  Create a NAT gateway
resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.Prod01.id
  tags = {
    Name = "NAT Gateway"
  }
}

# Associate subnets with the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Prod01.id
  route_table_id = aws_route_table.RouteTable.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.Prod02.id
  route_table_id = aws_route_table.RouteTable.id
}

# Create security group for Production

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    description = "https traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server01-nic-prod" {
  subnet_id       = aws_subnet.Prod01.id
  #private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_network_interface" "web-server02-nic-prod" {
  subnet_id       = aws_subnet.Prod02.id
  # private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server01-nic-prod.id
  # associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.IGW]

}

resource "aws_eip" "two" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server02-nic-prod.id
  # associate_with_private_ip = "10.0.2.50"
  depends_on                = [aws_internet_gateway.IGW]

}

resource "aws_security_group" "elb" {
  name   = "terraform-example-elb" # Allow all outbound
  vpc_id = aws_vpc.VPC.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "webserverprod01" {
  ami               = var.ami
  instance_type     = "t2.micro"
  availability_zone = var.availability_zone[0]
  key_name          = var.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server01-nic-prod.id
  }
  user_data = <<-EOF
               #!/bin/bash
               sudo apt update -y
               sudo apt-get install tcpdump
               sudo apt install curl
               sudo apt install htop
               sudo apt install apache2 -y
               sudo systemctl start apache2
               sudo bash -c 'echo welcome to contentsquare web-01 > /var/www/html/index.html'
               EOF
  tags = {
    Name = "Prod-web-server-01"
  }
}

resource "aws_instance" "webserverprod02" {
  ami               = var.ami
  instance_type     = "t2.micro"
  availability_zone = var.availability_zone[1]
  key_name          = var.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server02-nic-prod.id
  }
  user_data = <<-EOF
               #!/bin/bash
               sudo apt update -y
               sudo apt-get install tcpdump
               sudo apt install curl
               sudo apt install htop
               sudo apt install apache2 -y
               sudo systemctl start apache2
               sudo bash -c 'echo welcome to contentsquare web-02> /var/www/html/index.html'
               EOF
  tags = {
    Name = "Prod-web-server-02"
  }
}


######
# ELB
######
resource "aws_elb" "Prod_ApplicationLoadBalancer" {
  name    = "csloadBalancer"
  subnets = [aws_subnet.Prod02.id, aws_subnet.Prod01.id]

  # security_groups = ["sg-056d2aee9beaccac1"]
  security_groups = [aws_security_group.elb.id]
  internal        = false
  # availability_zones = ["us-east-1b","us-east-1a"]
  instances = [aws_instance.webserverprod01.id, aws_instance.webserverprod02.id]
  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  } 
  
  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = 443
    lb_protocol       = "https"
    instance_port     = 80
    instance_protocol = "http"
    ssl_certificate_id = var.ssl_certificate_id
  }
}
