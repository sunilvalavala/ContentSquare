
variable "aws_subnet_staging" {
  description = "cidr block for  subnet of staging"
  }

resource "aws_subnet" "staging" {
  vpc_id     = aws_vpc.VPC.id
  cidr_block = var.aws_subnet_staging
  availability_zone = var.availability_zone[2]

  tags = {
    Name = "staging"
  }
}

# Create Route Table for staging

resource "aws_route_table" "StagingRouteTable" {
  vpc_id = aws_vpc.VPC.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
    
  }
  tags = {
    Name = "StagingRouteTable"
  }
}


# Associate subnets with the route table
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.staging.id
  route_table_id = aws_route_table.StagingRouteTable.id
}

# create security group for staging

resource "aws_security_group" "staging_internal" {
  name        = "allow_internal"
  description = "Allow internal traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC.cidr_block]
  }

  
  ingress {
    description = "web from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC.cidr_block]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.VPC.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_internal"
  }
}

# Network interface

resource "aws_network_interface" "web-server-nic-staging" {
  subnet_id       = aws_subnet.staging.id
 # private_ips     = ["10.0.3.50"]
  security_groups = [aws_security_group.staging_internal.id]
}


# create staging web server

resource "aws_instance" "webserverstaging" {
  ami               = var.ami
  instance_type     = "t2.micro"
  availability_zone = var.availability_zone[2]
  key_name          = var.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic-staging.id
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
    Name = "staging_web"
  }
}
