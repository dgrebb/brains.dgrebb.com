# CloudFront and Route53 are global services. The only region that matters here
# is us-east-1, because CloudFront can only attach ACM certificates from there.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = var.project
      Domain    = var.fqdn
      ManagedBy = "opentofu"
    }
  }
}
