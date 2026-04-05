# Makefile for gha-cross-repo-issue-sync development.
# Run `make help` to see all available recipes.

.SILENT:
.ONESHELL:
.PHONY: setup_dev test lint clean help
.DEFAULT_GOAL := help


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


test:  ## Run all BATS tests
	bats tests/unit/

lint:  ## Run shellcheck on scripts
	shellcheck scripts/*.sh


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
