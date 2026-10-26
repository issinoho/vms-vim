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

Phases 0-2 done; release (Phase 4) next. See [docs/PLAN.md](docs/PLAN.md).

| Step | IA64 (V8.4-2L3) | x86-64 (E9.2-4) |
|------|-----------------|-----------------|
| Build with upstream's Make_vms.mms + patch 0001 (`tools/build.sh`) | clean | clean |
| DCL smoke test, 29 checks (`tools/test.sh`) | 29/29 | 29/29 |
| PCSI kit `ISSINOHO <base> VIM V9.2-1240E1` (`tools/kit.sh`) | built (52 MB) | built (49 MB) |
| Install check (`tools/installcheck.sh`): install, smoke 27/27, clean removal | pass (17 min) | pass (5 min) |
| Interactive test, 20 checks (`tools/ttytest.sh`) | 20/20 | 20/20 |

## Workflow

```sh
cp tools/nodes.conf.example tools/nodes.conf   # then fill in the real nodes
tools/prepare.sh                               # fetch and verify the tag, patch, stage
tools/build.sh <node>                          # push and build with MMS
tools/push.sh <node> runtime                   # once: the runtime files, for the tests
tools/test.sh <node>                           # smoke test (non-interactive, on VMS)
tools/ttytest.sh <node>                        # interactive test from the host (pexpect, pyte)
tools/vimtests.sh <node> join,sort,...         # upstream's tests (push.sh <node> testdir first)
tools/kit.sh <node>                            # PCSI kit -> out/kits/ (producer ISSINOHO)
tools/installcheck.sh <node>                   # install, verify, remove (changes the system)
```

## What the port changes

| Change | Why |
|---|---|
| `0001-vms-mch-calc-cell-size` | Upstream 9.2 calls mch_calc_cell_size(), which VMS lacked: VIM.EXE did not link ([N2](docs/NOTES.md)) |
| `0002-termlib-strncpy-casts` | The only compiler warnings in the VMS build ([N3](docs/NOTES.md)) |
| `0003-vms-read-non-terminal-input` | Input from a file or mailbox: Vim looped for ever ([N4](docs/NOTES.md)) |
| `0004-vms-fopen-record-files` | `:source`, readfile(), system() on VAR/VFC files ran the lines together ([N5](docs/NOTES.md)) |
| `0005-vms-settmode-sleep-deccolm` | `:!cmd` output wiped by DECCOLM; CTRL-C while sleeping ([N7](docs/NOTES.md)) |
| `0006-vms-breakcheck-tmode` | CTRL-C interrupted nothing ([N8](docs/NOTES.md)) |
| `0007-vms-getenv-no-symbols` | `$VIM` was the DCL symbol `vim` (the command itself) ([N10](docs/NOTES.md)) |
| `0008-vms-shellsize-unknown` | With output to a file the screen was 12x2 ([N12](docs/NOTES.md)) |
| `0009-vms-mkdir-p-isdir` | `mkdir(d, 'p')` looped; isdirectory() of `dir]/sub` ([N14](docs/NOTES.md)) |
| `0010-vms-rename-case-only` | rename() that changed only the case left the file as `123.VIM` ([N17](docs/NOTES.md)) |
| `vms/build.com` | Runs upstream's Make_vms.mms for VIM.EXE and XXD.EXE |
| `vms/test_smoke.com`, `tools/ttytest.py` | Smoke test (DCL, `vim -es`) and interactive test (pexpect + pyte over ssh) |
