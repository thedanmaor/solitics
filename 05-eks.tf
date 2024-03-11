# provider "aws" {
#   region = "eu-west-2"
# }

# # Create EKS Cluster
# resource "aws_eks_cluster" "my_cluster" {
#   name     = "my-eks-cluster"
#   role_arn = aws_iam_role.my_eks_role.arn
#   version  = "1.28" # Change the version as needed

#   vpc_config {
#     subnet_ids         = ["your_subnet_ids"]         # Replace with your subnet IDs
#     security_group_ids = ["your_security_group_ids"] # Replace with your security group IDs
#   }
# }

# # Define IAM role for EKS
# resource "aws_iam_role" "my_eks_role" {
#   name               = "my-eks-role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "eks.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# # Attach necessary policies to IAM role
# resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
#   role       = aws_iam_role.my_eks_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# }

# resource "aws_iam_role_policy_attachment" "eks_service_policy" {
#   role       = aws_iam_role.my_eks_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
# }

# # Deploy simple web server on Kubernetes
# resource "kubernetes_deployment" "web_server" {
#   metadata {
#     name = "web-server"
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "web-server"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "web-server"
#         }
#       }

#       spec {
#         container {
#           name  = "web-server"
#           image = "nginx:latest" # Choose your Docker image here
#           ports {
#             container_port = 80
#           }
#         }
#       }
#     }
#   }
# }
