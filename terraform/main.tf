#Credentials stored in my local for security
provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "/home/islam/.aws/credentials"
  profile                 = "default"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable env_prefix {}
variable my_ip{}

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr_block

  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}
#creating internet gatway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

#Routing traffic to internet

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.main.id  
  route {
    
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}


# associating subnet to a route table
resource "aws_route_table_association" "associate-sub" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.myapp-route-table.id
}

#creating security group

resource "aws_security_group" "sg-1" {
  name        = "sg1"
  description = "sg-1"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_ip]
  }
  ingress {
    description      = "http to VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}


resource "aws_instance" "example" {
  ami           = "ami-066333d9c572b0680"
  instance_type = "t2.micro"
  subnet_id= aws_subnet.public-subnet.id
  vpc_security_group_ids=[aws_security_group.sg-1.id]
  associate_public_ip_address= true
  key_name= "keypair"
  user_data= <<EOF
                 #!/bin/bash
                 sudo yum update -y && sudo yum install -y docker
                 sudo systemctl start docker
                 sudo usermod -aG docker ec2-user
                 docker run -p 8080:80 nginx 



             EOF 
  tags = {
    Name = "${var.env_prefix}-server"
  }
}