# Makefile for gha-cross-repo-issue-sync development.
# Run `make` to see all available recipes.

# Require GNU Make >= 3.82 (.ONESHELL support)
ifeq ($(filter oneshell,$(.FEATURES)),)
$(error GNU Make >= 3.82 required (.ONESHELL). macOS ships 3.81 — install via: brew install make, then use gmake)
endif

.SILENT:
.ONESHELL:
.PHONY: \
	setup_dev \
	test lint validate \
	clean \
	help
.DEFAULT_GOAL := help

# -- quiet mode (default: quiet; set VERBOSE=1 for full output) --
VERBOSE ?= 0
ifeq ($(VERBOSE),0)
  BATS_FILTER := | grep -v '^ok '
else
  BATS_FILTER :=
endif


# MARK: SETUP


setup_dev:  ## Install dev dependencies (bats, shellcheck, actionlint)
	echo "Setting up dev environment ..."
	command -v bats >/dev/null || npm install -g bats
	if command -v apt-get > /dev/null; then
		command -v shellcheck >/dev/null || sudo apt-get install -y shellcheck
		command -v actionlint >/dev/null || { \
			echo "Install actionlint: https://github.com/rhysd/actionlint#install"; }
	fi
	echo "Dev environment ready."
	echo "  bats:        $$(bats --version 2>/dev/null || echo 'not installed')"
	echo "  shellcheck:  $$(shellcheck --version 2>/dev/null | grep '^version:' || echo 'not installed')"
	echo "  actionlint:  $$(actionlint --version 2>/dev/null || echo 'not installed')"


# MARK: QUALITY


test:  ## Run all BATS tests (VERBOSE=1 for full output)
	bats tests/unit/ $(BATS_FILTER)

lint:  ## Run shellcheck on scripts
	shellcheck scripts/*.sh

validate: lint test  ## Full validation (lint + test)


# MARK: CLEANUP


clean:  ## Remove test artifacts
	rm -rf /tmp/claude-*/bats-tmp
	echo "Test artifacts cleaned."


# MARK: HELP


help:  ## Show available recipes grouped by section
	@echo "Usage: make [recipe]"
	@echo ""
	@awk '/^# MARK:/ { \
		section = substr($$0, index($$0, ":")+2); \
		printf "\n\033[1m%s\033[0m\n", section \
	} \
	/^[a-zA-Z0-9_-]+:.*?##/ { \
		helpMessage = match($$0, /## (.*)/); \
		if (helpMessage) { \
			recipe = $$1; \
			sub(/:/, "", recipe); \
			printf "  \033[36m%-22s\033[0m %s\n", recipe, substr($$0, RSTART + 3, RLENGTH) \
		} \
	}' $(MAKEFILE_LIST)
