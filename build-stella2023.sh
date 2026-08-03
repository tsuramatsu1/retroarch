#!/usr/bin/env bash
#
# Atari 2600 (Stella, 2023 fork).

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=stella2023
REPO=libretro/stella2023

# The libretro port lives under the emulator tree, not at the repository root.
MAKE_DIR=src/os/libretro

build_libretro_core || exit 1
