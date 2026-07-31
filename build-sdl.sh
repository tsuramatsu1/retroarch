#!/usr/bin/env bash
#
# Build SDL2 for Prospero with the DualSense touchpad patch, and install it into
# the SDK sysroot so retroarch.elf links against it.
#
# Run this BEFORE build.sh. The prebuilt SDL2 in the pacbrew sysroot is stock, and
# a frontend linked against it has no touchpad pointer - RetroArch derives
# RETRO_DEVICE_POINTER from SDL_GetMouseState(), and stock SDL never feeds
# touchpad contact into the mouse state. See patches/sdl-ps5-touchpad.py.

URL="https://github.com/ps5-payload-dev/SDL/archive/refs/heads/master.tar.gz"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"

if [[ -z "$PS5_PAYLOAD_SDK" ]]; then
    echo "error: PS5_PAYLOAD_SDK is not set"
    exit 1
fi

source "${PS5_PAYLOAD_SDK}/toolchain/prospero.sh" || exit 1
export MAKEFLAGS="-j$(nproc)"

TEMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TEMPDIR"' EXIT

wget -O "$TEMPDIR/sdl.tar.gz" "${URL}" || exit 1
tar xf "$TEMPDIR/sdl.tar.gz" -C "$TEMPDIR" || exit 1

SRC=$(find "$TEMPDIR" -maxdepth 1 -type d -name 'SDL-*' | head -n1)
if [[ -z "$SRC" ]]; then
    echo "error: could not find the extracted SDL source"
    exit 1
fi
cd "$SRC" || exit 1

echo "=== applying the touchpad patch ==="
python3 "${SCRIPT_DIR}/patches/sdl-ps5-touchpad.py" src/joystick/ps5/SDL_ps5joystick.c || exit 1

# Assert the patch actually landed. It is applied by a script rather than `patch`,
# so a silent no-op would otherwise produce a stock SDL that looks fine.
grep -q 'PS5_TouchpadToMouse' src/joystick/ps5/SDL_ps5joystick.c || {
    echo "error: patch did not apply"
    exit 1
}

echo "=== configuring ==="
rm -rf build
"${CMAKE}" -DCMAKE_BUILD_TYPE=Release -DSDL_OPENGL=YES -DSDL_LOADSO=YES \
    -B build -S . || exit 1

echo "=== building ==="
"${MAKE}" -C build || exit 1

echo "=== installing into the sysroot ==="
"${MAKE}" -C build install || exit 1

# The frontend links libSDL2.a, so the symbol must be in the installed archive,
# not merely in a build-tree object.
if "${PS5_PAYLOAD_SDK}/bin/prospero-nm" \
      "${PS5_SYSROOT}/user/homebrew/lib/libSDL2.a" 2>/dev/null \
      | grep -q 'PS5_TouchpadToMouse'; then
    echo "ok: patched libSDL2.a installed"
else
    echo "error: installed libSDL2.a does not contain the patch"
    exit 1
fi
