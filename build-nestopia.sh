#!/usr/bin/env bash
#
# NES/Famicom (Nestopia UE). More accurate than fceumm and heavier; both are
# kept so a game that misbehaves in one can be run in the other.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=nestopia
REPO=libretro/nestopia
MAKE_DIR=libretro

build_libretro_core || exit 1
