resource "aws_instance" "k8slabWorker1" {
  count = var.worker_count
  depends_on = [aws_instance.k8slab]
  ami           = local.ec2_image_id_map[var.region]
  instance_type = var.instance_type
  subnet_id     = aws_subnet.k8slabWorker1.id
  security_groups = [aws_security_group.k8slab.id]
  key_name = aws_key_pair.k8slabkey.key_name
  source_dest_check = false
  private_ip = cidrhost(var.vpc_subnet1, count.index+200)


  user_data     = templatefile(
        "${path.module}/user-data-for_worker_node.tftpl",
         {
                POD_CIDR=var.podCIDR
         }
  )

  provisioner "file" {
    source = var.cfosLicense
    destination ="/home/ubuntu/fos_license.yaml"
   }

  provisioner "file" {
    source =  var.key_location
    destination = "/home/ubuntu/.ssh/id_ed25519"
  }

  provisioner "file" {
    source = var.dockerinterbeing
    destination = "/home/ubuntu/.dockerinterbeing.yaml"
  }

  tags = {
    Name = "k8slabWorker${count.index+1}"
  }

   provisioner "remote-exec" {
     inline = [
      "tail -f /var/log/user-data.log --retry | sed '/deploymentcompleted/q' ",
    ]
   }
  connection {
   # host = "${aws_instance.k8slabWorker1[count.index].public_ip}"
    host = self.public_ip
    type = "ssh"
    port = "22"
    user = "ubuntu"
    timeout = "120s"
    private_key = "${file("${var.key_location}")}"
    agent= false
  }
}

output "workernode_instance_public_ip" {
  value = aws_instance.k8slabWorker1.*.public_ip
}
