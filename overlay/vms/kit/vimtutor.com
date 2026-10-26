$! VIMTUTOR.COM [language] [chapter] - the Vim tutor
$!
$! Copies the tutor (in the language of P1, such as "de", or the default) to a
$! scratch file, opens it in Vim, and deletes it at the end.  P2 is the chapter
$! (1 or 2).  Defined as the vimtutor command by VIM$SETUP.COM.
$!
$ set noon
$ if f$trnlnm("VIM$ROOT") .eqs. ""
$ then
$   write sys$error "VIMTUTOR: VIM$ROOT is not defined; run SYS$STARTUP:VIM$STARTUP.COM first"
$   exit 44
$ endif
$ on control_y then goto done
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ vimexe = "$VIM$ROOT:[BIN]VIM.EXE"
$ tut = "SYS$SCRATCH:VIMTUTOR_" + f$getjpi("", "PID") + ".TXT"
$ define/nolog tutorcopy 'tut'
$ lang = f$edit(p1, "LOWERCASE")
$ if lang .nes. "" then define/nolog xx "''lang'"
$ if p2 .nes. "" then define/nolog chapter "''p2'"
$! tutor.vim picks the file and writes it to $TUTORCOPY.
$ define/user sys$input nl:
$ define/user sys$output nl:
$ vimexe -es -u NONE -i NONE -n "+source $VIMRUNTIME/tutor/tutor.vim"
$ if f$search(tut) .eqs. ""
$ then
$   write sys$error "VIMTUTOR: could not make a copy of the tutor"
$   goto done
$ endif
$ define/user sys$input sys$command
$ vimexe -u NONE -N -i NONE "+set showcmd" 'tut'
$done:
$ if f$search(tut) .nes. "" then delete/nolog 'tut';*
$ if f$trnlnm("tutorcopy", "LNM$PROCESS") .nes. "" then deassign tutorcopy
$ if f$trnlnm("xx", "LNM$PROCESS") .nes. "" then deassign xx
$ if f$trnlnm("chapter", "LNM$PROCESS") .nes. "" then deassign chapter
$ set process/parse_style='saved_parse'
$ exit 1
