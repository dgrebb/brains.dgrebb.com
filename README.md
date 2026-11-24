# brains.dgrebb.com

OpenTofu config fronting [Obsidian Publish](https://publish.obsidian.md) with a
CloudFront distribution and a Route53 alias, so the vault is served from
`brains.dgrebb.com` instead of a `publish.obsidian.md` URL.

Adapted from [kis9a/CustomDomain2ObsidianPublish](https://github.com/kis9a/CustomDomain2ObsidianPublish),
updated for OpenTofu and current AWS provider idioms (managed cache policies
instead of the deprecated `forwarded_values`, IPv6, HTTP/3, TLS 1.2_2021).

## How it works

Requests to `brains.dgrebb.com` hit CloudFront, which proxies to
`publish.obsidian.md` over HTTPS. Because CloudFront sends
`Host: publish.obsidian.md`, Obsidian identifies the site from the
`x-obsidian-custom-domain` request header the distribution injects. That header
value must exactly match the custom domain configured in the Obsidian Publish
settings pane.

## Resources

| Resource | Notes |
| --- | --- |
| `aws_cloudfront_distribution.site` | Alias `brains.dgrebb.com`, `PriceClass_100` |
| `aws_route53_record.site["A"]` | Alias to the distribution |
| `aws_route53_record.site["AAAA"]` | Alias to the distribution |

The ACM certificate and the hosted zone are read via data sources, not created.
The existing `*.dgrebb.com` wildcard certificate in `us-east-1` already covers
this subdomain.

## Regions

CloudFront and Route53 are global, and no regional compute or storage is
created, so there is no region or AZ to optimize. The provider is pinned to
`us-east-1` only because CloudFront requires its viewer certificate to live
there. The actual cost lever is `price_class`, which defaults to the cheapest
option, `PriceClass_100` (North America and Europe edges only).

## Configuration

No account identifiers are committed to this repo. Credentials and the
certificate id come from [`pass`](https://www.passwordstore.org/) at runtime:

```sh
export AWS_ACCESS_KEY_ID="$(pass dg/aws/id)"
export AWS_SECRET_ACCESS_KEY="$(pass dg/aws/secret)"
export AWS_REGION=us-east-1

# Pins the exact certificate. Bare UUID, not a full ARN.
export TF_VAR_acm_certificate_id="$(pass dg/aws/brains/cert-id)"
```

`acm_certificate_id` is optional. Left unset, the config falls back to looking
up the most recent ISSUED certificate whose primary domain is `dgrebb.com`.
That works today, but the account holds more than one such certificate, so the
selection could change if another is issued later. Pinning the id avoids that.

The account id is never stored anywhere; it is read at apply time via
`aws_caller_identity` to assemble the certificate ARN.

## Usage

```sh
tofu init
tofu plan -out=tfplan
tofu apply tfplan
```

Then set the custom domain to `brains.dgrebb.com` in Obsidian Publish and wait
for the distribution to finish deploying. Until Obsidian knows the domain, the
site returns a 404 from the origin even though the AWS side is healthy.

State is local and gitignored. It contains the account id, hosted zone id, and
distribution id, so it must not be committed; back it up or move it to an S3
backend before relying on it.
