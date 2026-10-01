FROM docker.io/library/ubuntu:24.04
# dpkg-shlibdeps maps the libraries needed by the Electron binaries to their packages:
# the runtime libraries of Electron must be installed
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends dpkg-dev fakeroot file \
      libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
      libxext6 libxfixes3 libexpat1 libdrm2 libcups2t64 libdbus-1-3 libatspi2.0-0t64 \
    && rm -rf /var/lib/apt/lists/*
