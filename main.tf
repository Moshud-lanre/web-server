provider "aws" {
    region = "us-east-1"
}

variable "subnet_prefix" {
  description = "cidr block for subnet"
}

# resource "aws_instance" "terraform" {
#     ami     = "ami-0729e439b6769d6ab"
#     instance_type = "t2.micro"
#     tags = {
#         Name = "terraform"
#   }
# }

#Create a vpc
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "test-vpc"
  }
}
#Create a subnet
resource "aws_subnet" "test" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = var.subnet_prefix[0].name
  }
}
# create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-vpc.id
}
#Create a custom route table
resource "aws_route_table" "test" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "test-gw"
  }
}

#Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.test.id
  route_table_id = aws_route_table.test.id
}
# create a Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "allow_web"
  }
}

#Create a network Interface with an IP in the subnet that was created
resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.test.id
  private_ips = ["10.0.5.34"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign EIP(external Ip) to the network interface created
resource "aws_eip" "o" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id 
  associate_with_private_ip = "10.0.5.34"
  depends_on = [aws_internet_gateway.gw]

}

# Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-0729e439b6769d6ab"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "udapeople"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo My firts web server > /var/www/html/index.html'
                EOF

  tags = {
    "Name" = "web-server"
    }
}
