provider "aws" {
  region = var.aws_region
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "random_id" "id" {
  byte_length = 2
  prefix      = var.project_name
}

locals {
  name_prefix          = random_id.id.dec
  my_ip                = chomp(data.http.myip.response_body)
  lambda_function_name = local.name_prefix
}

resource "aws_vpc" "this" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = local.name_prefix
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = local.name_prefix
  }
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_subnet" "this" {
  count = var.aws_az_count

  cidr_block              = cidrsubnet(cidrsubnet(var.aws_vpc_cidr, 4, 0), 4, count.index + 1)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-${count.index + 1}"
  }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "this" {
  count = var.aws_az_count

  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = aws_route_table.this.id
}

# Create a NAT Gateway in the public subnet
resource "aws_eip" "natgw" {
  depends_on = [aws_internet_gateway.this]

  domain               = "vpc"
  network_border_group = ""

  tags = {
    Name = "${local.name_prefix}-natgw"
  }
}

resource "aws_nat_gateway" "this" {
  depends_on = [aws_internet_gateway.this]

  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.this[0].id
}

# Create a private subnet
resource "aws_subnet" "private_lambda" {
  vpc_id     = aws_vpc.this.id
  cidr_block = cidrsubnet(cidrsubnet(var.aws_vpc_cidr, 4, 1), 4, 0)
}

# Create a route table for the private subnet
resource "aws_route_table" "private_lambda" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "private_lambda" {
  subnet_id      = aws_subnet.private_lambda.id
  route_table_id = aws_route_table.private_lambda.id
}
