provider "aws" {
  region = "eu-west-1"
}
module "cdn" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.3.2"

  #aliases = ["cdn.example.com"]

  comment             = "CloudFront For Solitics"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    alb = {
      domain_name = aws_lb.my_alb.dns_name
      custom_origin_config = {
        http_port = 80
        #        https_port             = 443
        origin_protocol_policy = "match-viewer"
        #        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
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
