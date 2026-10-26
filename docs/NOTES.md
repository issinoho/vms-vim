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

## N10. $VIMRUNTIME without the VIM or VIMRUNTIME logicals (2026-10-26)

With neither logical defined, Vim derives $VIMRUNTIME from how it was started, and with a
foreign command (`vim :== $dev:[dir]VIM.EXE`) got `$dev:[dir]VIM.EXE;`, and :help failed
("E149: Sorry, no help for help.txt"). The cause: mch_getenv() falls back to getenv(), which
returns DCL symbols, and $VIM was the symbol VIM, the command itself (as LESS was for
vms-less). Patch 0007 looks only in logical names and the C environment. The kit defines
both logicals anyway (D5).
Also: f$parse() returns ODS-5 names in the case they were made (lower case on IA64), so
the tests build directory specs from its DEVICE and DIRECTORY fields.

## N11. vms.sh: empty results from the IA64 node (2026-10-26)

Three times a run on IA64 came back empty right after an sftp upload: the ssh session
failed at once, vms.sh found no DONE marker and no log, and printed nothing. vms.sh now
retries an ssh that fails before the procedure starts (no log on the node) and says when
it has no complete log.

## N12. Screen size when output is not a terminal (2026-10-26)

With SYS$OUTPUT a file, get_tty()'s SENSEMODE fails and gives 0 x 0; mch_get_shellsize()
used it, and Vim made the screen 12 columns by 2 lines. Upstream's tests (run with
--not-a-term, output to a file) all failed with "E36: Not enough room". Patch 0008 returns
FAIL so Vim keeps 80 x 24, as on Unix.

## N13. Upstream's test suite (src/testdir) on VMS (2026-10-26, x86-64)

testdir/Make_vms.mms (2020) runs only the old test20-27 and test77a scripts, in a new
DECterm (needs an X display). The modern suite (320 test_*.vim files with runtest.vim) was
never set up for VMS: util/vms.vim sources util/setup.vim, which sets
$HOME = getcwd() .. '/XfakeHOME' and mkdir()s it. On VMS getcwd() is
`DEV:[DIR.TESTDIR]`, and mkdir() of that mixed spec fails (E739), so no test starts.
tools/vimtests.sh and [.VMS]RUN_TESTS.COM run chosen tests with input from NL: and report
runtest.vim's summary; getting the suite going needs the mkdir() fix below first.

mkdir() with mixed VMS and Unix specs (fixed by patch 0009, see N14): a probe of seven forms (`getcwd() .. '/xa'`, `xb`,
`./xc`, `[.xd]`, `xf/xg`, `getcwd() .. '/xh/xi'`, `expand('~') .. '/x'`, all with 'p')
left VIM.EXE spinning on x86-64, so one of them loops (mkdir_recurse() with VMS's path
separators, filepath.c vim_ispathsep() treats : [ ] < > / all as separators). This also
matters outside the tests: vimrc lines like `call mkdir(expand('~/.vim/undo'), 'p')` are
common. Next: run the forms one at a time (each with a CPU-time limit) and fix.

## N14. mkdir(..., 'p') loops; isdirectory() of mixed names (2026-10-26, x86-64)

Each form run alone as a batch job with /CPUTIME=20: `mkdir(d, 'p')` hit the limit for
`'xb'`, `'[.xd]'` and `getcwd() .. '/xh/xi'`; `getcwd() .. '/xa'` and `~/x` made the
directory but isdirectory() said no. Causes: gettail_sep() on VMS always stepped one
character forward, into the name when there was no separator ("xb" -> "x" -> "x" ...) and
past a '/' (so "dir]/a/" was its own parent); mkdir_recurse() had no stop for a VMS
directory spec; mch_isdir() stat()ed the name as given, and the C RTL takes neither a mixed
name nor the file form of a directory (SUB.DIR). Patch 0009 fixes all three: every form
then works, twice in a row, and isdirectory() agrees. Smoke check mkdir-p.

## N15. vms.sh: long runs on IA64 came back empty (2026-10-26)

The real cause behind N11: during a long run (a build, the smoke test) the ssh session to
IA64 drops while the VMS process carries on. vms.sh took "ssh gone, no DONE marker" as the
end and fetched a log that was still locked. It now keeps polling for DONE until the time
limit.

## N16. A first run of upstream's tests (2026-10-26, x86-64)

tools/vimtests.sh with 37 core test files (docs/testruns/2026-10-26-x86-sample37.txt):
1254 test functions executed, 141 failed (89 % pass), in one batch job with a CPU limit.
Clean: cindent, fold, regexp_latin, regexp_utf8, syntax, textobjects, filter_map, let, join,
changelist, charsearch, put, execute_func. Clusters to look at (Phase 1 follow-ups, not
gating the kit):
- test_vimscript, 63 failures, 42 of them "E484: Can't open file Xtest.out": one cause.
- test_spell, 34 failures: "E751: Output file name must not have region name" from
  :mkspell (its name parsing on VMS), then E756 for the tests that need the spell file.
- test_edit: "Test caused Vim to exit" in a CursorHoldI test: with input from NL: (so that
  no test can hang) Vim reads the end of input; upstream runs the tests in a terminal.
- test_options: no messages file written; to see why.

## N17. PCSI and a big runtime tree (2026-10-26, IA64)

- Material is looked up by name in one flat directory, whatever the tree (as vms-mariadb
  found): a tree-shaped material directory gives %PCSI-E-OPENIN for every file. With
  `file [VIMPROBE.A]X.TXT source [000000]R0001.DAT ;` duplicate names package fine.
- PCSI upper-cases names: `a^.b.json` is stored as `A^.B.JSON`, `[VIMPROBE.lower]` as
  `[VIMPROBE.LOWER]`. A quoted name in the PDF is %PCSI-E-PDFIVS.
- On ODS-5, RENAME can change only the case of a file (C.VIM -> c.vim, A^.B.JSON ->
  a^.b.json). Renaming a directory file needs privilege (SYSTEM has it at install).

## N18. sftp to VMS: a final ".<digits>" becomes a version (2026-10-26)

VSI OpenSSH's sftp server stored `xxd-fr.UTF-8.1` as `xxd-fr.UTF-8;1`: after a dot it
reads a final number as the version. The runtime has 43 such names (doc/*.UTF-8.1, the
translated man pages), and MAKE_KIT's copy of them failed. push.sh now uploads them as
`<name>_` and renames them on the node to `xxd-fr^.UTF-8.1` (and deletes the mangled copy).

## N19. Two runtime files PCSI cannot name (2026-10-26)

PCSI's product description rejects ODS-5 escapes for parentheses
(`file [VIM.VIM92.LANG]MENU_CHINESE^(GB^)_GB^.936.VIM ...` is %PCSI-E-PDFIVS). The runtime
has two such names, lang/menu_chinese(gb)_gb.936.vim and
lang/menu_chinese(taiwan)_taiwan.950.vim: menu translations for Chinese GB2312 and Big5
locales, used only by Vim's menus. gen_kit.py leaves them out and lists them; installing
them under another name would leave PRODUCT REMOVE unable to find them.
