#!/usr/bin/env bash
# Builds the Debian package from the application artifact, for the distribution of the container it runs in.
# Usage: build-deb.sh <artifact>
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
artifact=$(readlink -f "${1:?artifact}")
read -r version release < <("$ROOT/scripts/pkg-version.sh" "$artifact")
OUT=${OUT:-$ROOT/out}
: "${PKG_MAINTAINER:?PKG_MAINTAINER must be set (Name <email>)}"
. /etc/os-release
debversion="$version-$release~${ID}${VERSION_ID}"

work=$(mktemp -d)
tree=$work/tree
mkdir -p "$tree/opt" "$tree/usr/bin" "$tree/usr/share/doc/podman-desktop" "$tree/etc/apparmor.d" "$tree/DEBIAN"
tar -C "$work" -xzf "$artifact"
mv "$work/podman-desktop" "$tree/opt/podman-desktop"
cp -a "$work/share/." "$tree/usr/share/"
cp "$work/BUILD_INFO" "$tree/usr/share/doc/podman-desktop/"
ln -s /opt/podman-desktop/podman-desktop "$tree/usr/bin/podman-desktop"
cp "$ROOT/deb/apparmor-podman-desktop" "$tree/etc/apparmor.d/podman-desktop"
# setuid sandbox helper, used when unprivileged user namespaces are not available
chmod 4755 "$tree/opt/podman-desktop/chrome-sandbox"
install -m 0755 "$ROOT/deb/postinst" "$ROOT/deb/postrm" "$tree/DEBIAN/"
echo /etc/apparmor.d/podman-desktop > "$tree/DEBIAN/conffiles"

# dependencies of the Electron binaries (the libraries bundled with Electron are resolved from the application)
mkdir -p "$work/debian"
printf 'Source: podman-desktop\n\nPackage: podman-desktop\nArchitecture: amd64\n' > "$work/debian/control"
app=$tree/opt/podman-desktop
shlibs=$(cd "$work" && dpkg-shlibdeps -O --ignore-missing-info -l"$app" \
  "$app/podman-desktop" "$app/chrome_crashpad_handler" "$app"/*.so*)
depends=$(sed -n 's/^shlibs:Depends=//p' <<<"$shlibs")

installed_size=$(du -sk --exclude=DEBIAN "$tree" | cut -f1)
cat > "$tree/DEBIAN/control" <<CONTROL
Package: podman-desktop
Version: $debversion
Architecture: amd64
Maintainer: $PKG_MAINTAINER
Installed-Size: $installed_size
Depends: $depends, xdg-utils
Recommends: podman
Section: devel
Priority: optional
Homepage: https://podman-desktop.io
Description: Manage Podman and other container engines from a single UI
 Podman Desktop is an open source graphical tool enabling you to seamlessly work
 with containers and Kubernetes from your local environment.
CONTROL

mkdir -p "$OUT"
deb=$OUT/podman-desktop_${debversion}_amd64.deb
dpkg-deb --root-owner-group -Zxz --build "$tree" "$deb" >/dev/null
rm -rf "$work"
echo "$deb"
