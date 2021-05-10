provider "aws" {
  region = "eu-north-1"
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "environment" {}
variable "ssh_public_key_location" {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    "Name" = "${var.environment}-vpc"
  }

}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    "Name" = "${var.environment}-subnet-1"
  }
}

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    "Name" = "${var.environment}-rtb"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    "Name" = "${var.environment}-igw"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}

# Firewall
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress = [
    {
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = []
    description = "SSH"
    from_port = 22
    protocol = "tcp"
    to_port = 22
    prefix_list_ids = null
    security_groups = null
    self = false
    },
    {
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = []
    description = "Nginx"
    from_port = 8080
    protocol = "tcp"
    to_port = 8080
    prefix_list_ids = null
    security_groups = null
    self = false
    }
  ]

  egress = [ {
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = []
    description = "All traffic"
    from_port = 0
    prefix_list_ids = []
    protocol = "-1"
    to_port = 0
    security_groups = null
    self = false
  } ]

  tags = {
    "Name" = "${var.environment}-sg"
  }
}

data "aws_ami" "amazon-linux-ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami" {
  value = data.aws_ami.amazon-linux-ami.id
}

resource "aws_key_pair" "ssh-key" {
  key_name = "aws-eu-1-key"
  public_key = file(var.ssh_public_key_location)
}


resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.amazon-linux-ami.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  user_data = <<EOF
                  #!/bin/bash
                  sudo yum update -y && sudo yum install -y docker
                  sudo systemctl start docker
                  sudo usermod -aG docker $USER
                  docker run -p 8080:80 nginx
              EOF

  tags = {
    "Name" = "${var.environment}-server"
  }
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

