# CLAUDE.md

Guidance for working in this repository: a port of Vim to OpenVMS (IA64 and x86-64) that
stores only our changes over an upstream Vim tag. Read README.md and docs/PLAN.md first;
docs/DECISIONS.md (D1-D7) and docs/NOTES.md hold what has been settled and found.

## Ground rules

- **Never edit `staging/`, `cache/` or `out/`.** They are regenerated. Every VMS change is
  either a patch (`patches/NNNN-*.patch`, listed in `patches/series`) or a new file in
  `overlay/`. `tools/prepare.sh` refuses overlay files that would replace upstream files.
- **Change an upstream file with a patch**, made with `diff -u a/<path> b/<path>`, with a
  `Subject:` line and a short explanation above it. Upstream already has VMS code
  (`src/os_vms*.c`, `src/Make_vms.mms`): follow its style and `#ifdef VMS` so the patch can
  be sent upstream (D1).
- **The source is a signed tag** (upstream.conf). To move to a new tag, change
  UPSTREAM_TAG, UPSTREAM_VERSION and UPSTREAM_COMMIT together; fetch.sh refuses a tag that
  is not signed by the pinned key or does not point at the commit.
- **Committed files must not contain real node details.** Use `<ia64-host>`, `<x86-host>`
  and `DISK$USER:[USERNAME.VMS_VIM]`. Real values live only in the git-ignored
  `tools/nodes.conf`.

## Commands

```sh
tools/prepare.sh                 # always first after changing patches/ or overlay/
tools/build.sh <ia64|x86> [ALL|CLEAN]
tools/push.sh <node> runtime     # also upload runtime/ (kit, tests)
tools/vms.sh <node> dcl '<cmd>'  # run DCL; also run/batch/put/get
```

Run full builds with `run_in_background`. MMS does not track compiler flags: after
changing them, build CLEAN first.

## VMS and tooling pitfalls (from the family)

- **Use `tools/vms.sh`, never raw `ssh host cmd`.** Raw ssh output is often lost and
  sessions sometimes never close.
- **Never use `WAIT` in DCL run over ssh**; it hangs.
- **Never edit a bash script that is running.**
- **Kill by explicit PID**, never `pkill -f`. On VMS stop only processes this session
  started.
- **`sftp put -r` into an existing directory nests a copy**; push.sh uploads file by file.
- **A runaway interactive program starves the IA64 node** (one CPU). Find it with
  `SHOW SYSTEM/PROCESS=FTA*`, check `F$GETJPI(pid,"IMAGNAME")`, `STOP/ID=` it. Run new
  interactive cases with a timeout.
- `CALL` arguments and unquoted DCL arguments are upper-cased; Vim on VMS reads `-/r` as
  `-R` (upstream's convention, os_vms.txt).
- `SYS$LOGIN:[.X]` is not valid on these nodes.

## Commits

Commit in logical steps with messages that explain the VMS reason for each change. Don't
push without the user asking.
