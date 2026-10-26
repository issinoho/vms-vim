#!/usr/bin/env bash
# prepare.sh - build a VMS-ready source tree in staging/vim-<version>/
#
#   1. fetch + verify the upstream tag (fetch.sh)
#   2. extract it, apply patches/series, lay overlay/ over the top
#
# Vim needs no configure step on VMS: src/Make_vms.mms and src/os_vms_conf.h are
# upstream's. Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
stage=$top/staging/$name

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"
mkdir -p "$top/staging"
tar -xzf "$top/cache/$name.tar.gz" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

# overlay/ may only add files; changes to upstream files belong in patches/.
(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

# --- PCSI kit inputs (vms/kit/MAKE_KIT.COM builds the kit on each node) ------
if [ -d "$stage/vms/kit" ]; then
    step "PCSI kit inputs"
    : "${KIT_PRODUCER:=ISSINOHO}"
    # Vim's versions have three parts (9.2.1240): the patch number is the PCSI
    # update and our VMS patch level the ECO, as in the sibling ports:
    # 9.2.1240-vms1 is V9.2-1240E1 (PCSI takes a four-digit update, NOTES N1).
    IFS=. read -r major minor update _ <<< "$UPSTREAM_VERSION"
    pcsiversion="V$major.$minor-${update:-0}E$VMS_PATCH_LEVEL"
    kitversion="$UPSTREAM_VERSION-vms$VMS_PATCH_LEVEL"
    kit=$stage/vms/kit
    python3 -I "$top/tools/gen_kit.py" "$stage/runtime" "$kit" | sed 's/^/prepare: /'
    subst() {
        sed -e "s/@PRODUCER@/$KIT_PRODUCER/g" -e "s/@BASE@/$1/g" \
            -e "s/@PCSIVERSION@/$pcsiversion/g" -e "s/@VERSION@/$UPSTREAM_VERSION/g" \
            -e "s/@KITVERSION@/$kitversion/g" -e "s/@ARCH@/$2/g"
    }
    for base in I64VMS X86VMS; do
        # awk, not sed's "r file": BSD sed (macOS) differs.
        subst $base "" < "$kit/vim.pcsi\$desc_template" |
            awk -v files="$kit/runtime.pdf" '/^@RUNTIME@$/ { while ((getline l < files) > 0) print l; next } { print }' \
            > "$kit/VIM-$base.PCSI\$DESC"
        subst $base "" < "$kit/vim.pcsi\$text_template" > "$kit/VIM-$base.PCSI\$TEXT"
    done
    rm -f "$kit/vim.pcsi\$desc_template" "$kit/vim.pcsi\$text_template" "$kit/runtime.pdf"
    mv "$kit/vim\$startup.com" "$kit/VIM\$STARTUP.COM"
    mv "$kit/vim\$setup.com" "$kit/VIM\$SETUP.COM"
    mv "$kit/vimtutor.com" "$kit/VIMTUTOR.COM"
    mv "$kit/make_kit.com" "$kit/MAKE_KIT.COM"
    subst "" "IA64 and x86-64" < "$kit/readme.vms" > "$kit/README.VMS"; rm -f "$kit/readme.vms"
    mkdir -p "$kit/doc"
    cp "$stage/LICENSE" "$kit/doc/LICENSE."
    printf 'KIT_PRODUCER=%s\nPCSI_VERSION=%s\nKIT_VERSION=%s\n' "$KIT_PRODUCER" "$pcsiversion" \
        "$kitversion" > "$kit/KIT.ENV"
fi

step "staged $stage"
