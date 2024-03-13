### VPCS
# Create VPC in eu-west-1
module "vpc_eu_west_1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "vpc_eu_west_1"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create VPC in eu-west-2
module "vpc_eu_west_2" {
  providers = {
    aws = aws.london
  }

  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "vpc_eu_west_2"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

### TGWs
# Create Transit Gateway in eu-west-1
resource "aws_ec2_transit_gateway" "tgw" {
  provider    = aws
  description = "Transit Gateway for VPC communication"
}

# Create Transit Gateway in eu-west-2
resource "aws_ec2_transit_gateway" "tgw_london" {
  provider    = aws.london
  description = "Transit Gateway for VPC communication"
}

# Attach VPC in eu-west-1 to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_eu_west_1" {
  provider           = aws
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc_eu_west_1.vpc_id
  subnet_ids         = tolist(module.vpc_eu_west_1.private_subnets)
}

# Attach VPC in eu-west-2 to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment_eu_west_2" {
  provider           = aws.london
  transit_gateway_id = aws_ec2_transit_gateway.tgw_london.id
  vpc_id             = module.vpc_eu_west_2.vpc_id
  subnet_ids         = tolist(module.vpc_eu_west_2.private_subnets)
}

# Create Transit Gateway route table in eu-west-1
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table_eu_west_1" {
  provider           = aws
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}

# Create route in the Transit Gateway route table to enable traffic from eu-west-2 to eu-west-1
resource "aws_ec2_transit_gateway_route" "route_to_eu_west_1" {
  provider                       = aws
  destination_cidr_block         = module.vpc_eu_west_1.vpc_cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table_eu_west_1.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachment_eu_west_1.id
}

# Create Transit Gateway route table in eu-west-2
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table_eu_west_2" {
  provider           = aws.london
  transit_gateway_id = aws_ec2_transit_gateway.tgw_london.id
}

# Create route in the Transit Gateway route table to enable traffic from eu-west-1 to eu-west-2
resource "aws_ec2_transit_gateway_route" "route_to_eu_west_2" {
  provider                       = aws.london
  destination_cidr_block         = module.vpc_eu_west_2.vpc_cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table_eu_west_2.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attachment_eu_west_2.id
}

### EC2s
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create security group for instances
resource "aws_security_group" "instances_sg" {
  name        = "instances-sg"
  description = "Security group for instances"
  vpc_id      = module.vpc_eu_west_1.vpc_id
  # Allow inbound traffic all
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # currentyl open to all for the demo
  }

  # so i can remote exec / ssh into it
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["147.235.223.166/32"] # my IP
  }
  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "instances-sg"
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "forwarder" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3a.micro"
  monitoring                  = true
  vpc_security_group_ids      = [aws_security_group.instances_sg.id]
  subnet_id                   = module.vpc_eu_west_1.public_subnets[0]
  key_name                    = "danm"
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y nginx
              sudo systemctl enable nginx
              sudo systemctl start nginx

              sudo bash -c 'cat << "EOF" > /etc/nginx/sites-enabled/default
              server {
                  listen 80;
                  server_name _;
                  location / {
                      proxy_pass ${aws_eks_cluster.my_cluster.endpoint};
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }
              }
              EOF'

              sudo systemctl restart nginx
              EOF
  tags = {
    Name        = "forwarder"
    Terraform   = "true"
    Environment = "dev"
  }
}

### ALB & TG
# Create Target Group
resource "aws_lb_target_group" "my_target_group" {
  name        = "my-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc_eu_west_1.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

# Attach instance to Target Group
resource "aws_lb_target_group_attachment" "my_target_group_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.forwarder.id
}

# Create ALB
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = tolist(module.vpc_eu_west_1.private_subnets)
}

resource "aws_lb_listener" "my_alb_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}
# Create security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB to allow traffic from CloudFront"
  vpc_id      = module.vpc_eu_west_1.vpc_id
  # Allow inbound traffic from CloudFront
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this to allow traffic from CloudFront - currentyl open to all for the demo
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "alb-sg"
    Terraform   = "true"
    Environment = "dev"
  }
}

