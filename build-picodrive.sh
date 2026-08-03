#!/usr/bin/env bash
#
# Mega Drive, Sega CD, 32X, Master System and Game Gear (PicoDrive). Covers the
# 32X, which genesis_plus_gx does not.

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/build-core-common.sh" || exit 1

CORE=picodrive
REPO=libretro/picodrive

# PicoDrive keeps libpicofe, cyclone68000, libchdr, emu2413 and dr_libs as
# submodules, and GitHub's archives omit those, so this one has to be cloned.
FETCH=git

# The root Makefile insists on ./configure having been run; the libretro
# target is a separate makefile.
MAKEFILE=Makefile.libretro

# The SH2 recompiler is on by default on x86-64. It maps its translation cache
# executable (plat_mem_set_exec -> mprotect PROT_EXEC in platform/libretro),
# which the payload sandbox refuses, so a 32X game would recompile into a
# non-executable page and die - and the 32X is the reason this core is here.
# use_sh2drc=0 is upstream's own switch for that case (Apple builds use it, for
# code signing reasons); the MAME SH2 interpreter is compiled in either way.
MAKE_ARGS=(use_sh2drc=0)

core_post_build() {
    # If the recompiler ever creeps back in the core still builds, then dies the
    # moment a 32X game starts, so assert its objects really are absent. Only the
    # sh2_drc_* symbols prove that: cpu/drc/cmn.o, which owns the translation
    # cache and drc_cmn_init, is linked either way and simply goes uncalled here.
    # They are internal symbols, so read the static table - the version script
    # only exports retro_*.
    if "${PS5_PAYLOAD_SDK}/bin/prospero-nm" --defined-only "$1" 2>/dev/null \
        | grep -qE 'sh2_drc_dispatcher|sh2_drc_init|sh2_execute_drc'; then
        echo "error: SH2 recompiler symbols present; use_sh2drc=0 did not take effect"
        return 1
    fi
    echo "ok: SH2 interpreter only, no recompiler"
}

build_libretro_core || exit 1
