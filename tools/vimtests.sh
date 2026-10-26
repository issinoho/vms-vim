#!/usr/bin/env bash
# vimtests.sh <node> test_a,test_b,... - run tests from upstream's src/testdir on <node>
# with [.VMS]RUN_TESTS.COM. Push them first: tools/push.sh <node> testdir.
# Output: out/vimtests-<node>.log. Records, does not gate (docs/PLAN.md Phase 1).
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
node=${1:?usage: vimtests.sh <node> test,test,...}
tests=${2:?usage: vimtests.sh <node> test,test,...}
. "$top/upstream.conf"
remote=$(echo "$UPSTREAM_NAME-$UPSTREAM_VERSION" | tr . _ | tr a-z A-Z)
read -r _ _ _ _ _ WORKDIR _ < <(awk -v n="$node" '$1==n' "$top/tools/nodes.conf")

# DCL parameters are limited in length: split the list into up to 8 of them.
parts=() cur=
for t in ${tests//,/ }; do
    if [ $(( ${#cur} + ${#t} )) -gt 200 ]; then parts+=("$cur"); cur=; fi
    cur=${cur:+$cur,}$t
done
[ -n "$cur" ] && parts+=("$cur")
[ ${#parts[@]} -le 8 ] || { echo "vimtests: too many tests for 8 DCL parameters" >&2; exit 2; }
job=$top/cache/vimtests-$node.com
{ echo '$ set noon'
  printf '$ @%s.%s.VMS]RUN_TESTS.COM' "${WORKDIR%]}" "$remote"
  for p in "${parts[@]}"; do printf ' "%s"' "$p"; done; echo; } > "$job"
VMS_TIMEOUT=${VMS_TIMEOUT:-3600} "$top/tools/vms.sh" "$node" run "$job" | grep -av '^$' |
    tee "$top/out/vimtests-$node.log" | grep -a '^VIMTEST'
