# Decisions

Proposed 2026-10-26; awaiting the user's sign-off.

## D1. Source: upstream's signed tags, upstream's VMS build

Build from a tag of github.com/vim/vim, verified against Christian Brabandt's key
(4F19 7088 1691 8E19 AAE1 9DEE F3F9 2DA3 83FD DE09) and pinned to its commit id. Build with
upstream's src/Make_vms.mms and os_vms_conf.h, not a build of our own: they are maintained,
and staying close to them keeps our patch list short. Changes go in patches/, written so
they can be sent upstream.

## D2. Which upstream versions

Vim tags a patch release almost daily (9.2.0001 ... 9.2.1240). Proposed: build the latest
tag when we start (9.2.1240), then move up for each new minor release (9.3) and otherwise
when there is a reason (a security fix, a VMS fix upstream, or every few months). Tags
are v<upstream>-vms<N>, as for the other ports: v9.2.1240-vms1.

## D3. Terminal first; GUI later, as a second image

The first kit has the terminal Vim (HUGE features). A Motif GVIM.EXE (DECwindows) can follow
in Phase 3 as a second image in the same kit, installed only where DECwindows is present.
Language interfaces (Perl, Python, Lua...) stay off.

## D4. Product and version

PCSI product ISSINOHO <I64VMS|X86VMS> VIM, version V9.2-<patch>E<level>: V9.2-1240E1 for
9.2.1240-vms1 (PCSI accepts it, N1). Kit: ISSINOHO-X86VMS-VIM-V0902-1240E1-1.PCSI.

## D5. Install layout

PCSI$DESTINATION:[VIM] with the concealed rooted logical VIM$ROOT, as LESS$ROOT:

    VIM$ROOT:[BIN]      VIM.EXE, XXD.EXE
    VIM$ROOT:[VIM92]    the runtime tree (doc, syntax, ftplugin, ...)
    VIM$ROOT:[000000]   VIM$SETUP.COM, vimrc (site-wide settings, empty by default)
    VIM$ROOT:[DOC]      README.VMS, LICENSE

VIM$STARTUP.COM (SYS$STARTUP) defines VIM$ROOT, and VIM and VIMRUNTIME as upstream
expects (VIM = VIM$ROOT:[000000], VIMRUNTIME = VIM$ROOT:[VIM92]), in the system table.

## D6. Commands

VIM$SETUP.COM defines `vim`, `vi`, `view` (vim -R), `vimdiff` (vim -d), `vimtutor` and
`xxd` as foreign commands. It does not touch EDIT or the TPU symbols.

## D7. TMP

Vim needs a TMP logical for xxd filtering, printing and some functions. VIM$SETUP.COM
defines TMP as SYS$SCRATCH in the process table when TMP is not already defined.
