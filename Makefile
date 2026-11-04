.DEFAULT_GOAL := help

.PHONY: help build rm

CONTAINER_FILE_DIR ?= containerfiles
CONTAINER_FLAVOR ?=
CONTAINER_FILE ?= $(CONTAINER_FILE_DIR)/Containerfile.$(CONTAINER_FLAVOR)
CONTAINER_REPO_LOCAL ?= localhost
CONTAINER_FLAG ?= latest
PODMAN_BIN ?= podman
# Override to build against a base image other than each Containerfile's
# default (the published remote fedora-toolbox-base). Useful for chaining a
# locally-built base without pushing it first, e.g.:
#   make CONTAINER_FLAVOR=fedora-toolbox-base build
#   BASE_IMAGE=localhost/fedora-toolbox-base:latest CONTAINER_FLAVOR=fedora-toolbox-devel make build
BASE_IMAGE ?=

help: ## Display help information
	@printf "\033[33mTargets:\033[0m\n\n"
	@grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@printf "\n\033[33mAvailable Flavors:\033[0m\n"
	@printf "CONTAINER_FLAVOR=\n"
	@ls -1 $(CONTAINER_FILE_DIR)/Containerfile.* | xargs -i basename {} | sed -e 's/^Containerfile./\t/g'

build: $(CONTAINER_FILE) ## Build an image using instructions from Containerfiles
	@echo "Build $(CONTAINER_FLAVOR)..."
	$(PODMAN_BIN) build \
		--file $(CONTAINER_FILE) \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE)) \
		--squash \
		--tag $(CONTAINER_REPO_LOCAL)/$(CONTAINER_FLAVOR):$(CONTAINER_FLAG) \
		.

rm: $(CONTAINER_FILE) ## Remove one or more containers
	@echo "Remove $(CONTAINER_FLAVOR)..."
	@CONTAINER_IMAGE=$$($(PODMAN_BIN) images --filter reference=$(CONTAINER_REPO_LOCAL)/$(CONTAINER_FLAVOR) --format "{{.ID}}"); \
	echo "Container Image: $${CONTAINER_IMAGE}"; \
	if [ -n "$${CONTAINER_IMAGE}" ]; then \
		$(PODMAN_BIN) rmi -f $${CONTAINER_IMAGE}; \
	else \
		echo "No image found matching $(CONTAINER_REPO_LOCAL)/$(CONTAINER_FLAVOR)"; \
	fi
