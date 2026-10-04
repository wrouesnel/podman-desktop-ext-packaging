#!/usr/bin/env bash
# Builds Podman Desktop Ext from sources, and assembles the compiled application archive repackaged by the
# source packages: out/podman-desktop-ext-<version>-linux-x64.tar.gz (and its .sha256), containing
#   podman-desktop-ext-<version>/app/         the application (electron-builder "dir" output)
#   podman-desktop-ext-<version>/share/       desktop entry, AppStream metadata, icons, managed configuration
#   podman-desktop-ext-<version>/BUILD_INFO   repository, ref, commit, versions
# Runs in the EL8 build container (containers/build-el8.Containerfile).
set -euo pipefail

: "${PD_REPO:?}" "${PD_REF:?}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$ROOT/out}
WORK=${WORK:-$ROOT/work}
SRC=$WORK/src

mkdir -p "$OUT" "$WORK"
rm -rf "$SRC"
git clone --quiet --filter=blob:none "$PD_REPO" "$SRC"
git -C "$SRC" checkout --quiet "$PD_REF"
COMMIT=$(git -C "$SRC" rev-parse HEAD)

cd "$SRC"
node_version=$(node --version | sed 's/^v//')
if [[ "$(cat .nvmrc)" != "${node_version%%.*}" ]]; then
  echo "Node.js $node_version does not match .nvmrc ($(cat .nvmrc))" >&2
  exit 1
fi

# explicit store (the pnpm cache volume of the Makefile): by default pnpm creates its store at the root of
# the filesystem of the project, which is the mounted packaging repository
pnpm install --frozen-lockfile --store-dir "${PNPM_STORE_DIR:-$HOME/.local/share/pnpm/store}"
# same build as the upstream CI for Linux, keeping only the unpacked application
pnpm exec cross-env MODE=production pnpm run build
pnpm exec electron-builder build --config .electron-builder.config.cjs --linux dir --x64

APP_VERSION=$(node -p "require('./package.json').version")
NAME=podman-desktop-ext
APP_ID=io.podman_desktop.PodmanDesktopExt
STAGE=$WORK/stage/$NAME-$APP_VERSION
rm -rf "$WORK/stage"
mkdir -p "$STAGE/share/applications" "$STAGE/share/metainfo" \
  "$STAGE/share/icons/hicolor/scalable/apps" "$STAGE/share/icons/hicolor/512x512/apps"
cp -a dist/linux-unpacked "$STAGE/app"
test -x "$STAGE/app/$NAME"
cp "$ROOT/common/$APP_ID.desktop" "$STAGE/share/applications/"
# managed configuration (https://podman-desktop.io/docs/configuration/managed-configuration):
# telemetry disabled and locked
mkdir -p "$STAGE/share/$NAME"
cp "$ROOT/common/managed/default-settings.json" "$ROOT/common/managed/locked.json" "$STAGE/share/$NAME/"
sed -e "s#<id>io.podman_desktop.PodmanDesktop</id>#<id>$APP_ID</id>#" \
  -e "s#<name>Podman Desktop</name>#<name>Podman Desktop Ext</name>#" \
  -e "s#io.podman_desktop.PodmanDesktop.desktop#$APP_ID.desktop#" \
  .flatpak-appdata.xml > "$STAGE/share/metainfo/$APP_ID.metainfo.xml"
cp buildResources/icon.svg "$STAGE/share/icons/hicolor/scalable/apps/$APP_ID.svg"
cp buildResources/icon-512x512.png "$STAGE/share/icons/hicolor/512x512/apps/$APP_ID.png"
cat > "$STAGE/BUILD_INFO" <<INFO
PD_REPO=$PD_REPO
PD_REF=$PD_REF
PD_COMMIT=$COMMIT
APP_VERSION=$APP_VERSION
NODE_VERSION=$node_version
BUILD_DATE=$(date -u +%Y%m%d)
INFO

# the compiled binary archive (attached to the GitHub releases), which the source packages repackage:
# podman-desktop-ext-<version>/{app,share,BUILD_INFO}
ARCHIVE=$OUT/$NAME-$APP_VERSION-linux-x64.tar.gz
tar -C "$WORK/stage" --sort=name --owner=0 --group=0 --numeric-owner -czf "$ARCHIVE" "$NAME-$APP_VERSION"
(cd "$OUT" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
echo "Built $ARCHIVE ($COMMIT)"
