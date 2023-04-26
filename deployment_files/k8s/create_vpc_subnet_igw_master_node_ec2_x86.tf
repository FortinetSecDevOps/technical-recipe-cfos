data "aws_availability_zones" "selected" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "k8slab" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "k8slab-vpc"
  }
}

resource "aws_internet_gateway" "k8slab" {
  vpc_id = aws_vpc.k8slab.id

  tags = {
    Name = "k8slab-internet-gateway"
  }
}


resource "aws_subnet" "k8slab" {
  vpc_id            = aws_vpc.k8slab.id
  cidr_block        = var.vpc_subnet0
  availability_zone = data.aws_availability_zones.selected.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "k8slab-public-subnet"
  }
}

resource "aws_subnet" "k8slabWorker1" {
  vpc_id            = aws_vpc.k8slab.id
  cidr_block        = var.vpc_subnet1
  availability_zone = data.aws_availability_zones.selected.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "k8slab-public-subnet1"
  }
}



resource "aws_route_table" "k8slab" {
  vpc_id = aws_vpc.k8slab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8slab.id
  }

  tags = {
    Name = "k8slab-route-table"
  }
}

resource "aws_route_table_association" "k8slab" {
  subnet_id      = aws_subnet.k8slab.id
  route_table_id = aws_route_table.k8slab.id
}

resource "aws_route_table_association" "k8slabWorker1" {
  subnet_id      = aws_subnet.k8slabWorker1.id
  route_table_id = aws_route_table.k8slab.id
}


resource "aws_security_group" "k8slab" {
  name   = "k8slab-security-group"
  vpc_id = aws_vpc.k8slab.id

  ingress {
    from_port   = var.tcp_from_port
    to_port     = var.tcp_to_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "k8slabkey" {
  key_name   = "k8slabkeypair"
  #public_key = file("~/.ssh/id_rsa.pub") this will not work in macos 
  public_key = file("~/.ssh/id_ed25519cfoslab.pub")
}

resource "aws_instance" "k8slab" {
  ami           = local.ec2_image_id_map[var.region]
  instance_type = var.instance_type
  subnet_id     = aws_subnet.k8slab.id
  security_groups = [aws_security_group.k8slab.id]
  key_name = aws_key_pair.k8slabkey.key_name
  source_dest_check = false 
  private_ip = cidrhost(var.vpc_subnet0, 100)


  user_data     = templatefile(
	"${path.module}/user-data-for_master_node.tftpl",
	 {
		POD_CIDR=var.podCIDR
                WORKER_COUNT=var.worker_count
		SERVICE_CIDR=var.serviceCIDR
		CLUSTERDNSIP=var.clusterdnsip
                AWSDNSIP=var.awsdnsip
                CNI=var.cni
                MULTUSCNI=var.multuscni
                GATEKEEPER=var.gatekeeper
	 }
  )

  provisioner "file" {
    source = var.cfosLicense
    destination ="/home/ubuntu/fos_license.yaml"
   }
 

  provisioner "file" {
    source = var.dockerinterbeing
    destination = "/home/ubuntu/.dockerinterbeing.yaml"
  }

  provisioner "file" {
   source = "multus-daemonset-stable.yml"
   destination = "/home/ubuntu/multus-daemonset.yml"
 }

  tags = {
    Name = "k8slab"
  }

   provisioner "remote-exec" {
     inline = [
      "tail -f /var/log/user-data.log --retry | sed '/deploymentcompleted/q' ",
    ]
   }
  connection {
    host = "${aws_instance.k8slab.public_ip}"
    type = "ssh"
    port = "22"
    user = "ubuntu"
    timeout = "120s"
    private_key = "${file("${var.key_location}")}"
    agent= false
  }
}

output "instance_public_ip" {
  value = aws_instance.k8slab.public_ip
}
