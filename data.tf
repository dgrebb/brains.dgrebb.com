data "aws_route53_zone" "parent" {
  name         = "${var.parent_zone}."
  private_zone = false
}

# Reuses the existing wildcard certificate rather than issuing a new one.
# *.dgrebb.com already covers brains.dgrebb.com, so there is nothing to validate.
data "aws_acm_certificate" "site" {
  domain      = var.acm_certificate_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

# Managed-CachingOptimized: caches on path only, enables Brotli/Gzip.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
