# Podman Desktop Ext packaging

Packages of [Podman Desktop Ext](https://github.com/wrouesnel/podman-desktop-ext), an extended build of
[Podman Desktop](https://github.com/podman-desktop/podman-desktop) (tabbed and split pod terminals, a
PersistentVolumeClaim file browser, a ConfigMap / Secret value editor, pages for all the Kubernetes resources and
custom resources). It installs side by side with Podman Desktop: its own name, `podman-desktop-ext` command, desktop
entry, settings and data (`~/.config/containers/podman-desktop-ext`, `~/.local/share/containers/podman-desktop-ext`).
Its telemetry is disabled.

| Target | Repository | Built by |
| --- | --- | --- |
| Ubuntu 24.04 (noble), 26.04 (resolute) | [ppa:w-rouesnel/podman-desktop-ext](https://launchpad.net/~w-rouesnel/+archive/ubuntu/podman-desktop-ext) | Launchpad |
| RHEL 8 and 10 (Rocky, Alma), Fedora 43, 44, 45 | [wrouesnel/podman-desktop-ext](https://copr.fedorainfracloud.org/coprs/wrouesnel/podman-desktop-ext/) | COPR |

x86_64 only. The sources to package are configured in [`upstream.env`](upstream.env) (repository and git ref).

## Installing

Ubuntu 24.04 and 26.04, from the PPA
[ppa:w-rouesnel/podman-desktop-ext](https://launchpad.net/~w-rouesnel/+archive/ubuntu/podman-desktop-ext):

```sh
sudo add-apt-repository ppa:w-rouesnel/podman-desktop-ext
sudo apt install podman-desktop-ext
```

Fedora, and RHEL 8 / 10 and their rebuilds (Rocky Linux, AlmaLinux), from COPR
[wrouesnel/podman-desktop-ext](https://copr.fedorainfracloud.org/coprs/wrouesnel/podman-desktop-ext/):

```sh
sudo dnf install dnf-plugins-core     # RHEL 8 / 10: provides "dnf copr"
sudo dnf copr enable wrouesnel/podman-desktop-ext
sudo dnf install podman-desktop-ext
```

Then start "Podman Desktop Ext" from the applications, or run `podman-desktop-ext`.

### Moving from the old repositories

Until 1.32.0+wrouesnel.2 this repository (then `podman-desktop-packaging`) published a `podman-desktop` package in
its own dnf / apt repositories on GitHub Pages. They are retired and no longer served: remove them, and the old
package if you like (it is a different package, so both can stay installed):

```sh
sudo rm /etc/apt/sources.list.d/podman-desktop.list /usr/share/keyrings/podman-desktop.gpg   # Ubuntu
sudo rm /etc/yum.repos.d/podman-desktop.repo                                                  # RHEL
```

## How it works

Podman Desktop is an Electron application built with Node.js and pnpm: building it requires network access to
thousands of npm packages, and Node.js 24, which the build services (Launchpad, COPR) do not provide, as they build
offline. The application is therefore built once from the sources, by the CI of this repository, and the source
packages repackage that build:

1. `scripts/build-app.sh` builds the application in a **Rocky Linux 8** container: EL8 has the oldest glibc (2.28)
   of the targets, so the native modules compiled during the build run on all of them. The result is the compiled
   application archive `out/podman-desktop-ext-<version>-linux-x64.tar.gz` (and its `.sha256`), attached to the
   GitHub releases: `podman-desktop-ext-<version>/` with `app/` (the application), `share/` (desktop entry, AppStream
   metadata, icons, managed configuration) and `BUILD_INFO` (repository, ref, commit).
2. `scripts/build-srpm.sh` builds the source RPM (`rpm/podman-desktop-ext.spec.in`, the archive as `Source0`), and
   `scripts/build-deb-source.sh` the Debian source package of each Ubuntu series (`deb/debian/`, the archive as the
   orig tarball). The build services build the binary packages from them, computing the dependencies from the ELF
   binaries against the libraries of each distribution (`rpmbuild` automatic requires, `dpkg-shlibdeps`).
3. CI rebuilds the binary packages from the source packages in a container of each target, as the build services do
   (`scripts/rebuild-rpm.sh`, `scripts/rebuild-deb.sh`), and `scripts/test-install.sh` installs each package with
   `dnf` / `apt` in a clean container (resolving the dependencies from the distribution repositories), checks the
   libraries of all the binaries, starts the application under a virtual display (Xvfb, or Xwayland in a headless
   weston on EL10, which no longer ships an X server), and checks that the telemetry is disabled and that the
   application keeps its settings and data apart from Podman Desktop's.

Package layout: the application in `/opt/podman-desktop-ext`, `/usr/bin/podman-desktop-ext`, the desktop entry
`io.podman_desktop.PodmanDesktopExt.desktop` (also handling `podman-desktop-ext://` links), icons and AppStream
metadata. `chrome-sandbox` is setuid root (Electron sandbox when unprivileged user namespaces are not available), and
the Debian package installs an AppArmor profile allowing user namespaces, as Ubuntu restricts them.

The telemetry is disabled with the [managed configuration](https://podman-desktop.io/docs/configuration/managed-configuration)
of the application: `/usr/share/podman-desktop-ext/default-settings.json` sets `telemetry.enabled` to `false` (and
`telemetry.check`, so the welcome screen does not ask), and `/usr/share/podman-desktop-ext/locked.json` locks both
settings. These are configuration files of the packages: administrators can add other managed settings to them.

The in-application updater is disabled on Linux: updates come from the package manager.

## Building locally

Requires `podman` and `make`.

```sh
make app                                      # build the application archive from upstream.env
make app PD_LOCAL_SRC=../podman-desktop-ext   # or from a local checkout (its committed PD_REF)
make sources                                  # the source RPM and the Debian source packages in out/
make test                                     # rebuild, install and start test of every target
make test-noble                               # or of one: el8, el10, fedora-43, fedora-44, fedora-45, noble, resolute
```

`PKG_MAINTAINER` ("Name <email>", default: your git identity) and `PKG_RELEASE` (default 1) can be set.
Pre-release versions (`1.31.0-next`) are packaged as `1.31.0~next` with the build date and commit in the release,
so that they sort before the final version.

## Versions and releases

Podman Desktop Ext is versioned one minor version above upstream main, with a `+wrouesnel.N` build metadata suffix
(e.g. `1.32.0+wrouesnel.3` for upstream `1.31.0-next`): build metadata keeps the version valid for semver ranges, and
rpm and dpkg sort it after the corresponding upstream versions. The Debian packages are versioned
`<version>-<release>~<series>1`. A release is made by:

1. tagging the sources with `v<version>` in [wrouesnel/podman-desktop-ext](https://github.com/wrouesnel/podman-desktop-ext),
2. setting `PD_REF` to this tag in `upstream.env`,
3. tagging this repository with the same `v<version>`.

The [build workflow](.github/workflows/build.yml) builds the application and the source packages, and tests every
target, on pull requests and on every push, so a broken package build fails the CI. For `v*` tags, it then signs
and uploads the Debian source packages to the PPA, submits the source RPM to COPR, and creates the GitHub release
with the application archive and its checksum (no OS packages are attached to releases). Packaging-only changes
(same sources) increase `PKG_RELEASE` instead.

### One-time setup

- The PPA uploads are signed with the shared Launchpad key `2A12 8435 A6FE 8BD7 51AA  5787 2095 9AB8 0709 6ADB`
  ("Will Rouesnel (GPG key for launchpad signing)", registered on the Launchpad account `~w-rouesnel`), in the
  secrets `PACKAGE_SIGNING_KEY` (passphrase protected) and `PACKAGE_SIGNING_KEY_PASSPHRASE`, with the variable
  `PACKAGE_SIGNING_KEY_FINGERPRINT`. COPR signs the RPMs with its own key.
- The PPA `podman-desktop-ext` on Launchpad (amd64), and the COPR project `wrouesnel/podman-desktop-ext` with the
  chroots `epel-8-x86_64`, `epel-10-x86_64`, `fedora-43-x86_64`, `fedora-44-x86_64` and `fedora-45-x86_64`.
- The secret `COPR_CONFIG` (the COPR API configuration, `~/.config/copr` from
  <https://copr.fedorainfracloud.org/api/>, valid 180 days), and the variable `PKG_MAINTAINER`. The variables `PPA`
  and `COPR_PROJECT` can override the defaults.

## Notes

- Upstream Podman Desktop only publishes Flathub / flatpak and tar.gz builds for Linux (Fedora packaging is
  discussed in [podman-desktop#14676](https://github.com/podman-desktop/podman-desktop/issues/14676)).
- The packages use the Podman Desktop icons.
