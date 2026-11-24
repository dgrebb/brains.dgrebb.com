# brains.dgrebb.com — OpenTofu UX
#
# Secrets are loaded from pass via scripts/tofu; see scripts/env.sh.
# Prefer `make plan` then `make apply` over a bare interactive apply.

.DEFAULT_GOAL := help
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

TOFU := ./scripts/tofu
PLANFILE := tfplan

.PHONY: help init fmt check validate plan apply destroy output show refresh clean iam-policy

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize providers and modules
	$(TOFU) init

fmt: ## Format .tf files in place
	$(TOFU) fmt -recursive

validate: ## Validate configuration (loads secrets)
	$(TOFU) validate

check: ## fmt -check + validate (CI-friendly)
	$(TOFU) fmt -check -recursive
	$(TOFU) validate

# tofu plan -detailed-exitcode returns 2 when the plan contains changes.
# Make would treat that as failure; normalize 0 and 2 to success.
plan: ## Write a saved plan to tfplan
	@set +e; \
	$(TOFU) plan -out=$(PLANFILE) -detailed-exitcode; \
	ec=$$?; \
	if [[ $$ec -eq 0 || $$ec -eq 2 ]]; then \
		echo "plan written to $(PLANFILE)"; \
		exit 0; \
	fi; \
	exit $$ec

apply: ## Apply the saved tfplan (run make plan first)
	@if [[ ! -f $(PLANFILE) ]]; then \
		echo "error: no $(PLANFILE) — run 'make plan' first" >&2; \
		exit 1; \
	fi
	$(TOFU) apply $(PLANFILE)
	@rm -f $(PLANFILE)

destroy: ## Destroy all managed resources (typed confirmation)
	@echo "This will destroy the CloudFront distribution and Route53 records for brains.dgrebb.com."
	@read -r -p "Type 'brains.dgrebb.com' to confirm: " confirm; \
	[[ $$confirm == brains.dgrebb.com ]] || { echo "aborted"; exit 1; }
	$(TOFU) destroy

output: ## Print outputs (sensitive values redacted)
	$(TOFU) output

show: ## Show the saved plan, or state if no plan exists
	@if [[ -f $(PLANFILE) ]]; then \
		$(TOFU) show $(PLANFILE); \
	else \
		$(TOFU) show; \
	fi

refresh: ## Refresh state against live infrastructure
	$(TOFU) apply -refresh-only -auto-approve

clean: ## Remove local plan artifacts (does not touch state)
	rm -f $(PLANFILE)

iam-policy: ## Render the least-privilege IAM policy to iam/brains-tofu-policy.json
	./iam/render-policy.sh > iam/brains-tofu-policy.json
	@echo "wrote iam/brains-tofu-policy.json"
