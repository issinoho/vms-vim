$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the VIM kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[VIM], system logicals VIM$ROOT, VIM, VIMRUNTIME);
$! leaves it as it was.
$ set noon
$ set process/parse_style=extended
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ t0 = f$time()
$ product install VIM /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm
$ write sys$output "=== install status ", $status, " (", t0, " - ", f$time(), ")"
$ product show product VIM /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:VIM$STARTUP.COM"), "]"
$ show logical VIM$ROOT
$ show logical VIM
$ show logical VIMRUNTIME
$ @VIM$ROOT:[000000]VIM$SETUP.COM
$ show symbol vim
$ show symbol view
$! vimdiff and view must pass -d and -R with either parse style.
$ create sys$scratch:vda.txt
one
$ create sys$scratch:vdb.txt
two
$ style = "TRADITIONAL"
$vd_loop:
$ set process/parse_style='style'
$ if f$search("sys$scratch:vd.txt") .nes. "" then delete/nolog sys$scratch:vd.txt;*
$ define/user sys$input nl:
$ vimdiff -es -u NONE -i NONE -n "+call writefile([&diff, &readonly], 'sys$scratch:vd.txt')" "+qa!" sys$scratch:vda.txt sys$scratch:vdb.txt
$ vd_diff = "missing"
$ if f$search("sys$scratch:vd.txt") .nes. ""
$ then
$   open/read vdf sys$scratch:vd.txt
$   read vdf vd_diff
$   close vdf
$   delete/nolog sys$scratch:vd.txt;*
$ endif
$ define/user sys$input nl:
$ view -es -u NONE -i NONE -n "+call writefile([&readonly], 'sys$scratch:vd.txt')" "+qa!" sys$scratch:vda.txt
$ vd_ro = "missing"
$ if f$search("sys$scratch:vd.txt") .nes. ""
$ then
$   open/read vdf sys$scratch:vd.txt
$   read vdf vd_ro
$   close vdf
$   delete/nolog sys$scratch:vd.txt;*
$ endif
$ write sys$output "symbols ''style': vimdiff diff=''vd_diff' view readonly=''vd_ro'"
$ if style .eqs. "TRADITIONAL"
$ then
$   style = "EXTENDED"
$   goto vd_loop
$ endif
$ delete/nolog sys$scratch:vda.txt;*,sys$scratch:vdb.txt;*
$ define/user sys$output sys$scratch:vimver.txt
$ vim "--version"
$ open/read v sys$scratch:vimver.txt
$ read v verline
$ close v
$ delete/nolog sys$scratch:vimver.txt;*
$ write sys$output "version: ", verline
$! The runtime has its real names again (VIM$CASE.VIM).
$ write sys$output "=== NAMES (as stored)"
$ directory/noheading/notrailing VIM$ROOT:[VIM92]*.VIM,VIM$ROOT:[VIM92]*.DIR
$ directory/noheading/notrailing VIM$ROOT:[VIM92.syntax]c*.vim
$ directory/noheading/notrailing VIM$ROOT:[VIM92.pack.dist.opt]*.DIR
$ directory/noheading/notrailing/protection/owner VIM$ROOT:[BIN]*.EXE,VIM$ROOT:[VIM92]defaults.vim,VIM$ROOT:[VIM92]syntax.DIR
$ nrt = 0
$ nupper = 0
$count:
$ rtf = f$search("VIM$ROOT:[VIM92...]*.*;", 1)
$ if rtf .eqs. "" then goto counted
$ nrt = nrt + 1
$ rtname = f$parse(rtf,,,"NAME") + f$parse(rtf,,,"TYPE")
$ if rtname .eqs. f$edit(rtname, "UPCASE") .and. rtname .nes. f$edit(rtname, "LOWERCASE") then nupper = nupper + 1
$ goto count
$counted:
$ write sys$output "runtime files: ''nrt', all upper case: ''nupper'"
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMS]TEST_SMOKE.COM"
$ @'smoke' VIM$ROOT:[BIN]VIM.EXE VIM$ROOT:[BIN]XXD.EXE VIM$ROOT:[VIM92]
$ write sys$output "=== REMOVE"
$ product remove VIM /producer=ISSINOHO /options=noconfirm
$ write sys$output "=== remove status ", $status
$ write sys$output "VIM$ROOT after removal: [", f$trnlnm("VIM$ROOT"), "]"
$ write sys$output "VIMRUNTIME after removal: [", f$trnlnm("VIMRUNTIME"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[VIM...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:VIM$STARTUP.COM"), "]"
$ product show product VIM /producer=ISSINOHO
$ delete/symbol/global vim
$ delete/symbol/global vi
$ delete/symbol/global view
$ delete/symbol/global vimdiff
$ delete/symbol/global vimtutor
$ delete/symbol/global xxd
