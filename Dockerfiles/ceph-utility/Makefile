# Copyright 2017 The Openstack-Helm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ifndef CEPH_RELEASE
$(error The TAG variable is missing.)
endif

ifndef UBUNTU_RELEASE
$(error The ENV variable is missing.)
endif

SHELL := /bin/bash

DOCKER_REGISTRY            ?= quay.io
IMAGE_NAME                 ?= ceph-utility
IMAGE_PREFIX               ?= airship/porthole
IMAGE_TAG                  ?= latest
LABEL                      ?= mimic

IMAGE := ${DOCKER_REGISTRY}/${IMAGE_PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}

# Build ceph-utility Docker image for this project
.PHONY: images
images: build_$(IMAGE_NAME)

# Make targets intended for use by the primary targets above.
.PHONY: build_$(IMAGE_NAME)
build_$(IMAGE_NAME):
	docker build -f Dockerfile.ubuntu \
	--network host \
	--build-arg CEPH_RELEASE=$(CEPH_RELEASE) \
	--build-arg UBUNTU_RELEASE=$(UBUNTU_RELEASE) \
	$(EXTRA_BUILD_ARGS) \
	-t $(IMAGE) \
	--label $(LABEL) --label CEPH_RELEASE=$(CEPH_RELEASE) \
	.
