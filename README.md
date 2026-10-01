# Podman Desktop packaging

RPM and Debian packages of [Podman Desktop](https://github.com/podman-desktop/podman-desktop), for:

| Target | Package | Built on |
| --- | --- | --- |
| RHEL 8 and compatible (Rocky, Alma) | `podman-desktop-<version>.el8.x86_64.rpm` | Rocky Linux 8 |
| RHEL 10 and compatible | `podman-desktop-<version>.el10.x86_64.rpm` | AlmaLinux 10 |
| Ubuntu 24.04 (noble) | `podman-desktop_<version>~ubuntu24.04_amd64.deb` | Ubuntu 24.04 |

The sources to package are configured in [`upstream.env`](upstream.env) (repository and git ref).

## How it works

Podman Desktop is an Electron application built with Node.js and pnpm: building it requires network access to
thousands of npm packages, which the distribution build systems (Koji, Launchpad) do not allow. The application is
therefore built once, and the result is repackaged natively for each distribution:

1. `scripts/build-app.sh` builds the application in a **Rocky Linux 8** container: EL8 has the oldest glibc (2.28)
   of the targets, so the native modules compiled during the build run on all of them (the Electron binaries
   themselves require glibc 2.25). The result is `out/podman-desktop-app-<version>-x86_64.tar.gz`: the application,
   the desktop entry, AppStream metadata and icons, and `BUILD_INFO` (repository, ref, commit).
2. `scripts/build-rpm.sh` / `scripts/build-deb.sh` package it in a container of each target distribution, so the
   dependencies are computed from the ELF binaries against the libraries of the distribution
   (`rpmbuild` automatic requires, `dpkg-shlibdeps`).
3. `scripts/test-install.sh` installs each package with `dnf` / `apt` in a clean container of its distribution
   (resolving the dependencies from the distribution repositories), checks the libraries of all the binaries, and
   starts the application under a virtual display: Xvfb, or Xwayland in a headless weston on EL10, which no longer
   ships an X server (weston comes from EPEL, for the test only).

Package layout: the application in `/opt/podman-desktop`, `/usr/bin/podman-desktop`, the desktop entry
`io.podman_desktop.PodmanDesktop.desktop` (also handling `podman-desktop://` links), icons and AppStream metadata.
`chrome-sandbox` is setuid root (Electron sandbox when unprivileged user namespaces are not available), and the
Debian package installs an AppArmor profile allowing user namespaces, as Ubuntu 24.04 restricts them.

The in-application updater of Podman Desktop is disabled on Linux: updates come from the package manager.

## Building locally

Requires `podman` and `make`.

```sh
make app                                  # build the application from upstream.env
make app PD_LOCAL_SRC=../podman-desktop   # or from a local checkout (its committed HEAD of PD_REF)
make packages                             # RPMs (EL8, EL10) and the Debian package in out/
make test                                 # install and start test of each package
```

`PKG_MAINTAINER` ("Name <email>", default: your git identity) and `PKG_RELEASE` (default 1) can be set.
Pre-release versions (`1.31.0-next`) are packaged as `1.31.0~next` with the build date and commit in the release,
so that they sort before the final version.

## Package repositories

`make repos REPO_BASE_URL=<url>` builds in `public/`:

- `rpm/el8/x86_64`, `rpm/el10/x86_64`: dnf repositories, and `rpm/podman-desktop-el8.repo` / `-el10.repo`
- `deb/`: an apt repository with the `noble` suite
- `podman-desktop.asc`: the public signing key

The packages and repository metadata are signed when `GPG_KEY_ID` is set (the key must be in your gpg keyring).

The [build workflow](.github/workflows/build.yml) builds and tests the packages on every push, and for `v*` tags
publishes the repositories on GitHub Pages (the latest packages only) and attaches the packages to the release.
It needs:

- the repository variable `PKG_MAINTAINER`
- the secret `GPG_PRIVATE_KEY` (armored private signing key, without passphrase)
- GitHub Pages enabled with "GitHub Actions" as source

### Installing from the repositories

RHEL 8 / 10 (replace `el8` by `el10` for RHEL 10):

```sh
sudo curl -o /etc/yum.repos.d/podman-desktop.repo <url>/rpm/podman-desktop-el8.repo
sudo dnf install podman-desktop
```

Ubuntu 24.04:

```sh
curl -fsSL <url>/podman-desktop.asc | sudo gpg --dearmor -o /usr/share/keyrings/podman-desktop.gpg
echo "deb [signed-by=/usr/share/keyrings/podman-desktop.gpg] <url>/deb noble main" \
  | sudo tee /etc/apt/sources.list.d/podman-desktop.list
sudo apt update && sudo apt install podman-desktop
```

## Notes

- Upstream Podman Desktop only publishes Flathub / flatpak and tar.gz builds for Linux (Fedora packaging is
  discussed in [podman-desktop#14676](https://github.com/podman-desktop/podman-desktop/issues/14676)).
- Builds from the upstream sources embed the upstream telemetry configuration (`product.json`), and use the
  Podman Desktop name and icons: decide whether it is appropriate for builds of modified sources before publishing.
- x86_64 only for now (arm64 would need an arm64 build of the application).
