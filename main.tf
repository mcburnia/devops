provider "aws" {
	region 						= "us-east-1"
}

variable "zones" {
  default 						= ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "instance_port" {
	description 				= "the port this server will use for http requests on each instance"
	default						= 8080
}

variable "public_port" {
	description 				= "the port this server will use for http requests on the ELB"
	default						= 80
}

data "aws_availability_zones" "all" {
	
}

resource "aws_instance" "example" {
	ami							= "ami-40d28157"
	instance_type				= "t2.micro"
	vpc_security_group_ids 		= ["${aws_security_group.instance.id}"]

	user_data = <<-EOF
				#!/bin/bash
				echo "Andi's first cloud webserver" > index.html
				nohup busybox httpd -f -p "${var.instance_port}" &
				EOF

	tags = {
		Name 					= "terraform-example"
	}
}

resource "aws_launch_configuration" "example" {
	image_id					= "ami-40d28157"
	instance_type				= "t2.micro"
	security_groups 			= ["${aws_security_group.instance.id}"]

	user_data = <<-EOF
				#!/bin/bash
				echo "Andi's first cloud webserver" > index.html
				nohup busybox httpd -f -p "${var.instance_port}" &
				EOF

	lifecycle {
		create_before_destroy 	= true
	}
}

resource "aws_autoscaling_group" "example" {
	launch_configuration 		= "${aws_launch_configuration.example.id}"
	availability_zones			= "${data.aws_availability_zones.all.names}"

	load_balancers				= ["${aws_elb.example.name}"]
	health_check_type			= "ELB"

	min_size 					= 2
	max_size 					= 10

	tag {
		key						= "Name"
		value					= "terraform-asg-example"
		propagate_at_launch		= true
	}
}

resource "aws_elb" "example" {
	name 						= "terraform-asg-example"
	availability_zones			= "${data.aws_availability_zones.all.names}"
	security_groups 			= ["${aws_security_group.elb.id}"]

	listener {
		lb_port					= "${var.public_port}"
		lb_protocol				= "http"
		instance_port			= "${var.instance_port}"
		instance_protocol		= "http"
	}

	health_check {
		healthy_threshold		= 2
		unhealthy_threshold		= 2
		timeout					= 3
		interval				= 30
		target					= "HTTP:${var.instance_port}/"
	}
}

resource "aws_security_group" "instance" {
	name 						= "terraform-example-instance"

	ingress {
		from_port				= "${var.instance_port}"
		to_port					= "${var.instance_port}"
		protocol				= "tcp"
		cidr_blocks 			= ["0.0.0.0/0"]
	}

	lifecycle {
		create_before_destroy 	= true
	}
}

resource "aws_security_group" "elb" {
	name 						= "terraform-example-elb"

	ingress {
		from_port				= "${var.public_port}"
		to_port					= "${var.public_port}"
		protocol				= "tcp"
		cidr_blocks 			= ["0.0.0.0/0"]
	}

	egress {
		from_port				= 0
		to_port					= 0
		protocol				= "-1"
		cidr_blocks 			= ["0.0.0.0/0"]
	}	

	lifecycle {
		create_before_destroy 	= true
	}
}

output "elb_dns_name" {
	value						= "${aws_elb.example.dns_name}"
}

