SHELL := /bin/bash
HUGO  ?= hugo

# Where the controller lives, for the generated reference.
ADMITIK_REPO ?= ../admitik

# Hugo speaks the Dart Sass embedded protocol, and only the native binary that
# comes inside sass-embedded does. npm installs one per libc, so the first one
# that actually runs is the one for this machine.
SASS_DIR := $(shell for d in node_modules/sass-embedded-*/dart-sass; do \
	if "$$d/sass" --version >/dev/null 2>&1; then echo "$$d"; break; fi; done)
ifneq ($(SASS_DIR),)
export PATH := $(CURDIR)/$(SASS_DIR):$(PATH)
endif

.PHONY: help deps build serve check clean version flags

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

deps: ## Install the tooling the theme and the site need
	npm ci
	npm ci --prefix themes/docsy

build: ## Build the site into public/
	$(HUGO) --gc --minify

check: ## Build the site and fail on a broken internal link
	$(HUGO) --gc --minify
	./hack/check-links.py public

serve: ## Serve the site on http://localhost:1313
	$(HUGO) server

clean: ## Remove the build output
	rm -rf public resources .hugo_build.lock

flags: ## Regenerate the flags table from the controller
	@mkdir -p .build
	cd $(ADMITIK_REPO) && go build -o $(CURDIR)/.build/admitik ./cmd
	cd hack/gen-flags && go run . -binary $(CURDIR)/.build/admitik -file $(CURDIR)/content/en/docs/configuration.md

version: ## Archive the current content and move the root to the next version
	@test -n "$(VERSION)" || (echo "usage: make version VERSION=2.1.0 [NEXT=2.1.1]" && exit 1)
	./hack/version.sh "$(VERSION)" "$(NEXT)"
