# Notes

Findings while porting, numbered so the decisions and patches can refer to them.

## N1. PCSI takes the patch number as the update (2026-10-26, x86-64 E9.2-4)

PRODUCT PACKAGE accepts V9.2-1240, V9.2-256 and V9.2-1240E1 (no limit at 255). The kit
file for V9.2-1240E1 is ISSINOHO-X86VMS-<PRODUCT>-V0902-1240E1-1.PCSI. So D4's
V9.2-<patch>E<level> works.

## N2. Upstream 9.2.1240 builds on VMS but does not link (2026-10-26)

Make_vms.mms (MODEL HUGE, terminal only) compiles everything on IA64 V8.4-2L3 and
x86-64 E9.2-4 unchanged, but the link fails with %ILINK-W-USEUNDEF MCH_CALC_CELL_SIZE:
the image-popup work (PR #20136) calls it from term.c, and only os_unix.c (outside VMS),
os_win32.c and os_mswin.c define it. Not fixed on upstream master as of today. Patch 0001
adds a VMS version to os_vms.c; to be offered upstream. With it, VIM.EXE (15159 blocks on
x86-64) and XXD.EXE build, and `vim --version` reports "Included patches: 1-1240" on both.
The first full build reported 4 compiler warnings or informationals; to be reviewed with a
CLEAN build in Phase 1.
