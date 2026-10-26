$! TEST_SMOKE.COM - quick non-interactive check of a built or installed VIM.EXE
$!
$! Usage:  @[.VMS]TEST_SMOKE [vim-image [xxd-image [runtime-dir]]]
$!         The defaults are this tree's [.SRC.<arch>]VIM.EXE, [.SRC.XXD.<arch>]XXD.EXE
$!         and [.RUNTIME] (pushed with tools/push.sh <node> runtime).
$! Vim runs in silent Ex mode (-es), so nothing here needs a terminal; the
$! interactive behaviour is tested from the host by tools/ttytest.py.
$! Exits with SS$_NORMAL if every test passes, otherwise reports failures.
$!
$ set noon
$ on control_y then goto finish
$ saved_default = f$environment("DEFAULT")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ image = p1
$ if image .eqs. "" then image = f$parse("[.SRC.''arch']VIM.EXE")
$ xximage = p2
$ if xximage .eqs. "" then xximage = f$parse("[.SRC.XXD.''arch']XXD.EXE")
$ rtdir = p3
$ if rtdir .eqs. "" then rtdir = f$parse("[.RUNTIME]",,,"DEVICE") + f$parse("[.RUNTIME]",,,"DIRECTORY")
$ if f$search(image) .eqs. "" .or. f$search(xximage) .eqs. ""
$ then
$   write sys$error "SMOKE: no image ''image' or ''xximage'"
$   exit 44
$ endif
$ vim :== $'image'
$ xxd :== $'xximage'
$ pass == 0
$ fail == 0
$ skip == 0
$ if f$search("SMOKE_TMP.DIR") .eqs. "" then create/directory [.SMOKE_TMP]
$ set default [.SMOKE_TMP]
$ call emptydir
$! Vim and xxd need TMP for filters (DECISIONS D7).
$ define/nolog tmp sys$scratch
$! -u NONE -i NONE: no vimrc, no viminfo; -n: no swap file.
$ vq = "vim -es -u NONE -i NONE -n"
$!
$! --- version ----------------------------------------------------------
$ define/user sys$output ver.txt
$ define/user sys$error nl:
$ vim "--version"
$ call firstline ver.txt
$ call check version "f$locate(""VIM - Vi IMproved 9.2"", line) .eq. 0"
$ call findline ver.txt "Included patches: 1-"
$ call check patches "found"
$!
$! --- edit a variable-length record file (DCL CREATE makes VAR) ----------
$ create ref.txt
the first line
line two, a little longer than the first
line three
$ 'vq' "+%s/two/TWO/" "+wq" ref.txt
$ st = $status
$ call check edit-status "st"
$ call check edit-newversion "f$search(""ref.txt;2"") .nes. """""
$ call check edit-oldversion "f$search(""ref.txt;1"") .nes. """""
$ call readall ref.txt;0
$ call check edit-content "got .eqs. ""the first line|line TWO, a little longer than the first|line three"""
$ rfm = f$file_attributes("ref.txt;0", "RFM")
$ write sys$output "INFO edit-var: new version is ''rfm' (old ''f$file_attributes("ref.txt;1","RFM")')"
$!
$! --- a STREAM_LF file --------------------------------------------------
$ create/fdl=sys$input slf.txt
RECORD
        FORMAT          STREAM_LF
$ open/append f slf.txt
$ write f "alpha"
$ write f "beta"
$ close f
$ 'vq' "+$put ='gamma'" "+wq" slf.txt
$ call readall slf.txt;0
$ call check stream-lf "got .eqs. ""alpha|beta|gamma"""
$ rfm = f$file_attributes("slf.txt;0", "RFM")
$ call check stream-lf-format "rfm .eqs. ""STMLF"""
$!
$! --- a VFC file (print carriage control, like a batch log) --------------
$ create/fdl=sys$input vfc.fdl
RECORD
        CARRIAGE_CONTROL        PRINT
        FORMAT                  VFC
        CONTROL_FIELD_SIZE      2
