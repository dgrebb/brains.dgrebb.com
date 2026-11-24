# brains.dgrebb.com

OpenTofu config that serves an [Obsidian Publish](https://publish.obsidian.md)
vault from a custom domain via CloudFront and Route53.

Adapted from [kis9a/CustomDomain2ObsidianPublish](https://github.com/kis9a/CustomDomain2ObsidianPublish),
updated for OpenTofu and current AWS provider idioms (managed cache policies
instead of the deprecated `forwarded_values`, IPv6, HTTP/3, TLS 1.2_2021).

## How it works

Obsidian Publish has no DNS of its own to point at. Instead, CloudFront proxies
to `publish.obsidian.md` and tags each request with a custom header naming the
domain:

```
browser ──> brains.dgrebb.com (Route53 alias)
        ──> CloudFront distribution
              injects x-obsidian-custom-domain: brains.dgrebb.com
              sends   Host: publish.obsidian.md
        ──> publish.obsidian.md  ──> your vault
```

CloudFront sends `Host: publish.obsidian.md`, so Obsidian cannot identify the
site from the Host header. It reads `x-obsidian-custom-domain` instead. **That
header value must exactly match the custom domain set in Obsidian Publish**, or
Obsidian returns 404 — which is the single most likely thing to be wrong.

Three resources, all in `us-east-1`: one `aws_cloudfront_distribution`, and A
and AAAA `aws_route53_record` aliases pointing at it. The ACM certificate and
hosted zone are read with data sources, not created.

## Where to start

| You are | Go to |
| --- | --- |
| Changing or maintaining this site | [Day to day](#day-to-day) |
| Rebuilding this domain after it was destroyed | [From scratch](#from-scratch) |
| Cloning this for a different domain | [Repurposing](#repurposing) |

## Day to day

```sh
make plan     # writes tfplan
make apply    # applies tfplan, then deletes it
make check    # fmt -check + validate, no AWS writes
make help     # all targets
```

Always `make plan` and read it before `make apply`. Apply refuses to run
without a saved plan, which is the guardrail against an unreviewed change.

For one-off commands with the same credential injection:
`./scripts/tofu <args>` — for example `./scripts/tofu state list`.

A healthy no-op plan says `No changes` and does **not** read
`data.aws_acm_certificate.site`. If you see that data source being read, the
certificate pin is missing and you are on the fallback path; see
[Certificate](#certificate).

Routine changes worth knowing:

- **Cache behavior or TLS settings** — edit `cloudfront.tf`, then plan/apply.
  CloudFront takes 3–15 minutes to redeploy; the site stays up throughout.
- **Purging the cache** — `aws cloudfront create-invalidation --distribution-id
  "$(./scripts/tofu output -raw cloudfront_distribution_id)" --paths '/*'`.
  Obsidian pushes content directly to its own origin, so you rarely need this.
- **Changing the IAM policy** — see [Permissions](#permissions).

## From scratch

Rebuilding `brains.dgrebb.com` in this account, assuming the `dgrebb.com`
hosted zone and the `*.dgrebb.com` certificate still exist.

1. Install `tofu`, `aws`, and `pass`.
2. Confirm the five `pass` entries exist (see [Reference](#reference)):
   `pass ls dg/aws/brains`.
3. `make init && make plan` — expect three resources to be created.
4. `make apply`. The distribution takes a few minutes.
5. In Obsidian Publish, set the custom domain to `brains.dgrebb.com`.
6. Verify: `curl -sSI https://brains.dgrebb.com/ | head -1` should be 200.

If step 6 returns 404 but the response has a `via: ... cloudfront.net` header,
AWS is healthy and step 5 is what is missing or mistyped.

If the certificate is also gone, request a new one in **us-east-1** covering
the domain, let it validate, then put its UUID in `dg/aws/brains/cert-id`.

If you are standing up the IAM user too, see [Permissions](#permissions) —
bootstrap it with broader credentials, since the scoped policy pins a
distribution id that does not exist yet.

## Repurposing

**You do not need `pass`, and you do not need to touch `scripts/`.** Every
lookup is skipped when the corresponding variable is already set, so exporting
`AWS_PROFILE` bypasses the credential lookup entirely. The remaining three
lookups are non-fatal: they print a warning and fall back to discovery.

Prerequisites: a Route53 **public hosted zone** you control, and an ACM
certificate in **us-east-1** whose domain or SANs cover your subdomain.

1. Set your values in `terraform.tfvars`:

   ```hcl
   fqdn                   = "notes.example.com"
   parent_zone            = "example.com"
   acm_certificate_domain = "example.com"
   project                = "notes"
   ```

2. `export AWS_PROFILE=your-profile`
3. `make init && make plan` — three warnings about missing `pass` entries are
   expected and harmless.
4. `make apply`, then set the custom domain in Obsidian Publish.

Two constraints that will bite you:

- The subdomain must live in a zone you control, and cannot include a path.
  Obsidian matches on the hostname alone.
- If your account has more than one certificate matching
  `acm_certificate_domain`, the fallback picks the most recently issued one.
  Pin an exact certificate by setting `acm_certificate_id` to its bare UUID in
  `terraform.tfvars`.

The IAM policy in `iam/` is specific to this account. Either delete it or
re-render it for yours.

## Reference

### Variables

All have working defaults for `brains.dgrebb.com`; override in
`terraform.tfvars`.

| Variable | Default | Notes |
| --- | --- | --- |
| `fqdn` | `brains.dgrebb.com` | Must match the Obsidian Publish custom domain |
| `parent_zone` | `dgrebb.com` | Existing Route53 public zone |
| `acm_certificate_domain` | `dgrebb.com` | Primary domain of the cert to reuse |
| `acm_certificate_id` | `null` | Bare UUID. Pins an exact cert; see below |
| `obsidian_domain_name` | `publish.obsidian.md` | Origin hostname |
| `price_class` | `PriceClass_100` | Cheapest; North America + Europe edges |
| `project` | `brains` | Name prefix and tag |

### pass entries

`make` loads these through `scripts/env.sh` before every OpenTofu invocation.
Already-set variables always win, so each is an override point.

| Variable | pass entry | Missing? |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `dg/aws/brains/{id,secret}` | **Fatal**, unless `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` / `AWS_SESSION_TOKEN` is already set |
| `TF_VAR_acm_certificate_id` | `dg/aws/brains/cert-id` | Warns; falls back to lookup by domain |
| `BRAINS_DISTRIBUTION_ID` | `dg/aws/brains/distribution-id` | Warns; falls back to local state |
| `BRAINS_ZONE_ID` | `dg/aws/brains/zone-id` | Warns; falls back to lookup by domain |

`BRAINS_*` are only used to render the IAM policy. OpenTofu never sees them —
it discovers both ids at plan time — so they are not `TF_VAR_`.

The account id is never stored anywhere; it is read at runtime from
`sts:GetCallerIdentity` and `aws_caller_identity`.

### Certificate

`acm_certificate_id` pins one exact certificate and is the intended path.
Without it, the config selects the most recent ISSUED certificate whose primary
domain matches `acm_certificate_domain`. This account holds more than one such
certificate, so that selection could silently change if another is issued —
hence the pin. The fallback exists so the config works without `pass` at all,
which is what makes [repurposing](#repurposing) straightforward.

## Permissions

`make` runs as the dedicated `brains-tofu` IAM user, which carries **only** the
`brains-tofu` managed policy. It can manage this one distribution and records
in the `dgrebb.com` zone. Reading any other distribution, listing S3, or
reading IAM is denied.

IAM permissions are additive, so this policy only restricts anything when it is
the *sole* policy on the principal. Attaching it next to something like
`IAMFullAccess` accomplishes nothing.

To change it, edit `iam/brains-tofu-policy.json.tpl`, then:

```sh
make iam-policy
aws iam create-policy-version \
  --policy-arn arn:aws:iam::<account-id>:policy/brains-tofu \
  --policy-document file://iam/brains-tofu-policy.json --set-as-default
```

Only the template is committed. The rendered JSON is gitignored because it
embeds the account, zone, and distribution ids.

After changing it, re-run `make plan` as that user: a clean `No changes` is the
only real proof the policy is still sufficient. Permission gaps surface as
`AccessDeniedException` mid-run, not at validate time. The ACM grants matter
only on the certificate fallback path, so a plan with the pin in place will not
exercise them.

## Why it is built this way

Non-obvious constraints, recorded so they do not have to be rediscovered:

- **The provider region is `us-east-1` and that is not a cost decision.**
  CloudFront requires its viewer certificate in `us-east-1`. CloudFront and
  Route53 are both global and this config creates no regional resources, so
  there is no region or AZ to optimize. `price_class` is the only cost lever.
- **Cost is effectively zero.** A distribution has no fixed charge, and the
  perpetual free tier covers 1 TB egress and 10M requests per month.
- **This does not conflict with other distributions on the same domain.**
  CloudFront only rejects *duplicate aliases*. A separate distribution for a
  subdomain is fine and needs no change to existing ones.
- **The certificate is shared, read-only.** `*.dgrebb.com` is read via a data
  source, so OpenTofu can never modify or delete it, and ACM renewal keeps the
  same ARN.
- **Never destroy to "reapply with new settings."** Almost everything, IAM
  included, can change in place. A destroy/recreate cycle means roughly 20–40
  minutes of downtime and a brand-new `*.cloudfront.net` hostname.
- **State is local and unbacked.** `terraform.tfstate` is gitignored and holds
  the account, zone, and distribution ids. Losing it means importing three
  resources by hand. Moving it to S3 (`state-brains.dgrebb.com`, matching the
  convention used by sibling projects) is the obvious next step.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| 404 with a `via: ... cloudfront.net` header | Obsidian does not know the domain. Check the custom domain in Obsidian Publish matches `fqdn` exactly. |
| `AccessDeniedException` during plan or apply | The `brains-tofu` policy is missing an action. See [Permissions](#permissions). |
| `error: could not read pass entry` | A credential entry is missing and no other AWS credential source is set. |
| `warning: pass entry unavailable` | Expected when repurposing. Harmless; the value is being discovered instead. |
| Plan wants to replace the distribution | Check for an `aliases` or `viewer_certificate` change. Replacement means downtime and a new CloudFront hostname. |
| `make apply` says no tfplan | Run `make plan` first; this is intentional. |
