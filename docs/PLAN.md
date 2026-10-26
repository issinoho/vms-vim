# vms-vim: Vim for OpenVMS, tracking upstream, with a PCSI kit

## Goal

Vim on IA64 and x86-64, built natively with VSI C from upstream's signed tags, installed
and removed with PRODUCT INSTALL / PRODUCT REMOVE like the rest of the family.

Why a family port when polarhome.com/vim exists: polarhome ships zip files of executables
(9.2.0491 in May 2026, while upstream is at 9.2.1240), with no installer, and its builds
follow upstream only when someone has time. Upstream Vim itself keeps the VMS support
(src/os_vms*.c, src/Make_vms.mms, maintained by Zoltan Arpadffy, last change 2026-05-04),
so this port builds upstream as it stands and adds what is missing: a pinned, verified
source, a repeatable build on both nodes, tests, and a kit.

The repository stores only our changes over the upstream tag (patches/, overlay/), as in
vms-less. Any patch we need is written so it can go upstream, and is offered there.

## Phase 0: scaffolding and first build (started 2026-10-26)

- Repo from vms-less's tooling: fetch.sh verifies the signed tag against the pinned key
  and checks the commit id, then makes the tarball with git archive (Vim publishes no
  tarballs). prepare.sh, push.sh, build.sh, vms.sh. Done.
- Build upstream's Make_vms.mms unchanged (HUGE, terminal only) on both nodes. Record what
  breaks (NOTES).
- Probe: whether PCSI accepts a version that carries the patch number (V9.2-1240, D4).

Status 2026-10-26: builds on both nodes with patch 0001 (N2); `vim --version` and xxd run.
PCSI takes V9.2-1240E1 (N1).

Exit: VIM.EXE and XXD.EXE build on both nodes and `vim --version` runs (done); the user
signs off this plan and D1-D7.

## Phase 1: the editor works (started 2026-10-26)

Status 2026-10-26: patches 0002-0009 (N3-N14). Both nodes: smoke test 28/28 (vimtutor and
mkdir included), interactive test 20/20. Upstream's tests, 37-file sample on x86-64: 1254
run, 89 % pass (N16); the failure clusters are follow-ups, not gating Phase 2.

- Smoke test (tools/test.sh, DCL, non-interactive): `-version`, `-es` scripts that edit and
  write files of each record format (STREAM_LF, VAR, VFC), new file versions, xxd round trip.
- Interactive test from the host (tools/ttytest.py, pexpect + pyte, from vms-less): VT220
  and xterm, arrow/editing keys, PF keys, resize, `:!` DCL, `:sh`, CTRL/C, suspend.
- Runtime from VIM/VIMRUNTIME: syntax highlighting, filetype plugins, `:help`, vimtutor.
- Upstream's own test suite (src/testdir): see how much runs under DCL; record, not gate.
- Patches for whatever fails, each offered upstream.

## Phase 2: the kit (started 2026-10-26)

PCSI upper-cases every file name it installs (probe, N17), so runtime files would be
SYNTAX/C.VIM: Vim still finds them (lookups ignore case), but listings and plugins that
match names case-sensitively would not. The post-install step therefore renames the
runtime back to its real case with Vim's own rename(), from a list prepare.sh makes.
Material is flat (PCSI looks files up by name only): each runtime file gets a unique
material name through the PDF's `source` clause.

Status 2026-10-26: tools/kit.sh builds ISSINOHO-X86VMS-VIM-V0902-1240E1-1.PCSI (49 MB,
5439 runtime files; two left out, N19). Patch 0010 (rename() of a case-only change lost
the file's name) was needed for the case fix-up. Next: the IA64 kit, then the install
check on each node (tools/installcheck.sh, PRODUCT INSTALL: with the user's go-ahead).

- PCSI kit ISSINOHO <base> VIM (D4, D5): VIM.EXE, XXD.EXE, the runtime tree (about 5,400
  files; prepare.sh generates the product description's file list), VIM$STARTUP.COM,
  VIM$SETUP.COM, README.VMS, docs.
- tools/kit.sh and tools/installcheck.sh (install, smoke test, clean removal) on both nodes.

## Phase 3: GUI (if D3 says yes)

- Motif build (GVIM.EXE) with DECwindows, shown over Xephyr on the laptop.

## Phase 4: release

- The family release process: tag v9.2.1240-vms1, GitHub release with both kits and
  SHA256SUMS, entry in vms-grep/site/projects.json and the vms-grep README.
- Updating to a newer upstream tag (D2) is then: change upstream.conf, prepare, build,
  test, kit.
