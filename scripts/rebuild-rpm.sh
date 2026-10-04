#!/usr/bin/env bash
# Rebuilds the binary RPM from the source RPM in the container of a target distribution (as COPR does):
# out/rpm/<distro>/podman-desktop-ext-*.rpm. Usage: rebuild-rpm.sh <srpm> <distro>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
srpm=$(readlink -f "${1:?source RPM}")
distro=${2:?distribution name}
OUT=${OUT:-$ROOT/out}
dnf -y -q install rpm-build >/dev/null
top=$(mktemp -d)
rm -rf "$OUT/rpm/$distro"
mkdir -p "$OUT/rpm/$distro"
rpmbuild --rebuild "$srpm" --define "_topdir $top" --define "_rpmdir $OUT/rpm/$distro" >/dev/null
rm -rf "$top"
find "$OUT/rpm/$distro" -name '*.rpm' -print
