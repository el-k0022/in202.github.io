variable "aws_region" { default = "eu-west-1"}

#########
# aws auth
provider "aws" {
    region     = "${var.aws_region}"
    access_key = "AKIASOO3MDFASBG467NQ"
    secret_key = "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"
}

# extract last Aws ubuntu Amazon image (Ami)
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# ssh keys
resource "aws_key_pair" "admin" {
  key_name   = "admin.key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDO0cD6HK2cPutURkX11lR1DG1+/Ry1t3Jp+RCTybp3wFVHCKitCcwqyZEhGuviTLJgCaL71xiKjkKjt9VoIEi7FnJ+gQdRC/OTc6RwhUYdox5mgOeM/1erb1949eD0OE2mVAw/al+xPZBTOejTQzRgOvIfEP7y0WlM3dAOqAgTCvJnysxxmHUh7skCt6mxLK5tpTmnpEb9bFXTIcbMKtKhLGkOImOUeVTRQePS4E2IImLouAl+QFbmbfxPM6A962FSGL1iZXF/Pkkm8IfSaUybkx+mcV4zD/l8BfYhNYJSujVJn/OoE99/2escJFoJBvgkRVNkAf583wrlx1M9k3Il nel@nel"
}

# network configuration

# Get default VPC

resource "aws_vpc" "main" {
  cidr_block       = "172.30.0.0/16"
  instance_tenancy = "dedicated"

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "default"{
  vpc_id = "${aws_vpc.main.id}"
}


resource "aws_subnet" "rudder" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "172.30.2.0/24"

  tags = {
    Name = "rudder"
  }
}


# create group_security

resource "aws_security_group" "allow_remote_admin" {
  name        = "allow_remote_admin"
  description = "Allow ssh and RDP inbound traffic"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_remote_admin"
  }
}


resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic to server"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
    Name = "allow_web"
  }
}

resource "aws_security_group" "allow_rudder_internal" {
  name        = "allow_rudder_internal"
  description = "Allow rudder connexion from web server"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.rudder.cidr_block}"]
  }

  tags = {
    Name = "allow_rudder_internal"
  }
}

# create instance 

resource "aws_instance" "rudder-terra" {
    ami           = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.admin.key_name}"  
    subnet_id = "${aws_subnet.rudder.id}"

    associate_public_ip_address = true

    tags = {
        Name = "rudder-terra"
        scope = "integration rudder"
        role = "rudder"
    }

    security_groups = [
        "${aws_security_group.allow_web.id}",
        "${aws_security_group.allow_rudder_internal.id}",
        "${aws_security_group.allow_remote_admin.id}"
    ]

}

