#!/usr/bin/env bash
# Builds a release of Pelota for Linux and Windows: exports both with Godot (the "Linux" and
# "Windows Desktop" presets of export_presets.cfg), packs each with the README and the license
# into an archive (Pelota-<version>-linux-x86_64.tar.gz, Pelota-<version>-windows-x86_64.zip)
# and writes their checksums (SHA256SUMS.txt), all into build/<version>/.
#
# Usage:
#   tools/release.sh [version] [--publish]
#
#   version    defaults to config/version of project.godot
#   --publish  also tags the current commit v<version>, pushes the tag and creates a draft
#              GitHub release with the archives (needs the gh CLI, logged in); review and
#              publish the draft on GitHub
#
# The Godot binary is taken from $GODOT, or `godot` on the PATH; its export templates must be
# installed (Editor > Manage Export Templates).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

VERSION=""
PUBLISH=false
for arg in "$@"; do
	case "$arg" in
		--publish) PUBLISH=true ;;
		-h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) VERSION="$arg" ;;
	esac
done
if [[ -z "$VERSION" ]]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")"
fi
NAME="Pelota-$VERSION"
OUT="$ROOT/build/$VERSION"

if ! command -v "$GODOT" >/dev/null; then
	echo "Godot not found: set GODOT to the Godot binary." >&2
	exit 1
fi
# Templates live in a folder named after the version, e.g. 4.8.dev7 for 4.8.dev7.official.xyz
GODOT_VERSION="$("$GODOT" --version | cut -d. -f1-3)"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION"
if [[ ! -d "$TEMPLATES" ]]; then
	echo "No export templates for Godot $GODOT_VERSION in $TEMPLATES." >&2
	echo "Install them in the editor: Editor > Manage Export Templates." >&2
	exit 1
fi

echo "Building $NAME with Godot $GODOT_VERSION into $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/linux/$NAME" "$OUT/windows/$NAME"

"$GODOT" --headless --path "$ROOT" --import
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "$OUT/linux/$NAME/Pelota.x86_64"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" \
	"$OUT/windows/$NAME/Pelota.exe"

for platform in linux windows; do
	cp "$ROOT/tools/release_readme.txt" "$OUT/$platform/$NAME/README.txt"
	cp "$ROOT/LICENSE" "$OUT/$platform/$NAME/LICENSE"
done
chmod +x "$OUT/linux/$NAME/Pelota.x86_64"

tar -czf "$OUT/$NAME-linux-x86_64.tar.gz" -C "$OUT/linux" "$NAME"
(cd "$OUT/windows" && zip -qr "../$NAME-windows-x86_64.zip" "$NAME")
(cd "$OUT" && sha256sum "$NAME-linux-x86_64.tar.gz" "$NAME-windows-x86_64.zip" > SHA256SUMS.txt)

echo "Done:"
ls -lh "$OUT"/*.tar.gz "$OUT"/*.zip "$OUT"/SHA256SUMS.txt

if $PUBLISH; then
	TAG="v$VERSION"
	echo "Tagging $TAG and creating a draft GitHub release"
	git -C "$ROOT" tag -a "$TAG" -m "Pelota $VERSION"
	git -C "$ROOT" push origin "$TAG"
	(cd "$ROOT" && gh release create "$TAG" --draft --title "Pelota $VERSION" \
		--notes "Pelota $VERSION for Linux and Windows. See README.txt in the archive." \
		"$OUT/$NAME-linux-x86_64.tar.gz" "$OUT/$NAME-windows-x86_64.zip" \
		"$OUT/SHA256SUMS.txt")
fi
