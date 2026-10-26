#!/usr/bin/env bash
# test.sh <node> - run [.VMS]TEST_SMOKE.COM against the built images on <node>.
# Pushes the tree first (the runtime only if it was pushed before: push.sh <node> runtime).
# Output is saved to out/smoke-<node>.log; exit status 0 only if all tests pass.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
node=${1:?usage: test.sh <node>}
. "$top/upstream.conf"
remote=$(echo "$UPSTREAM_NAME-$UPSTREAM_VERSION" | tr . _ | tr a-z A-Z)
read -r _ _ _ _ _ WORKDIR _ < <(awk -v n="$node" '$1==n' "$top/tools/nodes.conf")

"$top/tools/push.sh" "$node" >/dev/null
mkdir -p "$top/out"
job=$top/cache/smoke-$node.com
printf '$ set noon\n$ @%s.%s.VMS]TEST_SMOKE.COM\n' "${WORKDIR%]}" "$remote" > "$job"
VMS_TIMEOUT=900 "$top/tools/vms.sh" "$node" run "$job" | grep -av '^$' | tee "$top/out/smoke-$node.log"
grep -aq 'SMOKE: [0-9]* passed, 0 failed' "$top/out/smoke-$node.log"
