# podman-desktop-packaging

RPM (EL8, EL10) and deb (Ubuntu 24.04) packages of the wrouesnel/podman-desktop fork, published as signed dnf and
apt repositories on GitHub Pages (<https://blog.wrouesnel.com/podman-desktop-packaging/>). See README.md.

## Remotes

`origin` is the local backup `~/git/podman-desktop-packaging.git` (push after every commit), `github` is
github.com/wrouesnel/podman-desktop-packaging (push when releasing or asked).

## Signing key

- The repositories are signed with this project's own key, `058AF445927A0D7FF792B85540FC2F5AA994033A`
  (RSA 4096, expires 2029-09-30), kept in the personal keyring `~/.gnupg`, certified by the user's default key and
  published on keyserver.ubuntu.com. Its passphrase: `secret-tool lookup service gpg-passphrase fingerprint
  058AF445927A0D7FF792B85540FC2F5AA994033A`. Never print it.
- CI uses the standard names of the global key rules: the secrets `PACKAGE_SIGNING_KEY` (passphrase protected) and
  `PACKAGE_SIGNING_KEY_PASSPHRASE`, and the variable `PACKAGE_SIGNING_KEY_FINGERPRINT`.
- Local signing: `make repos PACKAGE_SIGNING_KEY_FINGERPRINT=<fpr>`; `repo/gpg-sign` passes the passphrase to gpg
  through a pipe (loopback pinentry), never through a file.

## Releases

GitHub Releases carry notes only: the packages are published only through the dnf / apt repositories.
