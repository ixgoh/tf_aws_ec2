provider "aws" {
    region = "eu-north-1"
}

variable "subnet-cidr" {
    description = "subnet cidr block" 
}

resource "aws_vpc" "devel-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "development"
    }

}

resource "aws_subnet" "devel-subnet-1" {
    vpc_id = aws_vpc.devel-vpc.id
    cidr_block = var.subnet-cidr
    availability_zone = "eu-north-1a"
    tags = {
      Name = "devel-subnet-1"
    }
}
