$! RUN_TESTS.COM test_a test_b ... - run tests from upstream's src/testdir
$!
$! Runs each test_<name>.vim with runtest.vim as upstream's Makefile does
$! (-u util/vms.vim -U NONE --noplugin --not-a-term), input from NL: so a
$! test that waits for keys ends instead of hanging, and prints one line per
$! test from runtest.vim's "messages" file. Needs the runtime (push.sh <node>
$! runtime) and the test directory (push.sh <node> testdir). Tests are named
$! in P1-P8, each a comma-separated list; names without "test_" are fine.
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ image = f$parse("[.SRC.''arch']VIM.EXE")
$ rt = f$parse("[.RUNTIME]",,,"DEVICE") + f$parse("[.RUNTIME]",,,"DIRECTORY")
$ define/nolog vimruntime 'rt'
$ define/nolog tmp sys$scratch
$ vim = "$" + image
$ set default [.SRC.TESTDIR]
$ list = p1 + "," + p2 + "," + p3 + "," + p4 + "," + p5 + "," + p6 + "," + p7 + "," + p8
$ n = 0
$ ran = 0
$loop:
$ t = f$edit(f$element(n, ",", list), "TRIM,LOWERCASE")
$ n = n + 1
$ if t .eqs. "," then goto done
$ if t .eqs. "" then goto loop
$ if f$locate("test_", t) .ne. 0 then t = "test_" + t
$ if f$search("''t'.vim") .eqs. ""
$ then
$   write sys$output "VIMTEST ''t' MISSING"
$   goto loop
$ endif
$ if f$search("messages.;*") .nes. "" then delete/nolog messages.;*
$ if f$search("test.log;*") .nes. "" then delete/nolog test.log;*
$ define/user sys$input nl:
$ define/user sys$output 'f$trnlnm("SYS$SCRATCH")'vimtest.out
$ vim -f -u util/vms.vim -U NONE --noplugin --not-a-term -S runtest.vim 't'.vim
$ st = $status
$ ran = ran + 1
$ summary = ""
$ nskip = 0
$ if f$search("messages.") .nes. ""
$ then
$   open/read m messages.
$mloop:
$   read/end=mdone m line
$!  runtest.vim's totals ("Executed N tests in S seconds", "N FAILED:") and
$!  the number of "Skipped" lines (one per skipped test function).
$   len = f$length(line)
$   if len .gt. 0 .and. f$locate("Executed ", line) .eq. 0 .and. f$locate("Test_", line) .eq. len then -
        summary = summary + " | " + f$edit(line, "TRIM,COMPRESS")
$   if f$locate("FAILED", line) .lt. len then -
        summary = summary + " | " + f$edit(line, "TRIM,COMPRESS")
$   if f$locate("Skipped", line) .lt. len then nskip = nskip + 1
$   goto mloop
$mdone:
$   close m
$ else
$   summary = " | no messages file"
$ endif
$ write sys$output "VIMTEST ''t' status=''st'''summary' | skipped ''nskip'"
$ if f$search("test.log.") .nes. ""
$ then
$   write sys$output "VIMTEST-LOG ''t' begin"
$   type test.log.
$   write sys$output "VIMTEST-LOG ''t' end"
$ endif
$ goto loop
$done:
$ write sys$output "VIMTESTS: ran ''ran'"
$ deassign vimruntime
$ deassign tmp
$ set process/parse_style='saved_parse'
$ set default 'saved_default'
$ exit 1
