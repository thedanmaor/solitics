# main.tf

provider "aws" {
  region = "eu-west-1"
}

# Create VPC in eu-west-1
resource "aws_vpc" "vpc_eu_west_1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

provider "aws" {
  region = "eu-west-2"
}

# Create VPC in eu-west-2
resource "aws_vpc" "vpc_eu_west_2" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

provider "aws" {
  region = "eu-west-1"
}

# Create Transit Gateway
resource "aws_ec2_transit_gateway" "my_transit_gateway" {
  description = "My Transit Gateway"
}

# Attach VPCs to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_eu_west_1" {
  transit_gateway_id = aws_ec2_transit_gateway.my_transit_gateway.id
  vpc_id             = aws_vpc.vpc_eu_west_1.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_eu_west_2" {
  transit_gateway_id = aws_ec2_transit_gateway.my_transit_gateway.id
  vpc_id             = aws_vpc.vpc_eu_west_2.id
}

# Create route table for Transit Gateway
resource "aws_ec2_transit_gateway_route_table" "transit_gateway_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.my_transit_gateway.id

  route {
    cidr_block                    = aws_vpc.vpc_eu_west_1.cidr_block
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment_eu_west_1.id
  }

  route {
    cidr_block                    = aws_vpc.vpc_eu_west_2.cidr_block
    transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment_eu_west_2.id
  }
}
