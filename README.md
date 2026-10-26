# vms-vim

Vim, the editor, for OpenVMS (IA64 and x86-64), built natively with VSI C from upstream's
signed release tags, with a PCSI kit.

Upstream Vim keeps its VMS support (src/os_vms*.c, src/Make_vms.mms). This port builds
upstream as it stands, follows its releases, and adds what upstream does not ship: a
verified source, a repeatable build on both architectures, tests, and an installer. The
existing binaries at [polarhome.com/vim](http://www.polarhome.com/vim/) are zip files of
executables, with no installer, and lag upstream.

The repository stores only our changes over the upstream tag:
- `patches/` holds changes to upstream files, applied in `patches/series` order.
- `overlay/` holds new files: VMS build procedures and the PCSI kit.

`tools/prepare.sh` combines them with the tag into `staging/`, which is pushed to a VMS
node and built there with MMS. The tooling is shared with the other ports in the family;
see [vms-grep](https://github.com/issinoho/vms-grep) for the list.

## Status

Phase 0 (see [docs/PLAN.md](docs/PLAN.md)).

| Step | IA64 (V8.4-2L3) | x86-64 (E9.2-4) |
|------|-----------------|-----------------|
| Build with upstream's Make_vms.mms + patch 0001 (`tools/build.sh`) | clean | clean |
| `vim --version`, xxd | run | run |

## Workflow

```sh
cp tools/nodes.conf.example tools/nodes.conf   # then fill in the real nodes
tools/prepare.sh                               # fetch and verify the tag, patch, stage
tools/build.sh <node>                          # push and build with MMS
```

## What the port changes

| Change | Why |
|---|---|
| `0001-vms-mch-calc-cell-size` | Upstream 9.2 calls mch_calc_cell_size(), which VMS lacked: VIM.EXE did not link ([N2](docs/NOTES.md)) |
| `vms/build.com` | Runs upstream's Make_vms.mms for VIM.EXE and XXD.EXE |
