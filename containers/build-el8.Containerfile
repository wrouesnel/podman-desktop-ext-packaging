# Builds the application on the oldest supported target (EL8, glibc 2.28), so that the native modules
# compiled during the build do not require a newer glibc than the one of the oldest target.
FROM docker.io/library/rockylinux:8

ARG NODE_VERSION
RUN dnf -y install git python3 gcc-c++ make xz tar findutils rpm-build \
    && dnf clean all
RUN curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
      | grep " node-v${NODE_VERSION}-linux-x64.tar.xz$" | sed 's# node-.*# /tmp/node.tar.xz#' | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && corepack enable
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
