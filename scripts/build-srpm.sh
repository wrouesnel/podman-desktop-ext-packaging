#!/usr/bin/env bash
# Builds the source RPM (for COPR) from the application archive: out/srpm/podman-desktop-ext-<version>.src.rpm.
# Runs in a container with rpm-build. Usage: build-srpm.sh <archive>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
archive=$(readlink -f "${1:?archive}")
read -r version release app_version < <("$ROOT/scripts/pkg-version.sh" "$archive")
commit=$(tar -xzOf "$archive" --wildcards '*/BUILD_INFO' | sed -n 's/^PD_COMMIT=//p')
OUT=${OUT:-$ROOT/out}
: "${PKG_MAINTAINER:?PKG_MAINTAINER must be set (Name <email>)}"
top=$(mktemp -d)
mkdir -p "$top/SPECS" "$top/SOURCES" "$OUT/srpm"
cp "$archive" "$top/SOURCES/"
sed -e "s|@VERSION@|$version|g" -e "s|@RELEASE@|$release|g" -e "s|@APP_VERSION@|$app_version|g" \
  -e "s|@COMMIT@|${commit:0:12}|g" -e "s|@PACKAGER@|$PKG_MAINTAINER|g" \
  -e "s|@DATE@|$(LC_ALL=C date -u +'%a %b %d %Y')|g" \
  "$ROOT/rpm/podman-desktop-ext.spec.in" > "$top/SPECS/podman-desktop-ext.spec"
rm -f "$OUT"/srpm/*.src.rpm
# no dist tag in the source RPM name: each build service chroot adds its own
rpmbuild -bs "$top/SPECS/podman-desktop-ext.spec" --define "_topdir $top" --define "_srcrpmdir $OUT/srpm" \
  --define "dist %{nil}" >/dev/null
rm -rf "$top"
ls "$OUT"/srpm/*.src.rpm
