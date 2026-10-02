#!/usr/bin/env bash
# Adds the Debian packages of out/ for a suite to the apt repository in public/deb, with a flat
# "dists/<suite>/main" layout. Runs in an Ubuntu container (apt-utils, gnupg).
# Usage: build-deb-repo.sh <suite, e.g. noble>
# When PACKAGE_SIGNING_KEY_FINGERPRINT is set, the Release file is signed with this key (InRelease and Release.gpg;
# its passphrase is read from PACKAGE_SIGNING_KEY_PASSPHRASE).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
suite=${1:?suite}
repo=$ROOT/public/deb
pool=$repo/pool/main/p/podman-desktop
dist=$repo/dists/$suite/main/binary-amd64
mkdir -p "$pool" "$dist"
find "$ROOT/out" -name "podman-desktop_*~ubuntu*_amd64.deb" -exec cp {} "$pool/" \;

cd "$repo"
apt-ftparchive packages pool > "dists/$suite/main/binary-amd64/Packages"
gzip -9kf "dists/$suite/main/binary-amd64/Packages"
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="podman-desktop" \
  -o APT::FTPArchive::Release::Suite="$suite" \
  -o APT::FTPArchive::Release::Codename="$suite" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  -o APT::FTPArchive::Release::Components="main" \
  release "dists/$suite" > "dists/$suite/Release"
if [ -n "${PACKAGE_SIGNING_KEY_FINGERPRINT:-}" ]; then
  "$ROOT/repo/gpg-sign" --yes --local-user "$PACKAGE_SIGNING_KEY_FINGERPRINT" --clearsign -o "dists/$suite/InRelease" "dists/$suite/Release"
  "$ROOT/repo/gpg-sign" --yes --local-user "$PACKAGE_SIGNING_KEY_FINGERPRINT" --detach-sign --armor -o "dists/$suite/Release.gpg" "dists/$suite/Release"
  gpg --armor --export "$PACKAGE_SIGNING_KEY_FINGERPRINT" > "$ROOT/public/podman-desktop.asc"
fi
echo "repository: $repo ($suite)"
