#!/usr/bin/env bash
#
# Capcom CP System II arcade (FB Alpha 2012).
# A focused split of FB Alpha: far smaller than fbneo and enough for these
# romsets on their own.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=fbalpha2012_cps2
REPO=libretro/fbalpha2012_cps2

# The libretro makefile is lowercase here; the root Makefile only includes it.
MAKEFILE=makefile.libretro

build_libretro_core || exit 1
