$! VIM$STARTUP.COM - system startup for Vim on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical names
$! VIM$ROOT (the installed [VIM] directory, concealed), and VIM and VIMRUNTIME
$! as Vim expects them.  To run it at every boot, add this line to
$! SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:VIM$STARTUP.COM
$!
$! P1 = "INSTALL": also give the runtime files their real names (PCSI installs
$!                 them in upper case) and print the post-installation tasks;
$!                 PCSI runs it so.
$! P1 = "REMOVE":  deassign the logical names instead (PCSI runs it so).
$!
$! Users then define the commands with
$!     $ @VIM$ROOT:[000000]VIM$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("VIMRUNTIME", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode VIMRUNTIME
$   if f$trnlnm("VIM", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode VIM
$   if f$trnlnm("VIM$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode VIM$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[VIM].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.VIM.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "VIM.]"
$ if root .eqs. dir + "VIM.]"
$ then
$   write sys$error "VIM$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed VIM$ROOT 'dev''root'
$ define/system/executive_mode VIM VIM$ROOT:[000000]
$ define/system/executive_mode VIMRUNTIME VIM$ROOT:[VIM92]
$ if f$search("VIM$ROOT:[BIN]VIM.EXE") .eqs. ""
$ then
$   write sys$error "VIM$STARTUP: VIM.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$!
$! PCSI stores every file name in upper case; Vim's runtime has lower-case and
$! mixed-case names (scripts look for them so).  VIM$CASE.VIM renames each
$! file and directory under [VIM92] back to its real name.
$! Renaming a directory file needs delete access, which PCSI does not give:
$! add it for the system and owner categories while renaming, then put back
$! what PCSI set ("SYSTEM=RWE, OWNER=RWE, GROUP=RE, WORLD=RE").
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ pro = f$file_attributes("VIM$ROOT:[000000]VIM92.DIR", "PRO")
$ sys_access = f$element(1, "=", f$element(0, ",", pro))
$ own_access = f$element(1, "=", f$element(1, ",", pro))
$ set protection=(s:rwed,o:rwed) VIM$ROOT:[VIM92...]*.DIR;*
$ vimexe = "$VIM$ROOT:[BIN]VIM.EXE"
$ define/user sys$input nl:
$ define/user sys$output nl:
$ vimexe -es -u NONE -i NONE -n "+source VIM$ROOT:[000000]VIM$CASE.VIM"
$ set protection=(s:'sys_access',o:'own_access') VIM$ROOT:[VIM92...]*.DIR;*
$ set process/parse_style='saved_parse'
$! VIM$CASE.VIM lists any name it could not change in SYS$SCRATCH:VIM$CASE.ERR.
$ if f$search("SYS$SCRATCH:VIM$CASE.ERR") .nes. ""
$ then
$   write sys$error "VIM$STARTUP: some runtime files kept upper-case names:"
$   type SYS$SCRATCH:VIM$CASE.ERR
$   delete/nolog SYS$SCRATCH:VIM$CASE.ERR;*
$ endif
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for Vim"
$ say ""
$ say "    At system startup: to define VIM$ROOT, VIM and VIMRUNTIME at every"
$ say "    boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:VIM$STARTUP.COM"
$ say "    For each user: to define the commands (vim, vi, view, vimdiff,"
$ say "    vimtutor, xxd), add this line to LOGIN.COM or SYS$MANAGER:SYLOGIN.COM:"
$ say "    $ @VIM$ROOT:[000000]VIM$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE VIM removes the product and deassigns the logical names."
$ say ""
$ exit 1
