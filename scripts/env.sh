# shellcheck shell=bash
# Shared environment for OpenTofu and AWS CLI in this project.
#
# Sourced by scripts/tofu — do not execute directly.
# Existing AWS_* / TF_VAR_* values win; pass is only consulted for unset ones.
# Credentials go to the standard AWS env chain (not TF_VAR_*), so the provider
# uses its default credential resolution. The only TF_VAR_ is the project-
# specific certificate pin.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "error: source this file; do not execute it" >&2
  exit 1
fi

# Project-scoped credentials: the brains-tofu user carries only the
# brains-tofu policy (iam/brains-tofu-policy.json.tpl), not account-wide access.
PASS_AWS_ACCESS_KEY_ID="${PASS_AWS_ACCESS_KEY_ID:-dg/aws/brains/id}"
PASS_AWS_SECRET_ACCESS_KEY="${PASS_AWS_SECRET_ACCESS_KEY:-dg/aws/brains/secret}"
PASS_ACM_CERTIFICATE_ID="${PASS_ACM_CERTIFICATE_ID:-dg/aws/brains/cert-id}"

# Resource ids used to render the IAM policy (iam/render-policy.sh). Not read
# by OpenTofu, which discovers both at plan time, so they stay out of TF_VAR_.
PASS_DISTRIBUTION_ID="${PASS_DISTRIBUTION_ID:-dg/aws/brains/distribution-id}"
PASS_ZONE_ID="${PASS_ZONE_ID:-dg/aws/brains/zone-id}"

# CloudFront viewer certificates must live in us-east-1. Do not inherit the
# account default (us-east-2) from pass or ~/.aws/config for this project.
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"

# Read the first line of a pass entry. Quiet by design: callers decide whether
# a missing entry is fatal. Avoids `| head -n1`, which can SIGPIPE `pass` and
# report failure even when the value was read.
pass_get() {
  local entry="$1" value
  value="$(pass show "$entry" 2>/dev/null)" || return 1
  value="${value%%$'\n'*}"
  value="${value%$'\r'}"
  [[ -n "$value" ]] || return 1
  printf '%s' "$value"
}

# Export $1 from pass entry $2 when the variable is unset or empty.
# A missing entry is fatal.
from_pass() {
  local var="$1" entry="$2" value
  if [[ -n "${!var:-}" ]]; then
    return 0
  fi
  if ! value="$(pass_get "$entry")"; then
    echo "error: could not read pass entry: ${entry}" >&2
    return 1
  fi
  export "${var}=${value}"
}

# Same, but a missing entry is not fatal. Used where there is a working
# fallback, so a fresh clone still works without the entry. $3 describes that
# fallback for the warning.
from_pass_optional() {
  local var="$1" entry="$2" fallback="${3:-runtime discovery}" value
  if [[ -n "${!var:-}" ]]; then
    return 0
  fi
  if ! value="$(pass_get "$entry")"; then
    echo "warning: pass entry unavailable (${entry});" >&2
    echo "warning: falling back to ${fallback}" >&2
    return 0
  fi
  export "${var}=${value}"
}

# Prefer an already-configured credential chain (env, profile, SSO, instance
# role). Only fall back to static keys in pass when nothing else is set.
if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -z "${AWS_PROFILE:-}" && -z "${AWS_SESSION_TOKEN:-}" ]]; then
  from_pass AWS_ACCESS_KEY_ID "$PASS_AWS_ACCESS_KEY_ID" || return 1
  from_pass AWS_SECRET_ACCESS_KEY "$PASS_AWS_SECRET_ACCESS_KEY" || return 1
fi

from_pass_optional TF_VAR_acm_certificate_id "$PASS_ACM_CERTIFICATE_ID" \
  "the most recent ISSUED cert for the domain" || return 1

from_pass_optional BRAINS_DISTRIBUTION_ID "$PASS_DISTRIBUTION_ID" \
  "reading the distribution id from local state" || return 1

from_pass_optional BRAINS_ZONE_ID "$PASS_ZONE_ID" \
  "looking the zone id up by domain name" || return 1