$ convert/fdl=vfc.fdl ref.txt;1 vfc.txt
$ 'vq' "+1d" "+wq" vfc.txt
$ call readall vfc.txt;0
$ call check vfc "got .eqs. ""line two, a little longer than the first|line three"""
$ rfm = f$file_attributes("vfc.txt;0", "RFM")
$ write sys$output "INFO vfc: new version is ''rfm'"
$!
$! --- a new file, and VMS and Unix file names ----------------------------
$ 'vq' "+call setline(1, 'made by vim')" "+wq" []new.txt
$ call readall new.txt
$ call check new-vms-name "got .eqs. ""made by vim"""
$ 'vq' "+call setline(1, 'unix name')" "+wq" ./unix.txt
$ call readall unix.txt
$ call check new-unix-name "got .eqs. ""unix name"""
$!
$! --- an Ex script read from SYS$INPUT ----------------------------------
$ create script.vim
%s/first/1st/
wq
$ define/user sys$input script.vim
$ 'vq' ref.txt;1
$ call readall ref.txt;0
$ call check ex-stdin "f$locate(""the 1st line"", got) .eq. 0"
$!
$! --- :cq sets an error status ------------------------------------------
$ define/user sys$output nl:
$ define/user sys$error nl:
$ 'vq' "+cq" ref.txt
$ st = $status
$ call check cq-status ".not. st"
$!
$! --- functions and Vim9 script ----------------------------------------
$ 'vq' "+call writefile([string(map(range(1, 5), {_, v -> v * v}))], 'fn.txt')" "+qa!"
$ call readall fn.txt
$ call check function "got .eqs. ""[1, 4, 9, 16, 25]"""
$ create v9.vim
vim9script
def Twice(s: string): string
  return s .. s
