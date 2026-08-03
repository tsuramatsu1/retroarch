#!/usr/bin/env bash
#
# Game Boy, Game Boy Color and Game Boy Advance (mGBA).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=mgba
REPO=libretro/mgba
MAKEFILE=Makefile.libretro

# Without HAVE_STRTOF_L, mgba defines its own strtof_l and collides with the
# one libc.a already has in no-locale.o. With it, mgba calls a function the C
# headers never declare - hence the shim, which supplies the real prototype.
EXTRA_DEFINES="-DHAVE_STRTOF_L -include ${SCRIPT_DIR}/shims/ps5-locale.h"

build_libretro_core || exit 1
