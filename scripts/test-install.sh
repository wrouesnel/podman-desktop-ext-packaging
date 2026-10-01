#!/usr/bin/env bash
# Installs a package in the (clean) container it runs in, and checks that the application can start.
# Usage: test-install.sh <package.rpm|package.deb>
set -euo pipefail
pkg=$(readlink -f "${1:?package}")

echo "== install $(basename "$pkg")"
case "$pkg" in
  *.rpm)
    # the package is installed alone first: its dependencies must resolve from the distribution repositories
    dnf -y install "$pkg" >/dev/null
    dnf -y install procps-ng desktop-file-utils util-linux >/dev/null
    if dnf -y install xorg-x11-server-Xvfb xorg-x11-xauth >/dev/null 2>&1; then
      display_runner="xvfb-run -a"
    else
      # EL10 has no X server anymore: Xwayland in a headless Wayland compositor (EPEL, test tooling only)
      dnf -y install epel-release >/dev/null
      dnf -y install xwayland-run weston >/dev/null
      display_runner="xwfb-run -c weston --"
    fi
    ;;
  *.deb)
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb xauth procps desktop-file-utils >/dev/null
    display_runner="xvfb-run -a"
    ;;
  *) echo "unknown package type: $pkg" >&2; exit 1 ;;
esac

echo "== files"
test -L /usr/bin/podman-desktop
test -u /opt/podman-desktop/chrome-sandbox
desktop-file-validate /usr/share/applications/io.podman_desktop.PodmanDesktop.desktop

echo "== shared libraries"
missing=0
for file in /opt/podman-desktop/podman-desktop /opt/podman-desktop/chrome_crashpad_handler /opt/podman-desktop/*.so*; do
  if ldd "$file" 2>/dev/null | grep 'not found'; then
    echo "missing libraries for $file" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ]

echo "== launch"
# the setuid sandbox cannot be used in an unprivileged container: the launch check runs without the sandbox
useradd -m tester 2>/dev/null || true
log=/tmp/podman-desktop.log
set +e
su tester -c "cd ~ && export XDG_RUNTIME_DIR=\$(mktemp -d) && timeout 30 $display_runner /usr/bin/podman-desktop --no-sandbox" >"$log" 2>&1
status=$?
set -e
if grep -E 'error while loading shared libraries|Segmentation fault|FATAL' "$log"; then
  echo "the application failed to start" >&2
  exit 1
fi
# killed by the timeout: the application was still running after 30s
if [ "$status" -ne 124 ]; then
  echo "the application exited with status $status" >&2
  tail -30 "$log" >&2
  exit 1
fi
echo "OK: $(basename "$pkg")"
