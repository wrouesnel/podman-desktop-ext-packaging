#!/usr/bin/env bash
# Builds Podman Desktop from sources, and assembles the application artifact used by the packages:
#   out/podman-desktop-app-<version>-x86_64.tar.gz containing
#     podman-desktop/   the application (electron-builder "dir" output)
#     share/            desktop entry, AppStream metadata, icons
#     BUILD_INFO        repository, ref, commit, versions
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
STAGE=$WORK/stage
rm -rf "$STAGE"
mkdir -p "$STAGE/share/applications" "$STAGE/share/metainfo" \
  "$STAGE/share/icons/hicolor/scalable/apps" "$STAGE/share/icons/hicolor/512x512/apps"
cp -a dist/linux-unpacked "$STAGE/podman-desktop"
cp "$ROOT/common/io.podman_desktop.PodmanDesktop.desktop" "$STAGE/share/applications/"
cp .flatpak-appdata.xml "$STAGE/share/metainfo/io.podman_desktop.PodmanDesktop.metainfo.xml"
cp buildResources/icon.svg "$STAGE/share/icons/hicolor/scalable/apps/io.podman_desktop.PodmanDesktop.svg"
cp buildResources/icon-512x512.png "$STAGE/share/icons/hicolor/512x512/apps/io.podman_desktop.PodmanDesktop.png"
cat > "$STAGE/BUILD_INFO" <<INFO
PD_REPO=$PD_REPO
PD_REF=$PD_REF
PD_COMMIT=$COMMIT
APP_VERSION=$APP_VERSION
NODE_VERSION=$node_version
BUILD_DATE=$(date -u +%Y%m%d)
INFO

ARTIFACT=$OUT/podman-desktop-app-$APP_VERSION-x86_64.tar.gz
tar -C "$STAGE" -czf "$ARTIFACT" .
echo "Built $ARTIFACT ($COMMIT)"
