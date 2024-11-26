#create a vpc

resource "aws_vpc" "project_vpc" {
  cidr_block       = "20.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support= true
  enable_dns_hostnames = true
  tags = {
    Name = "project_vpc"
  }
}

# create an IGW

resource "aws_internet_gateway" "project_igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "project_vpc"
  }
}

# create a pubrt

resource "aws_route_table" "project_pubrt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.project_igw.id
  }

#   route {
#     ipv6_cidr_block        = "::/0"
#     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
#   }

  tags = {
    Name = "project_vpc"
  }
}

# create a priv_rt
resource "aws_route_table" "project_priv_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "20.0.2.0/24"
     nat_gateway_id = aws_nat_gateway.project_NGW.id
  }

#   route {
#     ipv6_cidr_block        = "::/0"
#     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
#   }

  tags = {
    Name = "project_vpc"
  }
}

# create public SN
 resource "aws_subnet" "project_pubSN" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = "20.0.1.0/24"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true     
 
  tags = {
    Name = "project_vpc"
  }
}

#  associate public subnet
resource "aws_route_table_association" "project_pubrt_ass" {
  subnet_id      = aws_subnet.project_pubSN.id
  route_table_id = aws_route_table.project_pubrt.id
}

# create private SN
 resource "aws_subnet" "project_privSN" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = "20.0.2.0/24"
  availability_zone = "us-east-2b"


  tags = {
    Name = "project_vpc"
  }
}

# associate private subnet
resource "aws_route_table_association" "project_privrt_ass" {
  subnet_id      = aws_subnet.project_privSN.id
  route_table_id = aws_route_table.project_priv_rt.id
}

# create a security public group
resource "aws_security_group" "project_public_sg" {
  name        = "project_sg"
  description = "Allow ssh, rdp from a single IP address and Https from anywhere and allow all outbound traffic"
  vpc_id      = aws_vpc.project_vpc.id


  tags = {
    Name = "project vpc"
  }
}

# set ssh ingress rule
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.project_public_sg.id
  cidr_ipv4         = "192.0.0.1/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# set rdp ingress rule
resource "aws_vpc_security_group_ingress_rule" "allow_rdp" {
  security_group_id = aws_security_group.project_public_sg.id
  cidr_ipv4         = "192.0.0.1/32"
  from_port         = 3389
  ip_protocol       = "tcp"
  to_port           = 3389

}

# set https ingress rule
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.project_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}


# create a private security group
resource "aws_security_group" "project_priv_sg" {
  name        = "project_priv_sg"
  description = "only allow traffic from within the priv subnet"
  vpc_id      = aws_vpc.project_vpc.id


  tags = {
    Name = "project vpc"
  }
}

# set ingress rule
resource "aws_vpc_security_group_ingress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.project_priv_sg.id
  cidr_ipv4         = "20.0.2.0/24"
  ip_protocol       = "-1"
}



# create ENI
resource "aws_network_interface" "project_eni" {
  subnet_id       = aws_subnet.project_pubSN.id
  private_ips     = ["20.0.1.50"]
  security_groups = [aws_security_group.project_public_sg.id]

#   attachment {
#     instance     = aws_instance.test.id
#     device_index = 1
#   }
tags = {
    Name = "project_vpc"
  }
}    

# attach EIP to ENI
resource "aws_eip" "project_pub_eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.project_eni.id
  associate_with_private_ip = "20.0.1.50"
}

# create EIP for NATGW
resource "aws_eip" "project_NatGW_eip" {
  domain                    = "vpc"
}

# Create a NAT-GW
resource "aws_nat_gateway" "project_NGW" {
  # connectivity_type = "private"
  allocation_id = aws_eip.project_NatGW_eip.id
  subnet_id         = aws_subnet.project_pubSN.id   

tags = {
    Name = "project_vpc"
  } 
}

# Create instance

resource "aws_instance" "project_server1" {
  ami           = "ami-0c80e2b6ccb9ad6d1" # us-east-2
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "Ohio-KP"
  root_block_device {
    volume_size = 12
  }

  network_interface {
    network_interface_id = aws_network_interface.project_eni.id
    device_index         = 0
  }

  tags = {
    Name = "project_server"
  }
}

resource "aws_instance" "project_server2"{
  ami           = "ami-0c80e2b6ccb9ad6d1" # us-east-2
  instance_type = "t2.micro"
  subnet_id = aws_subnet.project_privSN.id
  # availability_zone = "us-east-2b"
  vpc_security_group_ids= ["sg-0978916c8c86bea24"]
  key_name = "Ohio-KP"
  
  root_block_device {
    volume_size = 12
  }

#   network_interface {
#     network_interface_id = aws_network_interface.project_eni.id
#     device_index         = 0
#   }
tags = {
    Name = "project_server"
  }
}

