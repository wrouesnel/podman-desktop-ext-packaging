#!/usr/bin/env bash
# Rebuilds the binary package from the Debian source package in the container of its Ubuntu series (as
# Launchpad does): out/deb/<series>/podman-desktop-ext_*.deb. Usage: rebuild-deb.sh <dsc> <series>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
dsc=$(readlink -f "${1:?dsc}")
series=${2:?series}
OUT=${OUT:-$ROOT/out}
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends dpkg-dev >/dev/null
work=$(mktemp -d)
(cd "$work" && dpkg-source -x "$dsc" src >/dev/null)
apt-get build-dep -y -qq "$work/src" >/dev/null
(cd "$work/src" && dpkg-buildpackage -b -us -uc >/dev/null)
rm -rf "$OUT/deb/$series"
mkdir -p "$OUT/deb/$series"
mv "$work"/*.deb "$OUT/deb/$series/"
rm -rf "$work"
ls "$OUT/deb/$series"/*.deb
