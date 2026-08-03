#!/usr/bin/env bash
#
# Nintendo 64 (ParaLLEl N64), built as a pure software core.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/_common.sh" || exit 1

CORE=parallel_n64
REPO=libretro/parallel-n64

# The bundled zlib copy calls read/write/close from gzread.c and gzwrite.c, and
# only reaches <unistd.h> when HAVE_UNISTD_H is defined - zconf.h turns it into
# Z_HAVE_UNISTD_H, which gates the include. zlib's own ./configure sets it; there
# is no configure step here, and clang 18 rejects the implicit declarations.
EXTRA_DEFINES="-DHAVE_UNISTD_H"

# Every video plugin this core ships except angrylion draws through OpenGL or
# Vulkan, and the frontend here renders into SDL2's software framebuffer - there
# is no context for them to use. angrylion is the software rasteriser, so it is
# the only plugin built in; leaving the others enabled would also pull in the GL
# libraries at link time.
#
# WITH_DYNAREC is emptied for the same reason desmume2015.sh disables its JIT:
# the recompiler maps executable pages, and the payload sandbox refuses
# PROT_EXEC. The r4300 interpreter is then the only CPU core compiled in.
MAKE_ARGS=(
    HAVE_OPENGL=0
    HAVE_GLIDEN64=0
    HAVE_GLIDE64=0
    HAVE_GLN64=0
    HAVE_RICE=0
    HAVE_PARALLEL=0
    HAVE_PARALLEL_RSP=0
    HAVE_THR_AL=1
    WITH_DYNAREC=
)

core_post_build() {
    # If the dynarec ever creeps back in the core still builds, then dies the
    # moment a game starts, so assert its objects really are absent. These are
    # internal symbols, so read the static table, not the dynamic one - the
    # version script only exports retro_*.
    if "${PS5_PAYLOAD_SDK}/bin/prospero-nm" --defined-only "$1" 2>/dev/null \
        | grep -qE 'new_dynarec|new_recompile_block'; then
        echo "error: dynarec symbols present; WITH_DYNAREC did not take effect"
        return 1
    fi
    # ...and that the software rasteriser is in, or the core would load with no
    # renderer at all.
    if ! "${PS5_PAYLOAD_SDK}/bin/prospero-nm" --defined-only "$1" 2>/dev/null \
        | grep -q 'n64video'; then
        echo "error: angrylion symbols missing; the core has no software renderer"
        return 1
    fi
    echo "ok: interpreter-only, software rasteriser"
}

core_post_info() {
    # Upstream's .info describes the GL build. Left alone it would claim a
    # hardware context this core was not built to use, and the hw_render gate in
    # _common.sh would reject it.
    sed -i 's/^hw_render = "true"/hw_render = "false"/' "$1" || return 1
    sed -i '/^required_hw_api = /d' "$1" || return 1
}

build_libretro_core || exit 1
