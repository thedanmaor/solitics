# provider "aws" {
#   region = "eu-west-1"
# }

# # Create security group for ALB
# resource "aws_security_group" "alb_sg" {
#   name        = "alb-sg"
#   description = "Security group for ALB to allow traffic from CloudFront"

#   # Allow inbound traffic from CloudFront
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # Adjust this to allow only traffic from CloudFront - currentyl open to all for the demo
#   }

#   # Allow outbound traffic
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # Create ALB
# resource "aws_lb" "my_alb" {
#   name               = "my-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_sg.id]

#   # Add other necessary configurations for your ALB
# }
