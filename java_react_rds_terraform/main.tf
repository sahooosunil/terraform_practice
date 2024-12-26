provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "todo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "todo vpc"
  }
}

resource "aws_internet_gateway" "todo_internet_gateway" {
    vpc_id = aws_vpc.todo_vpc.id
    tags = {
      "Name" = "todo internet gateway" 
    }
}

resource "aws_subnet" "todo_public_subnet1" {
  vpc_id = aws_vpc.todo_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    "Name" = "todo public subnet 1"
  }
    availability_zone = "ap-south-1a"
}
//Create a rooute table

resource "aws_route_table" "todo_public_sb_rt" {
    vpc_id = aws_vpc.todo_vpc.id
    tags = {
      "Name" = "todo public route table" 
    }
    
}

//add a route table into the internet gateway

resource "aws_route" "internet_access" {
    route_table_id = aws_route_table.todo_public_sb_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.todo_internet_gateway.id
  
}
//association of public subnet with the route table

resource "aws_route_table_association" "todo_public_sb_rt_asso" {
      route_table_id = aws_route_table.todo_public_sb_rt.id
      subnet_id = aws_subnet.todo_public_subnet1.id
      
}

//private subnet

resource "aws_subnet" "todo_private_subnet" {
    vpc_id = aws_vpc.todo_vpc.id
    cidr_block = "10.0.2.0/24"
    tags = {
      "Name" = "todo private subnet 1" 
    }
    availability_zone = "ap-south-1b"
  
}

resource "aws_eip" "nat_eip" {
  tags = {
    "Name" = "nat elastic ip" 
  }
}

//create NAT gateway
resource "aws_nat_gateway" "todo_nat_gatway" {
    subnet_id = aws_subnet.todo_public_subnet1.id
    tags = {
      "Name" = "todo_nat_gatway" 
    }
    allocation_id = aws_eip.nat_eip.id
    
}

//create rote table
resource "aws_route_table" "todo_private_sb_rt" {
    vpc_id = aws_vpc.todo_vpc.id
    tags = {
      "Name" = "todo private route table" 
    }
}

resource "aws_route" "nat_access" {
    route_table_id = aws_route_table.todo_private_sb_rt.id
    gateway_id = aws_nat_gateway.todo_nat_gatway.id
    destination_cidr_block = "0.0.0.0/0"
}


//association of private subnet with the route table
resource "aws_route_table_association" "todo_private_sb_rt_asso" {
    route_table_id = aws_route_table.todo_private_sb_rt.id
    subnet_id = aws_subnet.todo_private_subnet.id
}

output "vpc_id" {
  value = aws_vpc.todo_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.todo_public_subnet1.id
}

output "private_subnet_id" {
  value = aws_subnet.todo_private_subnet.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.todo_nat_gatway.id
}

resource "aws_security_group" "todo_public_ec21_sec_gr" {
  vpc_id = aws_vpc.todo_vpc.id
  tags = {
    "Name" = "todo public ec21 sec gr" 
  }
  ingress  {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "todo_public_ec21" {
  tags = {
    "Name" = "todo public ec21" 
  }
  subnet_id = aws_subnet.todo_public_subnet1.id
  security_groups = [ aws_security_group.todo_public_ec21_sec_gr.id ]
  instance_type = "t2.micro"
  ami = "ami-053b12d3152c0cc71"
  key_name = "todo-key-pair"
  associate_public_ip_address = true
  provisioner "remote-exec" {
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file("/Users/sunilsahu/Downloads/todo-key-pair.pem")
        host = self.public_ip
    }

    inline = [ 
        "sudo apt update -y",
        "sudo apt upgrade -y",
        "sudo apt install -y nodejs",
        "git clone https://github.com/sahooosunil/todoapp.git",
        "cd /home/ubuntu/todoapp/todo-app-ui",
        "sudo apt install npm -y",
        "npm install",
        "npm run build",
        "sudo apt install -y nginx",
        "sudo rm -rf /var/www/html/*",
        "sudo cp -r /home/ubuntu/todoapp/todo-app-ui/build/* /var/www/html/",
        "sudo systemctl restart nginx"
     ]
  }
  depends_on = [aws_security_group.todo_public_ec21_sec_gr]
}

resource "aws_security_group" "todo_private_ec21_sec_gr" {
  vpc_id = aws_vpc.todo_vpc.id
  tags = {
    "Name" = "todo private ec21 sec gr" 
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [aws_vpc.todo_vpc.cidr_block]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [aws_vpc.todo_vpc.cidr_block]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "todo_private_ec21" {
  tags = {
    "Name" = "todo private ec21" 
  }
  subnet_id = aws_subnet.todo_private_subnet.id
  security_groups = [ aws_security_group.todo_private_ec21_sec_gr.id ]
  instance_type = "t2.micro"
  ami = "ami-053b12d3152c0cc71"
  key_name = "todo-key-pair"
}