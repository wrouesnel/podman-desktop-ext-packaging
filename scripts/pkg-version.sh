#!/usr/bin/env bash
# Prints the package version and release for the application artifact given as argument, as
# "VERSION RELEASE", for both RPM and Debian packages:
# - VERSION: upstream version with '-' replaced by '~' (1.31.0-next -> 1.31.0~next, sorting before 1.31.0)
# - RELEASE: PKG_RELEASE (default 1), followed for pre-releases by the build date and commit
set -euo pipefail
artifact=${1:?artifact}
info=$(tar -xzOf "$artifact" ./BUILD_INFO)
app_version=$(sed -n 's/^APP_VERSION=//p' <<<"$info")
commit=$(sed -n 's/^PD_COMMIT=//p' <<<"$info")
date=$(sed -n 's/^BUILD_DATE=//p' <<<"$info")
version=${app_version//-/\~}
release=${PKG_RELEASE:-1}
if [[ "$app_version" == *-* ]]; then
  release="$release.$date.git${commit:0:7}"
fi
echo "$version $release"
