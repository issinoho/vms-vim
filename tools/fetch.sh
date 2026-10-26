#!/usr/bin/env bash
# fetch.sh - make the upstream tarball named in upstream.conf in cache/.
#
# Vim publishes no release tarballs, only signed tags. Fetch the tag (shallow),
# verify its signature against keys/vim-signing-key.asc only (a throwaway keyring),
# check it points at UPSTREAM_COMMIT, and git archive it to cache/vim-<version>.tar.gz.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
cache=$top/cache
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$cache/$name.tar.gz
[ -f "$tarball" ] && { echo "fetch: $tarball"; exit 0; }
mkdir -p "$cache"

git=$cache/upstream.git
[ -d "$git" ] || git init -q --bare "$git"
echo "fetch: $UPSTREAM_REPO tag $UPSTREAM_TAG"
git -C "$git" fetch -q --depth 1 "$UPSTREAM_REPO" "refs/tags/$UPSTREAM_TAG:refs/tags/$UPSTREAM_TAG"

commit=$(git -C "$git" rev-parse "$UPSTREAM_TAG^{commit}")
[ "$commit" = "$UPSTREAM_COMMIT" ] ||
    { echo "fetch: $UPSTREAM_TAG is $commit, expected $UPSTREAM_COMMIT" >&2; exit 1; }

keyring=$cache/$UPSTREAM_NAME-keyring.gpg
rm -f "$keyring"
gpg -q --no-default-keyring --keyring "$keyring" --import "$top/keys/$UPSTREAM_NAME-signing-key.asc" 2>/dev/null
tag=$(git -C "$git" cat-file tag "$UPSTREAM_TAG")
status=$(gpg --no-default-keyring --keyring "$keyring" --status-fd 1 \
             --verify <(sed -n '/^-----BEGIN PGP SIGNATURE/,$p' <<< "$tag") \
                      <(sed '/^-----BEGIN PGP SIGNATURE/,$d' <<< "$tag") 2>/dev/null || true)
echo "$status" | grep -q "^\[GNUPG:\] VALIDSIG .* $UPSTREAM_GPG_KEY\$" ||
    { echo "fetch: tag $UPSTREAM_TAG not validly signed by $UPSTREAM_GPG_KEY" >&2; exit 1; }
echo "fetch: tag signature OK ($UPSTREAM_GPG_KEY), commit $commit"

git -C "$git" archive --format=tar.gz --prefix="$name/" -o "$tarball.tmp" "$commit"
mv "$tarball.tmp" "$tarball"
echo "fetch: $tarball"
