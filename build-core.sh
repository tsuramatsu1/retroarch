#!/usr/bin/env bash
#
# Build one libretro core, or all of them, and stage it in
# .config/retroarch/cores next to its .info file.
#
#   ./build-core.sh mgba          one core
#   ./build-core.sh --all         every core, with a summary
#   ./build-core.sh --list        what is available, and how each is defined
#
# A core is defined either by a row in cores/_table.txt (the common case: just a
# repository and a makefile path) or by its own cores/<name>.sh, for the ones
# that need a source patch, a build assertion or an .info fixup. A dedicated
# script wins over a table row of the same name.

ROOT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
CORES_DIR="$ROOT_DIR/cores"
TABLE="$CORES_DIR/_table.txt"

rows() { grep -vE '^[[:space:]]*(#|$)' "$TABLE"; }

table_names() { rows | cut -d'|' -f1; }

script_names() {
    # _common.sh and _table.txt are plumbing, not cores.
    find "$CORES_DIR" -maxdepth 1 -type f -name '*.sh' ! -name '_*' \
        -exec basename {} .sh \; | sort
}

all_names() { { script_names; table_names; } | sort -u; }

usage() {
    echo "usage: $(basename "$0") <core> | --all | --list"
    echo "       $(basename "$0") --list   # $(all_names | wc -l) cores available"
}

build_one() {
    local name="$1"

    if [[ -f "$CORES_DIR/$name.sh" ]]; then
        # Its own script: run it as a child so nothing it defines leaks into a
        # subsequent core in the same --all run.
        bash "$CORES_DIR/$name.sh"
        return $?
    fi

    local row
    row=$(rows | awk -F'|' -v n="$name" '$1 == n { print; exit }')
    if [[ -z "$row" ]]; then
        echo "error: unknown core '$name'"
        echo "available: $(all_names | tr '\n' ' ')"
        return 1
    fi

    (
        local _name repo make_dir makefile args defines
        IFS='|' read -r _name repo make_dir makefile args defines <<<"$row"

        source "$CORES_DIR/_common.sh" || exit 1

        CORE="$name"
        REPO="$repo"
        MAKE_DIR="${make_dir:-.}"
        MAKEFILE="${makefile:-Makefile}"
        # The table may reference ${ROOT_DIR} in a define (mgba's shim path).
        # Substituted rather than eval'd, so a row cannot run commands.
        EXTRA_DEFINES="${defines//\$\{ROOT_DIR\}/$ROOT_DIR}"
        read -r -a MAKE_ARGS <<<"$args"

        build_libretro_core
    )
}

case "${1:-}" in
    "")
        usage
        exit 1
        ;;
    --list)
        printf '%-22s %s\n' CORE DEFINED_BY
        while read -r n; do
            if [[ -f "$CORES_DIR/$n.sh" ]]; then
                printf '%-22s cores/%s.sh\n' "$n" "$n"
            else
                printf '%-22s cores/_table.txt\n' "$n"
            fi
        done < <(all_names)
        echo
        echo "$(all_names | wc -l) cores"
        ;;
    --all)
        failed=0
        summary=""
        while read -r n; do
            echo "== $n"
            start=$SECONDS
            if build_one "$n"; then
                summary+=$(printf '%-22s ok   %4ds\n' "$n" "$((SECONDS - start))")$'\n'
            else
                summary+=$(printf '%-22s FAIL %4ds\n' "$n" "$((SECONDS - start))")$'\n'
                failed=$((failed + 1))
            fi
        done < <(all_names)
        echo
        echo "================ summary ================"
        printf '%s' "$summary"
        echo "$failed failed"
        exit $(( failed > 0 ))
        ;;
    -*)
        usage
        exit 1
        ;;
    *)
        build_one "$1"
        exit $?
        ;;
esac
