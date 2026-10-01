# Builds and tests the Podman Desktop packages in containers (podman).
#
#   make app            build the application artifact (out/podman-desktop-app-*.tar.gz), on EL8
#   make rpm-el8        build the EL8 RPM
#   make rpm-el10       build the EL10 RPM
#   make deb-noble      build the Ubuntu 24.04 package
#   make test           install and start each package in a clean container of its distribution
#   make repos          build the dnf / apt repositories in public/ (signed when GPG_KEY_ID is set)
#   make all            everything above
#
# Variables: see upstream.env (PD_REPO, PD_REF, NODE_VERSION), and
#   PD_LOCAL_SRC   build from a local git checkout instead of PD_REPO (e.g. PD_LOCAL_SRC=../podman-desktop)
#   PKG_MAINTAINER packager identity "Name <email>" (default: git config user.name / user.email)
#   PKG_RELEASE    package release number (default 1)
#   REPO_BASE_URL  public URL of the published repositories (for the generated .repo file)

include upstream.env
export PD_REPO PD_REF NODE_VERSION

PODMAN ?= podman
PKG_MAINTAINER ?= $(shell git config user.name) <$(shell git config user.email)>
PKG_RELEASE ?= 1
REPO_BASE_URL ?= https://example.invalid/podman-desktop-packaging
IMAGE_PREFIX ?= localhost/podman-desktop-pkg

EL8_IMAGE := $(IMAGE_PREFIX)/build-el8
EL10_IMAGE := $(IMAGE_PREFIX)/rpm-el10
NOBLE_IMAGE := $(IMAGE_PREFIX)/deb-noble

# SELinux labels are disabled rather than relabelling the mounted host directories (:Z)
RUN := $(PODMAN) run --rm --security-opt label=disable -v $(CURDIR):/pkg -w /pkg \
	-e PKG_MAINTAINER="$(PKG_MAINTAINER)" -e PKG_RELEASE=$(PKG_RELEASE) -e GPG_KEY_ID
ifdef PD_LOCAL_SRC
APP_SRC := -v $(abspath $(PD_LOCAL_SRC)):/src:ro -e PD_REPO=/src
else
APP_SRC := -e PD_REPO
endif

ARTIFACT = $(lastword $(sort $(wildcard out/podman-desktop-app-*-x86_64.tar.gz)))

.PHONY: all images app rpm-el8 rpm-el10 deb-noble packages test test-el8 test-el10 test-noble repos clean

all: app packages test repos

images:
	$(PODMAN) build --build-arg NODE_VERSION=$(NODE_VERSION) -t $(EL8_IMAGE) -f containers/build-el8.Containerfile containers
	$(PODMAN) build -t $(EL10_IMAGE) -f containers/rpm-el10.Containerfile containers
	$(PODMAN) build -t $(NOBLE_IMAGE) -f containers/deb-noble.Containerfile containers

app: images
	$(RUN) $(APP_SRC) -e PD_REF -v podman-desktop-pkg-pnpm:/root/.local/share/pnpm $(EL8_IMAGE) scripts/build-app.sh

packages: rpm-el8 rpm-el10 deb-noble

rpm-el8:
	$(RUN) $(EL8_IMAGE) scripts/build-rpm.sh $(ARTIFACT)

rpm-el10:
	$(RUN) $(EL10_IMAGE) scripts/build-rpm.sh $(ARTIFACT)

deb-noble:
	$(RUN) $(NOBLE_IMAGE) scripts/build-deb.sh $(ARTIFACT)

test: test-el8 test-el10 test-noble

test-el8:
	$(RUN) docker.io/library/rockylinux:8 scripts/test-install.sh $(lastword $(sort $(wildcard out/x86_64/podman-desktop-*.el8*.x86_64.rpm)))

test-el10:
	$(RUN) docker.io/library/almalinux:10 scripts/test-install.sh $(lastword $(sort $(wildcard out/x86_64/podman-desktop-*.el10*.x86_64.rpm)))

test-noble:
	$(RUN) docker.io/library/ubuntu:24.04 scripts/test-install.sh $(lastword $(sort $(wildcard out/podman-desktop_*~ubuntu24.04_amd64.deb)))

# the gpg keyring is mounted only when signing
GPG_MOUNT := $(if $(GPG_KEY_ID),-v $(HOME)/.gnupg:/root/.gnupg)

repos:
	$(RUN) $(GPG_MOUNT) docker.io/library/rockylinux:8 sh -c \
		'dnf -y -q install createrepo_c rpm-sign gnupg2 findutils >/dev/null && repo/build-rpm-repo.sh el8 $(REPO_BASE_URL)'
	$(RUN) $(GPG_MOUNT) docker.io/library/almalinux:10 sh -c \
		'dnf -y -q install createrepo_c rpm-sign gnupg2 findutils >/dev/null && repo/build-rpm-repo.sh el10 $(REPO_BASE_URL)'
	$(RUN) $(GPG_MOUNT) docker.io/library/ubuntu:24.04 sh -c \
		'apt-get update -qq && apt-get install -y -qq apt-utils gnupg >/dev/null && repo/build-deb-repo.sh noble'

clean:
	rm -rf out work public
