$! BUILD.COM [ALL|CLEAN] - build VIM.EXE and XXD.EXE with upstream's Make_vms.mms.
$! Run from anywhere: it works in the [.SRC] directory next to this [.VMS] one.
$ set noon
$ target = f$edit(p1,"upcase,trim")
$ if target .eqs. "" then target = "ALL"
$! ODS-5 keeps the case the directories were made with: compare in upper case.
$ here = f$edit(f$parse(f$environment("procedure"),,,"device") + -
         f$parse(f$environment("procedure"),,,"directory"), "upcase")
$ src = here - ".VMS]" + ".SRC]"
$ set default 'src'
$ write sys$output "BUILD: ''target' in ''src' on ''f$getsyi("arch_name")' ''f$getsyi("version")'"
$ show time
$ if target .eqs. "CLEAN"
$ then
$   mms/descrip=Make_vms.mms/ignore=warning clean
$ else
$   mms/descrip=Make_vms.mms/ignore=warning
$   set default [.xxd]
$   mms/descrip=Make_vms.mms/ignore=warning
$   set default [-]
$ endif
$ show time
$ write sys$output "BUILD: done"
$ exit
