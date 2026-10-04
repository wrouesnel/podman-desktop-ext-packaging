# podman-desktop-ext-packaging

Packages of the wrouesnel/podman-desktop-ext fork (Podman Desktop Ext, installable side by side with Podman
Desktop): Debian source packages for the Launchpad PPA `ppa:w-rouesnel/podman-desktop-ext` (noble, resolute) and a
source RPM for the COPR project `wrouesnel/podman-desktop-ext` (epel-8, epel-10, fedora-43/44/45), all x86_64.
Both repackage the application archive built by this repository's CI, since the build services build offline.
See README.md.

## Remotes

`origin` is the local backup `~/git/will/podman-desktop-ext-packaging.git` (push after every commit), `github` is
github.com/wrouesnel/podman-desktop-ext-packaging (push when releasing or asked). The repository was named
podman-desktop-packaging until 2026-10-04.

## Signing

- PPA uploads are signed in CI with the shared Launchpad key `2A128435A6FE8BD751AA578720959AB807096ADB`
  ("Will Rouesnel (GPG key for launchpad signing)", Launchpad account `~w-rouesnel`), exported (approved without
  asking by the global key rules) to the secrets `PACKAGE_SIGNING_KEY` and `PACKAGE_SIGNING_KEY_PASSPHRASE`, with the
  variable `PACKAGE_SIGNING_KEY_FINGERPRINT`. Its passphrase: `secret-tool lookup service gpg-passphrase fingerprint
  2A128435A6FE8BD751AA578720959AB807096ADB`. Never print it.
- COPR signs the RPMs with its own key. CI submits builds with the secret `COPR_CONFIG` (the COPR API
  configuration, expires after 180 days).
- Retired: the dnf / apt repositories on GitHub Pages and their key `058AF445927A0D7FF792B85540FC2F5AA994033A`
  (still in the personal keyring; ask the user before revoking or deleting it).

## Releases

GitHub Releases carry the compiled application archive and its checksum only: the packages are published only
through the PPA and COPR.
