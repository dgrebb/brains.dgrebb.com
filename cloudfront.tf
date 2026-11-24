locals {
  origin_id = "${var.project}-${var.obsidian_domain_name}"
}

resource "aws_cloudfront_distribution" "site" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.fqdn
  price_class     = var.price_class
  http_version    = "http2and3"
  aliases         = [var.fqdn]

  origin {
    origin_id   = local.origin_id
    domain_name = var.obsidian_domain_name

    # Obsidian routes the request to the correct published site off this header,
    # since CloudFront sends Host: publish.obsidian.md to the origin.
    custom_header {
      name  = "x-obsidian-custom-domain"
      value = var.fqdn
    }

    custom_origin_config {
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      http_port              = 80
      https_port             = 443
    }
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
