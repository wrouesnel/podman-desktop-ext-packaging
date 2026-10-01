#!/usr/bin/env bash
# Builds the RPM from the application artifact, for the distribution of the container it runs in.
# Usage: build-rpm.sh <artifact>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
artifact=$(readlink -f "${1:?artifact}")
read -r version release < <("$ROOT/scripts/pkg-version.sh" "$artifact")
app_version=$(tar -xzOf "$artifact" ./BUILD_INFO | sed -n 's/^APP_VERSION=//p')
OUT=${OUT:-$ROOT/out}
: "${PKG_MAINTAINER:?PKG_MAINTAINER must be set (Name <email>)}"
top=$(mktemp -d)
rpmbuild -bb "$ROOT/rpm/podman-desktop.spec" \
  --define "_topdir $top" \
  --define "_sourcedir $(dirname "$artifact")" \
  --define "_rpmdir $OUT" \
  --define "pkg_version $version" \
  --define "pkg_release $release" \
  --define "app_version $app_version" \
  --define "pkg_maintainer $PKG_MAINTAINER"
rm -rf "$top"
find "$OUT" -name "podman-desktop-$version-$release*.rpm" -newer "$artifact" -print
