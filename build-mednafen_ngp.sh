#!/usr/bin/env bash
#
# Neo Geo Pocket and Neo Geo Pocket Color (Beetle NeoPop).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=mednafen_ngp
REPO=libretro/beetle-ngp-libretro

build_libretro_core || exit 1
