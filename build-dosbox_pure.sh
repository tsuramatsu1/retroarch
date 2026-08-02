#!/usr/bin/env bash
#
# DOSBox Pure - MS-DOS / PC games.
#
# A good fit for this target: it renders entirely on the CPU (hw_render = false),
# has no external dependencies beyond pthread, and upstream already supports an
# interpreter-only build for platforms that forbid executable memory.

VER="master"
URL="https://github.com/schellingb/dosbox-pure/archive/refs/heads/master.tar.gz"
INFO="https://raw.githubusercontent.com/libretro/libretro-core-info/refs/heads/master/dosbox_pure_libretro.info"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"

if [[ -z "$PS5_PAYLOAD_SDK" ]]; then
    echo "error: PS5_PAYLOAD_SDK is not set"
    exit 1
fi

source "${PS5_PAYLOAD_SDK}/toolchain/prospero.sh" || exit 1

TEMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TEMPDIR"' EXIT

wget -O $TEMPDIR/dosbox-pure.tar.gz "${URL}" || exit 1
tar xf  $TEMPDIR/dosbox-pure.tar.gz -C $TEMPDIR || exit 1

# Detect the extracted directory rather than assuming it matches $VER: GitHub
# names it after the default branch, which here is "main", not "master".
SRC=$(find "$TEMPDIR" -maxdepth 1 -type d -name 'dosbox-pure-*' | head -n1)
[ -n "$SRC" ] || { echo "error: could not find the extracted source"; exit 1; }
cd "$SRC" || exit 1

# DOSBox emulates x86 and would normally recompile guest code at runtime. The
# payload sandbox refuses PROT_EXEC pages, so that cannot work - dyn_cache.h calls
# mprotect(..., PROT_WRITE|PROT_READ|PROT_EXEC) directly.
#
# DISABLE_DYNAREC is upstream's own switch for exactly this situation (iOS and
# tvOS use it). In include/config.h it makes the dynarec block take an empty
# branch, so neither C_DYNAMIC_X86 nor C_DYNREC is defined and the interpreter is
# the only CPU core compiled in.
#
# It goes through MAKE_CPUFLAGS rather than COMMONFLAGS: the Makefile builds
# COMMONFLAGS up with +=, and a command-line override would discard those; but
# CPUFLAGS := $(MAKE_CPUFLAGS) is assigned once and then appended to both CFLAGS
# and LDFLAGS.
export MAKE_CPUFLAGS="-DDISABLE_DYNAREC=1"

# STRIPCMD defaults to the host `strip`. Use the SDK's when it exists, and a no-op
# otherwise, so the recipe does not depend on a host tool touching a Prospero ELF.
if [ -x "${PS5_PAYLOAD_SDK}/bin/prospero-strip" ]; then
    export STRIP="${PS5_PAYLOAD_SDK}/bin/prospero-strip"
else
    export STRIP=/bin/true
fi

${MAKE} CXX="${CXX}" CC="${CC}" -j"$(nproc)" || exit 1

SO=dosbox_pure_libretro.so
[ -f "$SO" ] || { echo "error: $SO was not produced"; exit 1; }

# Assert the recompiler really is out. If DISABLE_DYNAREC ever stops reaching the
# compiler the core would still build, then fail on-console the moment a game
# started - the sandbox denies the mprotect and DOSBox aborts.
if "${PS5_PAYLOAD_SDK}/bin/prospero-nm" -C "$SO" 2>/dev/null | grep -qE 'CacheBlock|dyn_return|gen_run_code'; then
    echo "error: dynarec symbols present; DISABLE_DYNAREC did not take effect"
    exit 1
fi
echo "ok: interpreter-only build, no dynarec symbols"

mkdir -p "${SCRIPT_DIR}/.config/retroarch/cores" || exit 1
mv "$SO" "${SCRIPT_DIR}/.config/retroarch/cores/" || exit 1
wget $INFO -O "${SCRIPT_DIR}/.config/retroarch/cores/dosbox_pure_libretro.info"