enddef
writefile([Twice('ab')], 'v9.txt')
qa!
$! (v9.vim is a VAR file, as DCL CREATE and EDIT make: patch 0004.)
$ 'vq' "+source v9.vim"
$ call readall v9.txt
$ call check vim9script "got .eqs. ""abab"""
$ 'vq' "+call writefile([string(readfile('ref.txt;1'))], 'rf.txt')" "+qa!"
$ call readall rf.txt
$ call check readfile-var "got .eqs. ""['the first line', 'line two, a little longer than the first', 'line three']"""
$ 'vq' "+call writefile([string(systemlist('write sys$output ""one""')), string(v:shell_error)], 'sys.txt')" "+qa!"
$ call readall sys.txt
$ call check systemlist "got .eqs. ""['one']|0"""
$!
$! --- $VIM is never the symbol VIM (the command itself): patch 0007 --------
$ if f$trnlnm("VIM") .eqs. ""
$ then
$   'vq' "+call writefile([$VIM], 'env.txt')" "+qa!"
$   call readall env.txt
$   call check env-no-symbol "f$locate(""VIM.EXE"", f$edit(got, ""UPCASE"")) .eq. f$length(got)"
$ else
$   write sys$output "SKIP env-no-symbol: the logical name VIM is defined"
$   skip == skip + 1
$ endif
$!
$! --- a vimrc that is a VAR file (as EDIT makes), with -u ----------------
$ create rc.vim
set shiftwidth=3
let g:rc_loaded = 'yes'
$ vim -es -u rc.vim -i NONE -n "+call writefile([&shiftwidth, g:rc_loaded], 'rc.txt')" "+qa!"
$ call readall rc.txt
$ call check vimrc-var "got .eqs. ""3|yes"""
$!
$! --- the runtime: VIMRUNTIME, syntax, filetype, help ---------------------
$ if f$search("''rtdir'DEFAULTS.VIM") .eqs. ""
$ then
$   write sys$output "SKIP runtime: no ''rtdir'DEFAULTS.VIM (push.sh <node> runtime)"
$   skip == skip + 5
$   goto runtime_done
$ endif
$ define/nolog vimruntime 'rtdir'
$ create hello.c
#include <stdio.h>
int main(void) { return 0; }
$ 'vq' "+filetype on" "+filetype detect" "+syntax on" "+call writefile([&filetype, get(b:, 'current_syntax', """")], 'syn.txt')" "+qa!" hello.c
$ call readall syn.txt
$ call check filetype-syntax "got .eqs. ""c|c"""
$ 'vq' "+filetype on" "+filetype detect" "+call writefile([&filetype], 'ftc.txt')" "+qa!" [-.VMS]BUILD.COM
$ call readall ftc.txt
$ call check filetype-dcl "got .eqs. ""dcl"""
$ 'vq' "+help os_vms" "+call writefile([expand('%:t'), getline('.')], 'help.txt')" "+qa!"
$ call readall help.txt
$ call check help "f$locate(""os_vms.txt|*os_vms.txt*"", got) .eq. 0"
$! vimtutor: tutor.vim copies the lesson to $TUTORCOPY (a logical name here).
$ define/user tutorcopy tut.txt
$ 'vq' "+source $VIMRUNTIME/tutor/tutor.vim"
$ call findline tut.txt "V I M   T u t o r"
$ call check vimtutor "found"
$ 'vq' "+helptags ALL" "+qa!"
$ st = $status
$ call check helptags "st"
$ deassign vimruntime
$runtime_done:
$!
$! --- xxd: a round trip of a binary file --------------------------------
$ xxd -l 4096 -p 'image' a.hex
$ xxd -r -p a.hex b.bin
$ xxd -p b.bin b.hex
$ define/user sys$output nl:
$ define/user sys$error nl:
$ differences/mode=ascii a.hex b.hex
$ sev = $severity
$ call check xxd-roundtrip "sev .eq. 1"
$ call firstline a.hex
$ call check xxd-dump "f$length(line) .eq. 60"
$! :%!xxd from inside Vim needs TMP and a subprocess.
$ 'vq' "+%!xxd" "+w! filt.txt" "+qa!" hello.c
$ call firstline filt.txt
$ call check vim-filter "f$locate(""00000000: 2369 6e63"", line) .eq. 0"
$!
$finish:
$ set default 'vmsdir'
$ set default [-]
$ set process/parse_style='saved_parse'
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed, ''skip' skipped (''image')"
$ set default 'saved_default'
$ if f$type(vim) .nes. "" then delete/symbol/global vim
$ if f$type(xxd) .nes. "" then delete/symbol/global xxd
$ if f$trnlnm("tmp", "LNM$PROCESS") .nes. "" then deassign tmp
$ if f$trnlnm("vimruntime", "LNM$PROCESS") .nes. "" then deassign vimruntime
$ if fail .eq. 0 .and. pass .gt. 0 then exit 1
$ exit 44
$!
$! --- READALL file: the lines of a file, joined with "|", into GOT -------
$readall: subroutine
$ got == ""
$ if f$search(p1) .eqs. "" then exit 1
$ open/read rf 'p1'
$ra_loop:
$ read/end=ra_done rf line
$ if got .nes. "" then got == got + "|"
$ got == got + line
$ if f$length(got) .gt. 400 then goto ra_done
$ goto ra_loop
$ra_done:
$ close rf
$ exit 1
$ endsubroutine
$!
$! --- FIRSTLINE file: its first line into LINE ----------------------------
$firstline: subroutine
$ line == ""
$ if f$search(p1) .eqs. "" then exit 1
$ open/read rf 'p1'
$ read/end=fl_done rf l
$ line == l
$fl_done:
$ close rf
$ exit 1
$ endsubroutine
$!
$! --- FINDLINE file text: FOUND is true if a line contains text -----------
$findline: subroutine
$ found == 0
$ if f$search(p1) .eqs. "" then exit 1
$ open/read rf 'p1'
$fd_loop:
$ read/end=fd_done rf l
$ if f$locate(p2, l) .lt. f$length(l) then found == 1
$ goto fd_loop
$fd_done:
$ close rf
$ exit 1
$ endsubroutine
$!
$! --- CHECK name dcl-expression ----------------------------------------
$check: subroutine
$ if 'p2'
$ then
$   write sys$output "PASS ", p1
$   pass == pass + 1
$ else
$   write sys$output "FAIL ", p1, ": ", p2
$   if f$type(got) .nes. "" then write sys$output "     got [", got, "]"
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
$!
$! --- EMPTYDIR: delete everything under the current directory -------------
$emptydir: subroutine
$ set noon
$ if f$search("[...]*.*;*") .eqs. "" then exit 1
$ define/user sys$output nl:
$ define/user sys$error nl:
$ set protection=(s:rwed,o:rwed) [...]*.*;*
$ n = 0
$emptyloop:
$ define/user sys$output nl:
$ define/user sys$error nl:
$ delete/nolog [...]*.*;*
$ n = n + 1
$ if f$search("[...]*.*;*") .nes. "" .and. n .lt. 6 then goto emptyloop
$ exit 1
$ endsubroutine
