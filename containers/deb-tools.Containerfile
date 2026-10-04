# Builds the Debian source packages (dpkg-buildpackage -S runs the clean target of debian/rules, with debhelper)
FROM docker.io/library/ubuntu:24.04
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends dpkg-dev debhelper \
    && rm -rf /var/lib/apt/lists/*
