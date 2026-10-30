#!/usr/bin/env bash
# Regenerate the marketplace preview images from live Omarchy captures.
#
# Usage: preview/build.sh <drawer.png> <add-tiles.png> <new-command.png>
#
# Each argument is a full-screen 1920x1080 capture with the drawer open in the
# matching view, taken on the Ethereal theme with the Quick Drawer mark in the
# bar's centre section. The drawer card is expected at x=827 y=32.
#
# Needs: chromium, ImageMagick.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
work="$here/.work"

drawer=${1:?full-screen capture with the tile grid open}
tiles=${2:?full-screen capture with Add tiles open}
command=${3:?full-screen capture with New command open}

command -v chromium >/dev/null || { echo "chromium is required" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) is required" >&2; exit 1; }

mkdir -p "$work"
trap '[[ -f $work/server.pid ]] && kill "$(cat "$work/server.pid")" 2>/dev/null || true' EXIT

# The theme wallpaper is the backdrop of the poster; keep a copy beside the
# captures so the HTML can load everything from one directory.
if [[ ! -f $work/wallpaper.jpg ]]; then
  cp "$HOME/.local/state/omarchy/current/theme/backgrounds/1-cosmic.jpg" "$work/wallpaper.jpg"
fi

# 460x460 around the card: bar on top, the drawer card, and the wallpaper that
# gives the shot context.
magick "$drawer" -crop 460x460+767+0 +repage "$work/drawer.png"

cp "$here/poster.html" "$work/poster.html"

port=${PREVIEW_PORT:-8791}
pushd "$work" >/dev/null
python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
echo $! > server.pid
popd >/dev/null
sleep 0.5

cd "$work"
chromium --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1600,1000 \
  --virtual-time-budget=4000 --screenshot=poster2x.png \
  http://127.0.0.1:"$port"/poster.html >/dev/null 2>&1

magick poster2x.png -resize 1600x1000 -strip -define png:compression-level=9 "$repo/preview.png"

# Supporting shots for the README, cropped to the card plus a little wallpaper.
magick "$tiles" -crop 560x900+717+0 +repage -strip -define png:compression-level=9 "$repo/preview-settings.png"
magick "$command" -crop 560x420+717+0 +repage -strip -define png:compression-level=9 "$repo/preview-custom.png"

echo "wrote preview.png, preview-settings.png, preview-custom.png"
