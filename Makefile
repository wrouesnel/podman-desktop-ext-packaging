# Builds Podman Desktop Ext, its source packages, and tests them, in containers (podman).
#
#   make app            build the application archive out/podman-desktop-ext-<version>-linux-x64.tar.gz, on EL8
#   make srpm           build the source RPM (for COPR) in out/srpm/
#   make deb-source     build the Debian source packages (for the PPA) in out/deb-source/<series>/
#   make test           rebuild the binary packages from the source packages for each target, as the build services
#                       do, and install and start each in a clean container of its distribution
#   make test-<target>  the same for one target: el8, el10, fedora-43, fedora-44, fedora-45, noble, resolute
#   make all            everything above
#
# Variables: see upstream.env (PD_REPO, PD_REF, NODE_VERSION), and
#   PD_LOCAL_SRC   build from a local git checkout instead of PD_REPO (e.g. PD_LOCAL_SRC=../podman-desktop-ext)
#   PKG_MAINTAINER packager identity "Name <email>" (default: git config user.name / user.email)
#   PKG_RELEASE    package release number (default 1)

include upstream.env
export PD_REPO PD_REF NODE_VERSION

PODMAN ?= podman
PKG_MAINTAINER ?= $(shell git config user.name) <$(shell git config user.email)>
PKG_RELEASE ?= 1
IMAGE_PREFIX ?= localhost/podman-desktop-ext-pkg

# the Ubuntu series of the PPA, and the RPM targets of COPR, with the container images to test them in
DEB_SERIES := noble resolute
RPM_TARGETS := el8 el10 fedora-43 fedora-44 fedora-45
image_noble := docker.io/library/ubuntu:24.04
image_resolute := docker.io/library/ubuntu:26.04
image_el8 := docker.io/library/rockylinux:8
image_el10 := docker.io/library/almalinux:10
image_fedora-43 := registry.fedoraproject.org/fedora:43
image_fedora-44 := registry.fedoraproject.org/fedora:44
image_fedora-45 := registry.fedoraproject.org/fedora:45

EL8_IMAGE := $(IMAGE_PREFIX)/build-el8
DEB_TOOLS_IMAGE := $(IMAGE_PREFIX)/deb-tools

# SELinux labels are disabled rather than relabelling the mounted host directories (:Z)
RUN := $(PODMAN) run --rm --security-opt label=disable -v $(CURDIR):/pkg -w /pkg \
	-e PKG_MAINTAINER="$(PKG_MAINTAINER)" -e PKG_RELEASE=$(PKG_RELEASE)
ifdef PD_LOCAL_SRC
APP_SRC := -v $(abspath $(PD_LOCAL_SRC)):/src:ro -e PD_REPO=/src
else
APP_SRC := -e PD_REPO
endif

# the latest file matching a pattern, resolved by the shell when the recipe runs
# (make's $(wildcard) caches the directory contents, and does not see the files created by the previous targets)
latest = "$$(ls -1 $(1) 2>/dev/null | sort | tail -1)"
ARCHIVE = $(call latest,out/podman-desktop-ext-*-linux-x64.tar.gz)

.PHONY: all images app srpm deb-source sources test $(addprefix test-,$(RPM_TARGETS) $(DEB_SERIES)) clean

all: app sources test

images:
	$(PODMAN) build --build-arg NODE_VERSION=$(NODE_VERSION) -t $(EL8_IMAGE) -f containers/build-el8.Containerfile containers
	$(PODMAN) build -t $(DEB_TOOLS_IMAGE) -f containers/deb-tools.Containerfile containers

app: images
	$(RUN) $(APP_SRC) -e PD_REF -v podman-desktop-ext-pkg-pnpm:/root/.local/share/pnpm $(EL8_IMAGE) scripts/build-app.sh

srpm:
	$(RUN) $(EL8_IMAGE) scripts/build-srpm.sh $(ARCHIVE)

deb-source:
	$(RUN) $(DEB_TOOLS_IMAGE) scripts/build-deb-source.sh $(ARCHIVE) $(DEB_SERIES)

sources: srpm deb-source

test: $(addprefix test-,$(RPM_TARGETS) $(DEB_SERIES))

# rebuild in a container of the target, then install in a clean one
$(addprefix test-,$(RPM_TARGETS)): test-%:
	$(RUN) $(image_$*) scripts/rebuild-rpm.sh $(call latest,out/srpm/podman-desktop-ext-*.src.rpm) $*
	$(RUN) $(image_$*) scripts/test-install.sh $(call latest,out/rpm/$*/x86_64/podman-desktop-ext-*.rpm)

$(addprefix test-,$(DEB_SERIES)): test-%:
	$(RUN) $(image_$*) scripts/rebuild-deb.sh $(call latest,out/deb-source/$*/podman-desktop-ext_*.dsc) $*
	$(RUN) $(image_$*) scripts/test-install.sh $(call latest,out/deb/$*/podman-desktop-ext_*_amd64.deb)

clean:
	rm -rf out work
