# jxc_rails Makefile

.PHONY: help setup test lint ci scan console build

.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "jxc_rails Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""

setup: ## Install dependencies and git hooks
	bundle install
	lefthook install

test: ## Run the test suite
	bundle exec rspec

lint: ## Lint code with RuboCop
	bundle exec rubocop

ci: ## Run everything CI runs (the gem's default rake task: spec + rubocop)
	bundle exec rake

console: ## Open an IRB console with the gem loaded
	bin/console

build: ## Build the gem into pkg/
	bundle exec rake build

scan: ## Scan the committed tree for secrets (gitleaks)
	@tmp=$$(mktemp -d) && git archive HEAD | tar -x -C "$$tmp" && \
		gitleaks dir "$$tmp" --no-banner --redact --config .gitleaks.toml; \
		rc=$$?; rm -rf "$$tmp"; exit $$rc
