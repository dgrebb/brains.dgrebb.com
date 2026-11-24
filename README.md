# brains.dgrebb.com

OpenTofu config fronting [Obsidian Publish](https://publish.obsidian.md) with a
CloudFront distribution and a Route53 alias, so the vault is served from
`brains.dgrebb.com` instead of `publish.obsidian.md/brains`.

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

## Usage

```sh
tofu init
tofu plan -out=tfplan
tofu apply tfplan
```

Then set the custom domain to `brains.dgrebb.com` in Obsidian Publish and wait
for the distribution to finish deploying.

## Reference

`obsidian-aws-route53/` is the original upstream module, kept for reference
only. It is not wired into this root config.
