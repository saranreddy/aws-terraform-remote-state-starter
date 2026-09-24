# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-09-24

### Fixed
- **Makefile non-interactive modes**: `FORCE=1` and `CI=true` now skip all interactive confirmations, not just script prompts. Previously `destroy-bootstrap` would still prompt even with `FORCE=1`.
- **Terraform version parsing in doctor.sh**: Robust parsing that works on macOS BSD tools without requiring jq. Falls back through multiple methods (python3 JSON parsing, plain grep, awk) to handle different Terraform output formats.
- **AWS CLI architecture mismatch detection**: `doctor.sh` now actually executes `aws --version` and `aws sts get-caller-identity` to catch broken installations (e.g., x86_64 binary on arm64 Mac). Provides clear error messages with reinstallation guidance.
- **IAM trust policy precision**: Apply role trust conditions now use `StringEquals` instead of `StringLike` for exact values (no wildcards). Plan role correctly keeps `StringLike` for its pattern matching needs.

### Added
- **AUTO_APPROVE environment variable**: Set `AUTO_APPROVE=1` to add `-auto-approve -input=false` to all `terraform apply` and `terraform destroy` commands. `FORCE=1` implies this for destroy operations.
- **AWS_CLI override support**: Scripts honor `AWS_CLI` environment variable (e.g., `export AWS_CLI="python3 -m awscli"`) for non-standard AWS CLI installations.
- **"Who This Is For" section** in README: Clear guidance on when to use this starter (small teams, startups, platform engineers) and when not to (Terraform Cloud users, multi-account setups, experiments). Explains single-account scope and common use cases.

### Changed
- Makefile help text updated to document `AUTO_APPROVE=1`, `FORCE=1`, and `CI=true` environment variables with usage examples.

## [0.1.0] - 2026-09-24

### Added
- Initial release of AWS Terraform Remote State Starter
- Bootstrap stack for S3 backend + DynamoDB locking
- GitHub OIDC provider and IAM roles for GitHub Actions
- Dev, stage, and prod environment scaffolding
- Simple workload module (S3 bucket + SSM parameter)
- GitHub Actions workflow for CI and CD
- Makefile targets for common operations
- Doctor script for prerequisites checking
- Smoke test for end-to-end validation
- Comprehensive README with quickstart and troubleshooting
- MIT License
