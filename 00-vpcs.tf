provider "aws" {
  region = "eu-west-1"
}

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
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

provider "aws" {
  region = "eu-west-2"
}

# Create VPC in eu-west-2
module "vpc_eu_west_2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "vpc_eu_west_2"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
