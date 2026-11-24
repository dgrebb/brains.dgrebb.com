variable "project" {
  type        = string
  default     = "brains"
  description = "Project name, used as a resource name prefix and tag."
}

variable "fqdn" {
  type        = string
  default     = "brains.dgrebb.com"
  description = "Canonical domain served by this distribution. Must match the custom domain configured in Obsidian Publish."
}

variable "parent_zone" {
  type        = string
  default     = "dgrebb.com"
  description = "Route53 public hosted zone that contains the fqdn."
}

variable "obsidian_domain_name" {
  type        = string
  default     = "publish.obsidian.md"
  description = "Obsidian Publish origin hostname."
}

variable "acm_certificate_id" {
  type        = string
  default     = null
  description = <<-EOT
    UUID of the us-east-1 ACM certificate to attach, pinning the exact certificate.
    The account id is read at runtime, so only the UUID is needed here.
    Leave null to fall back to a lookup by acm_certificate_domain.
  EOT

  validation {
    condition     = var.acm_certificate_id == null || can(regex("^[0-9a-f-]{36}$", var.acm_certificate_id))
    error_message = "acm_certificate_id must be a bare certificate UUID, not a full ARN."
  }
}

variable "acm_certificate_domain" {
  type        = string
  default     = "dgrebb.com"
  description = "Primary domain of the certificate to look up when acm_certificate_id is null. Its SANs must cover var.fqdn."
}

variable "price_class" {
  type        = string
  default     = "PriceClass_100"
  description = "CloudFront price class. PriceClass_100 (North America + Europe edges) is the cheapest option."

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of PriceClass_100, PriceClass_200, PriceClass_All."
  }
}
