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

## N3. Compiler warnings (2026-10-26)

A CLEAN build of 9.2.1240 gives four %CC-W-PTRMISMATCH1 warnings, all in termlib.c (Vim's
own termcap, built only on VMS): vim_strncpy() given char pointers. Patch 0002 casts them;
the build is then free of warnings on both nodes.

## N4. Input that is not a terminal: Vim spins for ever (2026-10-26)

vms_read() and RealWaitForChar() read keys with terminal QIOs on a channel assigned to
SYS$OUTPUT, whatever read_cmd_fd is. With SYS$INPUT a file (DEFINE/USER SYS$INPUT, PIPE, a
batch job or a procedure), the QIOs fail, nothing is read, and Vim loops using all the CPU:
`vim -es` with an Ex script on SYS$INPUT never ended. Patch 0003 reads such input with
read(), as on Unix; the end of the input then ends Vim. (The first smoke run left one such
process spinning on the x86-64 node; STOP needs the user's go-ahead.)

## N5. Record files read in binary mode run their lines together (2026-10-26)

Vim reads text with fopen(..., "rb") and splits lines itself: :source, readfile(),
system() output, viminfo, help, `-s` scripts. On a VAR or VFC file a binary stream returns
records without line ends, so `:source` of a file made by DCL CREATE gave
"E492: Not an editor command: vim9scriptdef Twice...". A .vimrc made with EDIT would fail
the same way. Buffers were not affected (readfile() in fileio.c uses open() and read(),
which end each record with a newline). Patch 0004 routes mch_fopen() through vms_fopen(),
which opens VAR and VFC files as text when "rb" is asked for.

## N6. Record formats Vim writes (2026-10-26, x86-64)

Editing a VAR file writes a new version that is VAR; a STREAM_LF file stays STREAM_LF; a
VFC file (print carriage control) is written back as VAR. A new file is STREAM_LF.

## N7. `:!cmd` output wiped by DECCOLM (2026-10-26)

Before every `:!cmd`, mch_settmode(TMODE_COOK) sent ESC [ ? 3 l (DECCOLM, 80 columns) to
restore the original width. DECCOLM clears the screen and homes the cursor on VT
terminals and DECterm even when the width does not change, so the command's output landed
on the top line and the hit-enter prompt scrolled it away. Patch 0005 sends DECCOLM only
when Vim has changed the width.

## N8. CTRL-C did not interrupt anything (2026-10-26)

`:sleep 12` with CTRL-C typed after 1.5 s ran the full 12 s, and the CTRL-C then arrived
as a key ("Type :qa and press <Enter> to exit Vim"). os_unix.c's mch_breakcheck() checks
for typed keys only when its static mch_cur_tmode is TMODE_RAW; only Unix's mch_settmode()
sets it, so on VMS it was always TMODE_COOK and no break check ever read the keyboard.
Patch 0006 makes os_unix.c use settmode()'s cur_tmode on VMS. That also brings
mch_delay()'s TMODE_SLEEP into use, which patch 0005 keeps raw (in the original mode the
terminal driver would swallow the CTRL-C).

## N9. Terminal type and keys (2026-10-26)

The C RTL sets TERM from the device type (`vt500-80` over ssh); Vim's builtin vt320 entry
matches it. Cursor keys arrive as CSI sequences (ESC [ B) in normal cursor mode, and Vim
does not switch to application mode (t_ks empty), so SS3 sequences are not expected.
Vim's exit status is %X00030001 (success severity, with a facility code).
