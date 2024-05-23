# Define AWS provider
provider "aws" {
  region = "us-west-2" # Change to your desired AWS region
}
# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}
# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block ="10.0.1.0/24"
  availability_zone ="us-west-2a" # Change to your desired availability zone
}
# Create EKS cluster
resource "aws_eks_cluster" "my_cluster" {
  name = my-eks-cluster
  role_arn = "arn:aws:iam::123456789012:role/eks-service-role" # Change to your EKS service role ARN
  version = "1.21" # Change to your desired EKS version
  vpc_config {
  subnet_ids = [aws_subnet.private_subnet.id]
  }
}
# Create EKS worker nodes
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = "arn:aws:iam::123456789012:role/eks-node-role"  # Change to your EKS node role ARN
  subnet_ids = [aws_subnet.private_subnet.id]
  instance_types   = ["t2.medium"]
  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
}
# Create Virtual Machines
resource "aws_instance" "my_instances" {
  count = 4
  ami ="ami-0c55b159cbfafe1f0" # Change to your desired AMI
  instance_type ="t2.medium"
  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update
                 chmod 700 ~/.ssh
                 chmod 600 ~/.ssh/authorized_keys
               EOF
  tags = {
    Name = "my-instance-${count.index + 1}"
  }
}
# Paste public key in authorized_keys file of newly created VMs
resource "null_resource" "copy_ssh_key" {
  depends_on = [aws_instance.my_instances]
  provisioner "remote-exec" {
    connection {
      type ="ssh"
      host = aws_instance.my_instances.*.public_ip[count.index]
      user ="ubuntu" # Change to your desired username
      private_key = file("~/.ssh/your_private_key.pem") # Change to your private key path
    }
    inline = [
      "echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys" # Change to your public key
    ]
  }
}