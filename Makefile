.PHONY: help doctor bootstrap backend-configs init-dev init-stage init-prod plan-dev plan-stage plan-prod apply-dev apply-stage apply-prod destroy-dev destroy-stage destroy-prod destroy-bootstrap smoke clean

# Auto-approve flags
AUTO_APPROVE_FLAG =
ifeq ($(AUTO_APPROVE),1)
	AUTO_APPROVE_FLAG = -auto-approve -input=false
endif

# Force mode implies auto-approve for destroy operations
ifeq ($(FORCE),1)
	AUTO_APPROVE_FLAG = -auto-approve -input=false
endif

help:
	@echo "AWS Terraform Remote State Starter - Makefile targets"
	@echo ""
	@echo "Setup & Health:"
	@echo "  make doctor           - Check prerequisites (AWS creds, Terraform, region)"
	@echo ""
	@echo "Bootstrap (run once):"
	@echo "  make bootstrap        - Deploy state backend + OIDC + IAM roles"
	@echo "  make backend-configs  - Generate backend-*.hcl files from bootstrap outputs"
	@echo ""
	@echo "Environment Init (after bootstrap):"
	@echo "  make init-dev         - Initialize dev with remote backend"
	@echo "  make init-stage       - Initialize stage with remote backend"
	@echo "  make init-prod        - Initialize prod with remote backend"
	@echo ""
	@echo "Environment Operations:"
	@echo "  make plan-dev         - Plan dev changes"
	@echo "  make apply-dev        - Apply dev changes"
	@echo "  make destroy-dev      - Destroy dev resources"
	@echo ""
	@echo "  make plan-stage       - Plan stage changes"
	@echo "  make apply-stage      - Apply stage changes"
	@echo "  make destroy-stage    - Destroy stage resources"
	@echo ""
	@echo "  make plan-prod        - Plan prod changes"
	@echo "  make apply-prod       - Apply prod changes"
	@echo "  make destroy-prod     - Destroy prod resources"
	@echo ""
	@echo "Testing:"
	@echo "  make smoke            - Run smoke test (verify backend + applied env)"
	@echo ""
	@echo "Teardown:"
	@echo "  make destroy-bootstrap - Destroy bootstrap (after envs are destroyed)"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            - Clean .terraform directories and lock files"
	@echo ""
	@echo "Environment variables:"
	@echo "  AUTO_APPROVE=1        - Add -auto-approve -input=false to apply/destroy"
	@echo "  FORCE=1               - Skip confirmations + auto-approve destroy operations"
	@echo "  CI=true               - Skip confirmations (for CI environments)"
	@echo ""
	@echo "Examples:"
	@echo "  make bootstrap"
	@echo "  make backend-configs"
	@echo "  make init-dev"
	@echo "  AUTO_APPROVE=1 make apply-dev"
	@echo "  make smoke"
	@echo ""
	@echo "Teardown sequence:"
	@echo "  FORCE=1 make destroy-dev"
	@echo "  FORCE=1 make destroy-bootstrap"

doctor:
	@bash scripts/doctor.sh

bootstrap:
	@echo "Deploying bootstrap stack (state backend + OIDC + IAM)..."
	@cd bootstrap && terraform init
	@cd bootstrap && terraform apply
	@echo ""
	@echo "✅ Bootstrap complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: make backend-configs (generates backend-*.hcl from outputs)"
	@echo "  2. Run: make init-dev"
	@echo "  3. Run: make apply-dev"

backend-configs:
	@bash scripts/generate_backend_configs.sh

init-dev:
	@echo "Initializing dev environment with remote backend..."
	@cd environments/dev && terraform init -backend-config=backend-dev.hcl

init-stage:
	@echo "Initializing stage environment with remote backend..."
	@cd environments/stage && terraform init -backend-config=backend-stage.hcl

init-prod:
	@echo "Initializing prod environment with remote backend..."
	@cd environments/prod && terraform init -backend-config=backend-prod.hcl

plan-dev:
	@cd environments/dev && terraform plan

plan-stage:
	@cd environments/stage && terraform plan

plan-prod:
	@cd environments/prod && terraform plan

apply-dev:
	@cd environments/dev && terraform apply $(AUTO_APPROVE_FLAG)

apply-stage:
	@cd environments/stage && terraform apply $(AUTO_APPROVE_FLAG)

apply-prod:
	@cd environments/prod && terraform apply $(AUTO_APPROVE_FLAG)

destroy-dev:
	@echo "⚠️  Destroying dev environment..."
	@cd environments/dev && terraform destroy $(AUTO_APPROVE_FLAG)

destroy-stage:
	@echo "⚠️  Destroying stage environment..."
	@cd environments/stage && terraform destroy $(AUTO_APPROVE_FLAG)

destroy-prod:
	@echo "⚠️  Destroying prod environment..."
	@cd environments/prod && terraform destroy $(AUTO_APPROVE_FLAG)

destroy-bootstrap:
	@echo "⚠️  WARNING: This will destroy the state backend and all IAM roles!"
	@echo "⚠️  Make sure all environments are destroyed first."
	@echo ""
	@if [ "$$FORCE" != "1" ] && [ "$$CI" != "true" ]; then \
		read -p "Type 'yes' to proceed: " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted." && exit 1); \
	fi
	@echo ""
	@echo "Checking if state bucket needs version cleanup..."
	@bash scripts/empty_bucket_versions.sh --yes
	@echo ""
	@echo "Destroying bootstrap stack..."
	@cd bootstrap && terraform destroy $(AUTO_APPROVE_FLAG)

smoke:
	@echo "Running smoke test..."
	@bash scripts/smoke_test.sh

clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name .terraform.lock.hcl -delete 2>/dev/null || true
	@find . -type f -name "terraform.tfstate*" -not -path "*/bootstrap/*" -delete 2>/dev/null || true
	@echo "Clean complete."
