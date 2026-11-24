output "fqdn" {
  value       = var.fqdn
  description = "Canonical site domain. Set this as the custom domain in Obsidian Publish."
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.site.id
  description = "Distribution id, for cache invalidations."
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.site.domain_name
  description = "CloudFront hostname backing the Route53 alias."
}

output "acm_certificate_arn" {
  value       = local.acm_certificate_arn
  description = "Certificate attached to the distribution."
  sensitive   = true # embeds the account id
}
