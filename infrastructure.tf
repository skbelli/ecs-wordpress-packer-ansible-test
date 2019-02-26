
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "eu-west-1"
}



# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {

   availability_zone = "eu-west-1b"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}


# Our default security group to access
# the instances over SSH and HTTP

resource "aws_security_group" "default" {
  name        = "terraform-SG"
  description = "created by terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from specifi IP 123.123.123.123
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["123.123.123.123/32"]
  }

  # HTTP access from everywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  
  # HTTPS access from everywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
	
  }
  
  }


resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}


data "aws_ami" "centos" {

most_recent = true

  filter {
      name   = "name"
      values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
      name   = "architecture"
      values = ["x86_64"]
  }

  filter {
      name   = "root-device-type"
      values = ["ebs"]
  }
}





resource "aws_instance" "centos" {

instance_type = "t2.micro"

availability_zone = "eu-west-1b"
 
ami = "${data.aws_ami.centos.id}"

  connection {
    # The default username for CentOS AMI
    user = "centos"
	private_key = "${file(var.private_key)}"

    # The connection will use the local SSH agent for authentication.
}

    tags { Name = "web1" 
		}
		
	key_name = "${aws_key_pair.auth.id}"
	
	
	vpc_security_group_ids = ["${aws_security_group.default.id}"]
	
	 subnet_id = "${aws_subnet.default.id}"
	 
	root_block_device {
    volume_size = 50
    volume_type = "gp2"
    delete_on_termination = true

     }
	
  
provisioner "remote-exec" {
    inline = [
	
"sudo yum -y update",

#Installing apache service

"sudo yum -y install httpd",
"sudo systemctl enable httpd.service",
"sudo systemctl restart httpd.service",


# Adding `jsimon` and `dathena` users to the new CentOS instance
"sudo adduser jsimon",
"sudo adduser dathena",

]

}

# Updating ansible hosts file with CentOS EC2 instance public DNS to be used for the Configuration exercice 
provisioner "local-exec" {
    command = "echo ${aws_instance.centos.public_ip} >> /etc/ansible/hosts"
  }



}


resource "aws_ebs_volume" "ebs-volume-1" {
    availability_zone = "eu-west-1b"
    size = 10
    type = "gp2"
	
    tags {
        Name = "XFS Drive"
    }
	
}


resource "aws_volume_attachment" "ebs-volume-1-attachment" {
  device_name = "/dev/xvdf"
  volume_id = "${aws_ebs_volume.ebs-volume-1.id}"
  instance_id = "${aws_instance.centos.id}"
}