### CloudFront
module "cdn" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.3.2"

  comment             = "CloudFront For Solitics Demo"
  enabled             = true
  is_ipv6_enabled     = false
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    alb = {
      domain_name = aws_lb.my_alb.dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "alb"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

}

### EKS
# Create security group for EKS
resource "aws_security_group" "eks_sg" {
  provider    = aws.london
  name        = "eks-sg"
  description = "Security group for EKS"
  vpc_id      = module.vpc_eu_west_2.vpc_id

  # Allow inbound traffic all
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # currently open to all for the demo
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "eks-sg"
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create EKS Cluster
resource "aws_eks_cluster" "my_cluster" {
  provider = aws.london
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.my_eks_role.arn
  version  = "1.29"

  vpc_config {
    subnet_ids         = tolist(module.vpc_eu_west_2.private_subnets)
    security_group_ids = [aws_security_group.eks_sg.id]
  }
}

# Define IAM role for EKS
resource "aws_iam_role" "my_eks_role" {
  provider           = aws.london
  name               = "my-eks-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["eks.amazonaws.com",
                    "ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach necessary policies to IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  provider   = aws.london
  role       = aws_iam_role.my_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  provider   = aws.london
  role       = aws_iam_role.my_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# Attach necessary policies to IAM role for EKS node group
resource "aws_iam_role_policy_attachment" "eks_node_group_policy_1" {
  role       = aws_iam_role.my_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_2" {
  role       = aws_iam_role.my_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_3" {
  role       = aws_iam_role.my_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Create Node Group
resource "aws_eks_node_group" "nginx_node_group" {
  provider        = aws.london
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "nginx-node-group"
  node_role_arn   = aws_iam_role.my_eks_role.arn
  subnet_ids      = tolist(module.vpc_eu_west_2.private_subnets)
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t3a.micro"]

  depends_on = [aws_eks_cluster.my_cluster]
}

# Configure Kubernetes provider to connect to the EKS cluster
provider "kubernetes" {
  host                   = aws_eks_cluster.my_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.my_cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.my_cluster_token.token
}

data "aws_eks_cluster_auth" "my_cluster_token" {
  name = aws_eks_cluster.my_cluster.name
}

#nginx forwarder service account (to allow access)
resource "kubernetes_service_account" "nginx_forwarder" {
  metadata {
    name      = "nginx-forwarder"
    namespace = "default"
  }
}

resource "kubernetes_role" "nginx_forwarder_role" {
  metadata {
    name      = "nginx-forwarder-role"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "nginx_forwarder_role_binding" {
  metadata {
    name      = "nginx-forwarder-role-binding"
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.nginx_forwarder_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx_forwarder.metadata[0].name
    namespace = kubernetes_service_account.nginx_forwarder.metadata[0].namespace
  }
}

data "external" "get_service_account_token" {
  program = ["powershell", "-Command", <<-EOF
    $secretName = (kubectl.exe get sa nginx-forwarder -o json | ConvertFrom-Json).secrets[0].name
    $token = kubectl.exe get secret $secretName -o json | ConvertFrom-Json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty token
    $decodedToken = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
    Write-Output (ConvertTo-Json @{
      token = $decodedToken
    })
  EOF
  ]
}

# for some reason the token returns empty, need to further debug this and get a alid token
# output "service_account_token" {
#   value = try(jsondecode(data.external.get_service_account_token.result)["token"], "")
# }




# Deploy simple web server on Kubernetes
resource "kubernetes_deployment" "web_server" {
  provider = kubernetes
  metadata {
    name = "web-server"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "web-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "web-server"
        }
      }

      spec {
        container {
          name  = "web-server"
          image = "nginx:latest" # Ensure that the Docker image is accessible
          port {
            container_port = 80
          }
        }
      }
    }
  }
  depends_on = [aws_eks_node_group.nginx_node_group]
}
