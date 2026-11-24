data "aws_caller_identity" "current" {}

data "aws_route53_zone" "parent" {
  name         = "${var.parent_zone}."
  private_zone = false
}

# Reuses an existing certificate rather than issuing one: *.dgrebb.com already
# covers this subdomain, so there is nothing to validate.
#
# Prefer pinning acm_certificate_id, which resolves to exactly one certificate.
# The fallback lookup matches on primary domain with most_recent = true, and the
# account holds more than one ISSUED cert for dgrebb.com, so which one it picks
# can change if another is issued later.
data "aws_acm_certificate" "site" {
  count = var.acm_certificate_id == null ? 1 : 0

  domain      = var.acm_certificate_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  acm_certificate_arn = (
    var.acm_certificate_id == null
    ? data.aws_acm_certificate.site[0].arn
    : "arn:aws:acm:us-east-1:${data.aws_caller_identity.current.account_id}:certificate/${var.acm_certificate_id}"
  )
}

# Managed-CachingOptimized: caches on path only, enables Brotli/Gzip.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
