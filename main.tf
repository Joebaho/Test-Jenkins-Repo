# Define AWS provider
provider "aws" {
  region = "eu-west-2" # Change to your desired AWS region
}
# Data source for AMI 
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}
# Create private subnet
resource "aws_subnet" "private_subnet1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block ="10.0.1.0/24"
  availability_zone ="eu-west-2a" 
  tags = {
    Name = "private_Subnet1"
  }# Change to your desired availability zone
}
resource "aws_subnet" "private_subnet2" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block ="10.0.2.0/24"
  availability_zone ="eu-west-2b"
  tags = {
    Name = "private_Subnet2"
  } # Change to your desired availability zone
}
# Create role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name        = "EKSClusterRole"
  description = "all IAM role for eks xcluster access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "",
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}
# create eks nodes role
resource "aws_iam_role" "eks_node_role" {
  name        = "EKSClusterRole"
  description = "all IAM role for eks nodes access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "",
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}
# Create EKS cluster
resource "aws_eks_cluster" "my_cluster" {
  name = my-eks-cluster
  role_arn = aws_iam_role.eks_cluster_role.arn # Change to your EKS service role ARN
  version = "1.21" # Change to your desired EKS version
  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet1.id,
      aws_subnet.private_subnet2.id 
    ]
  }
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy
  ]
}
# Create EKS worker nodes
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn # Change to your EKS node role ARN
  subnet_ids = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]
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
  ami = aws_ami.ubuntu.id  # Change to your desired AMI
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