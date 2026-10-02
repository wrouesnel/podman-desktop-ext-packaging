# podman-desktop-packaging

RPM (EL8, EL10) and deb (Ubuntu 24.04) packages of the wrouesnel/podman-desktop fork, published as signed dnf and
apt repositories on GitHub Pages (<https://blog.wrouesnel.com/podman-desktop-packaging/>). See README.md.

## Remotes

`origin` is the local backup `~/git/podman-desktop-packaging.git` (push after every commit), `github` is
github.com/wrouesnel/podman-desktop-packaging (push when releasing or asked).

## Signing key (exception to the global key rule)

- The repositories are signed with this project's own key, `058AF445927A0D7FF792B85540FC2F5AA994033A`
  (RSA 4096, expires 2029-09-30), kept in the personal keyring `~/.gnupg`. Its passphrase is in the login keyring:
  `secret-tool lookup service gpg-passphrase fingerprint 058AF445927A0D7FF792B85540FC2F5AA994033A`. Never print it.
- Exception: the private key leaves the keyring as the GitHub secret `PACKAGE_SIGNING_KEY` (passphrase protected),
  with `PACKAGE_SIGNING_KEY_PASSPHRASE` and the variable `PACKAGE_SIGNING_KEY_FINGERPRINT`, so that the tag
  workflow signs and publishes the repositories. The user approved it (2026-10-01, and the standard secret names
  on 2026-10-03, see ~/claude/AGENTS.md "Packaging keys").
- Local signing: `make repos PACKAGE_SIGNING_KEY_FINGERPRINT=<fpr>`; `repo/gpg-sign` passes the passphrase to gpg
  through a pipe (loopback pinentry), never through a file.

## Releases

GitHub Releases carry notes only: the packages are published only through the dnf / apt repositories.
