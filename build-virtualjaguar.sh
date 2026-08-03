#!/usr/bin/env bash
#
# Atari Jaguar (Virtual Jaguar).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=virtualjaguar
REPO=libretro/virtualjaguar-libretro

build_libretro_core || exit 1
