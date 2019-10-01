# Copyright 2019 AT&T Intellectual Property.  All other rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash

# APP INFO
DOCKER_REGISTRY   ?= quay.io
IMAGE_PREFIX      ?= airshipit
IMAGE_NAME        ?=
IMAGE_TAG         ?= latest
PROXY             ?= http://proxy.foo.com:8000
NO_PROXY          ?= localhost,127.0.0.1,.svc.cluster.local
USE_PROXY         ?= false
PUSH_IMAGE        ?= false
# use this variable for image labels added in internal build process
LABEL             ?= org.airshipit.build=community
COMMIT            ?= $(shell git rev-parse HEAD)
DISTRO_SUFFIX     ?= $(DISTRO)
IMAGE             := ${DOCKER_REGISTRY}/${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}-${DISTRO_SUFFIX}
BASE_IMAGE        ?=

# VERSION INFO
GIT_COMMIT = ${COMMIT}
GIT_SHA    = $(shell git rev-parse --short HEAD)
GIT_TAG    = $(shell git describe --tags --abbrev=0 --exact-match 2>/dev/null)
GIT_DIRTY  = $(shell test -n "`git status --porcelain`" && echo "dirty" || echo "clean")

ifdef VERSION
	DOCKER_VERSION = $(VERSION)
endif

ifeq "$(DISTRO_SUFFIX)" ""
	# We expect that container is named 'porthole-xxxxx', and
	# subdirectory is named 'xxxxx'; so we cut 'porthole-' from
	# directory names here below and in next statement
	DOCKERFILE = "$(subst porthole-,,$(IMAGE_NAME))/Dockerfile"
else
	DOCKERFILE = "$(subst porthole-,,$(IMAGE_NAME))/Dockerfile.$(DISTRO_SUFFIX)"
endif

info:
	@echo "Version:           ${VERSION}"
	@echo "Git Tag:           ${GIT_TAG}"
	@echo "Git Commit:        ${GIT_COMMIT}"
	@echo "Git Tree State:    ${GIT_DIRTY}"
	@echo "Docker Version:    ${DOCKER_VERSION}"
	@echo "Registry:          ${DOCKER_REGISTRY}"

all:
	@echo "And what is there's nothing in there? You die, and there's" \
	      "nothing beyond that. Nothing. Nothing remains. Someone might" \
	      "remember you for a little while after but not for long.">&2; exit 2

check-docker:
	@if [ -z $$(which docker) ]; then \
		echo "Missing \`docker\` client which is required for development"; \
		exit 2; \
	fi

_BASE_IMAGE_ARG := $(if $(BASE_IMAGE),--build-arg FROM="${BASE_IMAGE}" ,)

build-image-$(IMAGE_NAME): check-docker
ifeq "$(IMAGE_NAME)" ""
	@echo "Missing \`IMAGE_NAME\` variable." >&2; exit 2
endif
ifeq ($(USE_PROXY), true)
	docker build --network host -t $(IMAGE) --label $(LABEL) \
		--label "org.opencontainers.image.revision=$(COMMIT)" \
		--label "org.opencontainers.image.created=$(shell date --rfc-3339=seconds --utc)" \
		--label "org.opencontainers.image.title=$(IMAGE_NAME)" \
		-f $(DOCKERFILE) \
		$(_BASE_IMAGE_ARG) \
		--build-arg http_proxy=$(PROXY) \
		--build-arg https_proxy=$(PROXY) \
		--build-arg HTTP_PROXY=$(PROXY) \
		--build-arg HTTPS_PROXY=$(PROXY) \
		--build-arg no_proxy=$(NO_PROXY) \
		--build-arg NO_PROXY=$(NO_PROXY) .
else
	docker build --network host -t $(IMAGE) --label $(LABEL) \
		--label "org.opencontainers.image.revision=$(COMMIT)" \
		--label "org.opencontainers.image.created=$(shell date --rfc-3339=seconds --utc)" \
		--label "org.opencontainers.image.title=$(IMAGE_NAME)" \
		-f $(DOCKERFILE) \
		$(_BASE_IMAGE_ARG) .
endif
ifeq ($(PUSH_IMAGE), true)
	docker push $(IMAGE)
endif

.PHONY: all build-image-$(IMAGE_NAME) build-image-% check-docker info
