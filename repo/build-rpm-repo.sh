#!/usr/bin/env bash
# Adds the RPMs of out/ for an EL version to the dnf repository in public/rpm/<el>/x86_64, and writes
# public/rpm/podman-desktop-<el>.repo. Runs in an EL container (createrepo_c, rpm-sign, gnupg2).
# Usage: build-rpm-repo.sh <el8|el10> <base url of the published repository>
# When GPG_KEY_ID is set, the packages and the repository metadata are signed with this key
# (the key must be available in the gpg keyring).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
el=${1:?el8 or el10}
base_url=${2:?base url}
repo=$ROOT/public/rpm/$el/x86_64
mkdir -p "$repo"
find "$ROOT/out" -name "podman-desktop-*.${el}*.x86_64.rpm" -exec cp {} "$repo/" \;

gpgcheck=0
if [ -n "${GPG_KEY_ID:-}" ]; then
  gpgcheck=1
  rpmsign --define "_gpg_name $GPG_KEY_ID" --addsign "$repo"/*.rpm
fi
createrepo_c --update "$repo"
if [ -n "${GPG_KEY_ID:-}" ]; then
  gpg --batch --yes --local-user "$GPG_KEY_ID" --detach-sign --armor "$repo/repodata/repomd.xml"
  gpg --armor --export "$GPG_KEY_ID" > "$ROOT/public/podman-desktop.asc"
fi

cat > "$ROOT/public/rpm/podman-desktop-$el.repo" <<REPO
[podman-desktop]
name=Podman Desktop ($el)
baseurl=$base_url/rpm/$el/x86_64
enabled=1
gpgcheck=$gpgcheck
repo_gpgcheck=$gpgcheck
gpgkey=$base_url/podman-desktop.asc
REPO
echo "repository: $repo"
