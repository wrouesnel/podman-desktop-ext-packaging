#!/usr/bin/env bash
# Builds the Debian source packages (for the Launchpad PPA) from the application archive, one per Ubuntu series:
# out/deb-source/<series>/podman-desktop-ext_<version>-<release>~<series>1{.dsc,.debian.tar.xz,_source.changes}
# and the orig tarball (the application archive itself, the same for all the series).
# The packages are not signed (see the release workflow). Runs in a container with dpkg-dev and debhelper.
# Usage: build-deb-source.sh <archive> <series>...
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
archive=$(readlink -f "${1:?archive}")
shift
[ $# -gt 0 ] || { echo "no Ubuntu series given" >&2; exit 1; }
read -r version release app_version < <("$ROOT/scripts/pkg-version.sh" "$archive")
commit=$(tar -xzOf "$archive" --wildcards '*/BUILD_INFO' | sed -n 's/^PD_COMMIT=//p')
OUT=${OUT:-$ROOT/out}
: "${PKG_MAINTAINER:?PKG_MAINTAINER must be set (Name <email>)}"

for series in "$@"; do
  debversion="$version-$release~${series}1"
  dir=$OUT/deb-source/$series
  rm -rf "$dir"
  mkdir -p "$dir"
  # the orig tarball is the application archive: its top directory is podman-desktop-ext-<app version>
  cp "$archive" "$dir/podman-desktop-ext_$version.orig.tar.gz"
  tar -C "$dir" -xzf "$archive"
  tree=$dir/podman-desktop-ext-$app_version
  cp -a "$ROOT/deb/debian" "$tree/debian"
  sed "s|@MAINTAINER@|$PKG_MAINTAINER|" "$tree/debian/control.in" > "$tree/debian/control"
  rm "$tree/debian/control.in"
  cat > "$tree/debian/changelog" <<CHANGELOG
podman-desktop-ext ($debversion) $series; urgency=medium

  * Podman Desktop Ext $app_version (${commit:0:12}), built from
    https://github.com/wrouesnel/podman-desktop-ext

 -- $PKG_MAINTAINER  $(LC_ALL=C date -u -R)
CHANGELOG
  # -sa: each upload carries the orig tarball (identical for all the series)
  (cd "$tree" && dpkg-buildpackage -S -sa -d -us -uc >/dev/null)
  rm -rf "$tree"
  ls "$dir"/*_source.changes
done
