$! VIM$SETUP.COM - define the Vim commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @VIM$ROOT:[000000]VIM$SETUP.COM
$!
$! Options: Vim reads "-x" as -x and "-/x" as -X whatever the DCL parse style;
$! with SET PROCESS/PARSE_STYLE=EXTENDED, quoted options keep their case too
$! ("-R").  Options and file names that must keep upper case need quotes.
$!
$ if f$trnlnm("VIM$ROOT") .eqs. ""
$ then
$   write sys$error "VIM$SETUP: VIM$ROOT is not defined; run SYS$STARTUP:VIM$STARTUP.COM first"
$   exit 44
$ endif
$ vim      :== $VIM$ROOT:[BIN]VIM.EXE
$ vi       :== $VIM$ROOT:[BIN]VIM.EXE
$ view     :== $VIM$ROOT:[BIN]VIM.EXE -/r
$ vimdiff  :== $VIM$ROOT:[BIN]VIM.EXE -d
$ vimtutor :== @VIM$ROOT:[000000]VIMTUTOR.COM
$ xxd      :== $VIM$ROOT:[BIN]XXD.EXE
$! Vim and xxd need TMP for filters, printing and some functions.
$ if f$trnlnm("TMP") .eqs. "" then define/nolog tmp sys$scratch
$ exit 1
