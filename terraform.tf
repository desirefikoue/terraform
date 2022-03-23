provider "aws" {
  region = "us-east-1"
}
# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "production 23"
  }
}
# IGW
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
}
# Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "prod"
  }
}
# Subnet
resource "aws_subnet" "subnet-1"{
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags = {
      "Name" = "prod-subnet"
    }
}
# Associate Subnet Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
# Security Groupe to allow 22,80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web-traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id
  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "HTTP from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "allow_web"
  }
}
# Network Interface with ip in the subnet that was created
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
# Assign a Elastic IP to the Network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
}
output "server-public-IP" {
  value = aws_eip.one.public_ip
  description = "The public IP address of the web server"
}
# Create ubuntu Server and install/enable apache
resource "aws_instance" "web-server-instance" {
  ami = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "projet-1key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  user_data = <<-EOF
        #!/bin/bash
        # sudo apt update -y
        # sudo apt install apache2 -y
        # sudo systemctl start apache2
        # sudo bash -c 'echo my first web server at $(hostname -f) > /var/www/html/index.html'
        echo "Hello, World at $(hostname -f)" > index.html
        nohup busybox httpd -f -p 8080 &
        EOF
    tags = {
      Name = "web-server"
    }
}