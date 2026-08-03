#!/usr/bin/env bash
#
# Shared plumbing for the build-<core>.sh recipes: fetch, cross-compile with the
# Prospero toolchain, prove the result can actually load on the console, then
# stage it next to its .info file.
#
# A recipe sources this file, sets the variables its core needs, and calls
# build_libretro_core:
#
#     SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
#     source "${SCRIPT_DIR}/build-core-common.sh" || exit 1
#
#     CORE=stella2023
#     REPO=libretro/stella2023
#     MAKE_DIR=src/os/libretro
#     build_libretro_core || exit 1
#
# Variables:
#   CORE           core name; also names the .so and the .info     (required)
#   REPO           GitHub owner/repo to build from                 (required)
#   BRANCH         branch to fetch                                (default master)
#   FETCH          "tarball", or "git" for a core with submodules  (default tarball)
#   MAKE_DIR       directory holding the libretro makefile         (default .)
#   MAKEFILE       makefile name                                   (default Makefile)
#   SO             expected output                       (default ${CORE}_libretro.so)
#   EXTRA_DEFINES  appended to CC and CXX
#   MAKE_ARGS      array of extra make arguments
#
# Optional hooks a recipe may define:
#   core_post_build <so>    called in the build directory, before staging
#   core_post_info  <info>  called on the downloaded .info, before it is checked

if [[ -z "$PS5_PAYLOAD_SDK" ]]; then
    echo "error: PS5_PAYLOAD_SDK is not set"
    return 1 2>/dev/null || exit 1
fi

source "${PS5_PAYLOAD_SDK}/toolchain/prospero.sh" || {
    return 1 2>/dev/null || exit 1
}

RECIPE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Linking is not loading. These three checks are what separates "the makefile
# produced a file" from "RetroArch on the console can dlopen it".
verify_libretro_so() {
    local so="$1"
    local nm="${PS5_PAYLOAD_SDK}/bin/prospero-nm"
    local syms sym

    # Cores link stripped of the static symbol table, so read the dynamic one.
    # That is also the table RetroArch's dlsym resolves against on-console;
    # `nm --defined-only` reports "no symbols" on a perfectly good core.
    syms=$("$nm" -D --defined-only "$so" 2>/dev/null)
    for sym in retro_api_version retro_init retro_run retro_load_game \
               retro_get_system_info; do
        if ! grep -qw "$sym" <<<"$syms"; then
            echo "error: $(basename "$so") does not export $sym"
            return 1
        fi
    done

    # A makefile that ignored CC/CXX builds a host Linux object that stages
    # cleanly and loads nowhere. Prospero output imports the sprx stubs, and
    # OSABI cannot tell the two apart - both are SYSV/x86-64.
    if ! readelf -dW "$so" | grep -q 'libkernel_web.sprx'; then
        echo "error: $(basename "$so") is not a PS5 object; the toolchain was bypassed"
        return 1
    fi

    # libkernel_sys is absent from websrv's process. A module importing it fails
    # to load with nothing shown on screen.
    if readelf -dW "$so" | grep -q 'libkernel_sys.sprx'; then
        echo "error: $(basename "$so") imports libkernel_sys.sprx"
        return 1
    fi
}

