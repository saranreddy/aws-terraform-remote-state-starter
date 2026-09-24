.PHONY: help doctor bootstrap backend-configs init-dev init-stage init-prod plan-dev plan-stage plan-prod apply-dev apply-stage apply-prod destroy-dev destroy-stage destroy-prod destroy-bootstrap smoke clean

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
	@echo "Variable overrides:"
	@echo "  ENV=dev|stage|prod    - Target environment (for shortcuts)"
	@echo ""
	@echo "Examples:"
	@echo "  make bootstrap"
	@echo "  make init-dev"
	@echo "  make apply-dev"
	@echo "  make smoke"
	@echo ""
	@echo "Teardown sequence:"
	@echo "  make destroy-dev"
	@echo "  make destroy-stage"
	@echo "  make destroy-prod"
	@echo "  make destroy-bootstrap"

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
	@cd environments/dev && terraform apply

apply-stage:
	@cd environments/stage && terraform apply

apply-prod:
	@cd environments/prod && terraform apply

destroy-dev:
	@echo "⚠️  Destroying dev environment..."
	@cd environments/dev && terraform destroy

destroy-stage:
	@echo "⚠️  Destroying stage environment..."
	@cd environments/stage && terraform destroy

destroy-prod:
	@echo "⚠️  Destroying prod environment..."
	@cd environments/prod && terraform destroy

destroy-bootstrap:
	@echo "⚠️  WARNING: This will destroy the state backend and all IAM roles!"
	@echo "⚠️  Make sure all environments are destroyed first."
	@echo ""
	@read -p "Type 'yes' to proceed: " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted." && exit 1)
	@echo ""
	@echo "Checking if state bucket needs version cleanup..."
	@bash scripts/empty_bucket_versions.sh --yes
	@echo ""
	@echo "Destroying bootstrap stack..."
	@cd bootstrap && terraform destroy

smoke:
	@echo "Running smoke test..."
	@bash scripts/smoke_test.sh

clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name .terraform.lock.hcl -delete 2>/dev/null || true
	@find . -type f -name "terraform.tfstate*" -not -path "*/bootstrap/*" -delete 2>/dev/null || true
	@echo "Clean complete."
