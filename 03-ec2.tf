provider "aws" {
  region = "eu-west-1"
}

# Create security group for instances
resource "aws_security_group" "instances_sg" {
  name        = "instances-sg"
  description = "Security group for instances"

  # Allow inbound traffic all
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # currentyl open to all for the demo
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3a.micro"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.instances_sg.id]
  subnet_id              = "REPLACE WITH ACTIAL SUBNET ID in the region"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo bash -c 'cat << EOF > /etc/nginx/sites-available/default",
      "server {",
      "    listen 80;",
      "    server_name _;",
      "    location / {",
      "        proxy_pass http://your_kubernetes_cluster_endpoint;",
      "        proxy_set_header Host $host;",
      "        proxy_set_header X-Real-IP $remote_addr;",
      "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "        proxy_set_header X-Forwarded-Proto $scheme;",
      "    }",
      "}",
      "EOF'",
      "sudo systemctl restart nginx"
    ]
  }
}
