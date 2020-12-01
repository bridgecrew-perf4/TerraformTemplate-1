terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}


# Configure the AWS Provider
provider "aws" {
  region     = "eu-west-2"
  shared_credentials_file = var.aws_credentials_filepath
}


// 1: Create vpc
resource "aws_vpc" "production-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

// 2: Create Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.production-vpc.id
}


// 3: Create Custom Route Table
resource "aws_route_table" "production-route-table" {
  vpc_id = aws_vpc.production-vpc.id

  route {
    cidr_block = var.all-non-local-addresses
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "production"
  }
}


// 4: Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.production-vpc.id
  cidr_block        = var.subnet_info[0].cidr_block
  availability_zone = var.subnet_info[0].availability_zone

  tags = {
    Name = var.subnet_info[0].name
  }
}


resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.production-vpc.id
  cidr_block        = var.subnet_info[1].cidr_block
  availability_zone = var.subnet_info[1].availability_zone

  tags = {
    Name = var.subnet_info[1].name
  }
}


// 5: Associate subnet with route Table
resource "aws_route_table_association" "route-table-a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.production-route-table.id
}


// 6: Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.production-vpc.id

  ingress {
    description = "HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.all-non-local-addresses]
  }

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.all-non-local-addresses]
  }

  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all-non-local-addresses]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all-non-local-addresses]
  }

  tags = {
    Name = "allow_web"
  }
}


// 7: Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}


// 8: Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.internet-gateway]
}


output "server_public_ip" {
  value = aws_eip.one.public_ip
}


// 9: Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  //  count = 1
  ami               = "ami-0e169fa5b2b2f88ae"
  instance_type     = var.ec2-instance-type
  availability_zone = "eu-west-2a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c "echo your very first web server > /var/www.html.index.html"
              EOF
  tags = {
    Name = "web-server"
  }

}

output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip
}


output "server_id" {
  value = aws_instance.web-server-instance.id
}