build_libretro_core() {
    local core="${CORE:?CORE is not set}"
    local repo="${REPO:?REPO is not set}"
    local branch="${BRANCH:-master}"
    local fetch="${FETCH:-tarball}"
    local make_dir="${MAKE_DIR:-.}"
    local makefile="${MAKEFILE:-Makefile}"
    local so="${SO:-${core}_libretro.so}"
    local info="${core}_libretro.info"
    local stage="${RECIPE_DIR}/.config/retroarch/cores"
    local tempdir src out

    tempdir=$(mktemp -d) || return 1
    trap 'rm -rf -- "$tempdir"' EXIT

    if [[ "$fetch" == "git" ]]; then
        # GitHub's archives omit submodules, so a core that has them has to be
        # cloned.
        git clone --depth 1 --recursive --branch "$branch" \
            "https://github.com/${repo}" "$tempdir/$core" || return 1
        src="$tempdir/$core"
    else
        wget -O "$tempdir/$core.tar.gz" \
            "https://github.com/${repo}/archive/refs/heads/${branch}.tar.gz" || return 1
        tar xf "$tempdir/$core.tar.gz" -C "$tempdir" || return 1
        # The extracted directory is named after the repo and branch, neither of
        # which need match the core name, so find it instead of assuming.
        src=$(find "$tempdir" -mindepth 1 -maxdepth 1 -type d | head -n1)
        if [[ -z "$src" ]]; then
            echo "error: $core: the archive extracted no source directory"
            return 1
        fi
    fi

    # platform=unix keeps the libretro makefiles on their .so/-fPIC path.
    #
    # The toolchain goes on the command line as make *variables*, not just in
    # the environment, so it also overrides makefiles that hardcode `CC = gcc`
    # in their unix branch - those otherwise build a host Linux object.
    #
    # -DCLOCK_REALTIME=0 -DCLOCK_MONOTONIC=4: the SDK's time.h only defines the
    # clock ids when __POSIX_VISIBLE >= 200112, which -std=c99 (__STRICT_ANSI__)
    # suppresses, so anything using libretro-common/rthreads fails to compile.
    # The values are the header's own, so predefining them is equivalent, not a
    # workaround. (-D_POSIX_C_SOURCE=200809L does not work here.)
    #
    # Both are needed together: time.h wraps the whole block in
    # `#if !defined(CLOCK_REALTIME) && __POSIX_VISIBLE >= 200112`, so defining
    # CLOCK_REALTIME alone also hides CLOCK_MONOTONIC - which is how
    # libretro-common/features/features_cpu.c breaks with only the first.
    #
    # HAVE_CDROM=0: libretro-common/cdrom has no PS5 ioctl path.
    #
    # -Wno-unused-command-line-argument keeps the define from breaking compiler
    # detection. Some makefiles sniff with `$(CC) -v 2>&1 | grep -c clang` and
    # expect exactly one line: clang reports the unused define on the flags-only
    # invocation, that second line makes the test conclude "not clang", and the
    # GCC branch then adds flags clang rejects (parallel_n64 picks up -fipa-pta
    # and every compile fails).
    local defines="-DCLOCK_REALTIME=0 -DCLOCK_MONOTONIC=4"
    defines+=" -Wno-unused-command-line-argument ${EXTRA_DEFINES:-}"
    (
        cd "$src/$make_dir" || exit 1
        "$MAKE" -f "$makefile" \
                platform=unix \
                DEBUG=0 \
                fpic="-fPIC" \
                HAVE_CDROM=0 \
                CC="$CC $defines" \
                CXX="$CXX $defines" \
                AR="$AR" \
                RANLIB="$RANLIB" \
                -j"$(nproc)" \
                "${MAKE_ARGS[@]}"
    ) || return 1

    out="$src/$make_dir/$so"
    if [[ ! -f "$out" ]]; then
        echo "error: $core: $so was not produced"
        return 1
    fi

    verify_libretro_so "$out" || return 1

    if declare -F core_post_build >/dev/null; then
        ( cd "$src/$make_dir" && core_post_build "$out" ) || return 1
    fi

    wget -O "$tempdir/$info" \
        "https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/${info}" \
        || return 1

    if declare -F core_post_info >/dev/null; then
        core_post_info "$tempdir/$info" || return 1
    fi

    # A core that wants a hardware GL context cannot run on this build at all -
    # the frontend renders through SDL2's software framebuffer.
    if grep -q 'hw_render[[:space:]]*=[[:space:]]*"true"' "$tempdir/$info"; then
        echo "error: $core declares hw_render = true; this build has no GL context"
        return 1
    fi

    mkdir -p "$stage" || return 1
    mv "$out" "$stage/$so" || return 1
    mv "$tempdir/$info" "$stage/$info" || return 1

    echo "staged $so ($(stat -c%s "$stage/$so") bytes)"
}
