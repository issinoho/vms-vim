#!/usr/bin/env python3
"""ttytest.py <node> - drive VIM.EXE interactively on <node> and check the screen.

TEST_SMOKE.COM runs Vim in silent Ex mode; this tests the editor on a terminal.
It logs in to the node over ssh in a pseudo-terminal (80x24, a VT500 to VMS),
runs the built VIM.EXE, sends keys, and checks what a VT emulator (pyte) shows
after each.  The test file is made on the node with DCL, so it is a
variable-length record file, the common case on VMS.

Needs pexpect and pyte on the host (python3 -m pip install pexpect pyte, or
set TTYTEST_PYTHON to a virtualenv's python; tools/ttytest.sh does that).
Output: out/tty-<node>.log; exit status 0 only if every check passes.
"""
import os
import re
import sys
import time

import pexpect
import pyte

TOP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_conf(node):
    for line in open(os.path.join(TOP, 'tools', 'nodes.conf')):
        f = line.split()
        if f and not f[0].startswith('#') and f[0] == node:
            return f
    sys.exit('ttytest: unknown node %s' % node)


def upstream():
    conf = {}
    for line in open(os.path.join(TOP, 'upstream.conf')):
        m = re.match(r'(\w+)=(.*)', line.strip())
        if m:
            conf[m.group(1)] = m.group(2)
    return conf


class Session:
    def __init__(self, node):
        _, arch, host, port, user, workdir, _ = read_conf(node)
        self.prompt = None
        self.screen = pyte.Screen(80, 24)
        self.stream = pyte.ByteStream(self.screen)
        self.child = pexpect.spawn(
            'ssh', ['-tt', '-p', port, '-i',
                    os.path.expanduser(os.environ.get('VMS_SSH_KEY', '~/.ssh/vms_ed25519')),
                    '-o', 'BatchMode=yes', '%s@%s' % (user, host)],
            env=dict(os.environ, TERM='vt100'), dimensions=(24, 80), timeout=60)
        self.workdir = workdir
        self.arch = 'IA64' if arch == 'IA64' else 'X86_64'

    def pump(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            try:
                self.stream.feed(self.child.read_nonblocking(65536, timeout=0.2))
            except pexpect.TIMEOUT:
                pass
            except pexpect.EOF:
                return

    def send(self, text, seconds=1.5):
        self.child.send(text)
        self.pump(seconds)

    def dcl(self, command, seconds=1.0):
        self.send(command + '\r', seconds)

    def row(self, n):
        return self.screen.display[n].rstrip()

    def dump(self):
        return '\n'.join('%2d|%s' % (i, l.rstrip()) for i, l in enumerate(self.screen.display))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    node = sys.argv[1]
    up = upstream()
    tree = (up['UPSTREAM_NAME'] + '-' + up['UPSTREAM_VERSION']).replace('.', '_').upper()
    os.makedirs(os.path.join(TOP, 'out'), exist_ok=True)
    log = open(os.path.join(TOP, 'out', 'tty-%s.log' % node), 'w')
    results = []

    def check(name, ok, s):
        results.append(ok)
        line = '%s %s' % ('PASS' if ok else 'FAIL', name)
        print(line, flush=True)
        log.write(line + '\n')
        if not ok:
            log.write(s.dump() + '\n')
        log.flush()

    def screen(s):
        return '\n'.join(s.screen.display)

    def cursor_line(s):
        return s.row(s.screen.cursor.y)

    s = Session(node)
    s.child.expect([r'::', r'\$ ', pexpect.TIMEOUT], timeout=60)
    s.pump(2)
    s.dcl('set default %s' % s.workdir)
    s.dcl('set terminal/page=24/width=80')
    s.dcl('vim :== $\'f$parse("[.%s.SRC.%s]VIM.EXE")\'' % (tree, s.arch))
    s.dcl('define/nolog vimruntime \'f$parse("[.%s.RUNTIME]") - ".;"\'' % tree)
    s.dcl('define/nolog tmp sys$scratch')
    # 200 numbered lines, a variable-length record file.
    # (Interactive DCL has no GOTO: the loop is a procedure.)
    s.dcl('create ttymk.com')
    for line in ('$ open/write tt ttytest.txt', '$ i = 1',
                 '$ loop: write tt f$fao("line !3ZL", i)', '$ i = i + 1',
                 '$ if i .le. 200 then goto loop', '$ close tt'):
        s.send(line + '\r', 0.3)
    s.send('\x1a', 1)
    s.dcl('@ttymk', 3)
    s.dcl('delete/nolog ttymk.com;*')
    s.screen.reset()

    # -u NONE -N: no vimrc, not vi-compatible; -i NONE: no viminfo; -n: no swap file.
    s.dcl('vim -u NONE -N -i NONE -n ttytest.txt', 4)
    check('open', s.row(0) == 'line 001' and s.row(22) == 'line 023'
          and '"ttytest.txt"' in s.row(23) and '200' in s.row(23), s)
    s.send('\x06')
    check('ctrl-f', s.row(0) == 'line 022', s)
    s.send('G')
    check('end', s.row(22) == 'line 200' and cursor_line(s) == 'line 200', s)
    s.send('gg')
    check('start', s.row(0) == 'line 001' and s.screen.cursor.y == 0, s)
    s.send('/line 150\r')
    check('search', cursor_line(s) == 'line 150', s)
    # A VT terminal in normal cursor mode sends CSI; Vim's vt320 entry (TERM is
    # vt500-80 and the like) does not switch the cursor keys to SS3.
    s.send('\x1b[B')
    check('arrow-down', cursor_line(s) == 'line 151', s)
    s.send('\x1b[A')
    check('arrow-up', cursor_line(s) == 'line 150', s)
    s.send('ccHELLO\x7f\x7fP!\x1b')
    check('insert-del', cursor_line(s) == 'HELP!', s)
    s.send('u')
    check('undo', cursor_line(s) == 'line 150', s)
    s.send('\x12')
    check('redo', cursor_line(s) == 'HELP!', s)
    s.send(':!show time\r', 4)
    text = screen(s)
    check('shell-cmd', re.search(r'\d{2}:\d{2}:\d{2}', text) is not None
          and 'Press ENTER' in text, s)
    s.send('\r')
    check('shell-return', cursor_line(s) == 'HELP!', s)
    # CTRL/C interrupts a long command and leaves Vim running.
    s.send(':sleep 30\r', 1)
    s.send('\x03', 2)
    s.send(':echo "back"\r')
    check('ctrl-c', s.row(23).startswith('back'), s)
    # The runtime: help and syntax highlighting (VIMRUNTIME).
    s.send(':help\r', 3)
    check('help', 'help.txt' in screen(s) and 'VIM - main help file' in screen(s), s)
    s.send(':q\r')
    s.send(':syntax on\r:set filetype=c\r:call setline(1, "int x; /* c */")\r', 2)
    attrs = [s.screen.buffer[0][x] for x in range(14)]
    check('syntax', any(c.fg != 'default' for c in attrs), s)
    s.send('u:syntax off\r')
    # :w writes a new version; :q leaves with a success status.
    s.send(':w\r', 2)
    check('write', 'written' in s.row(23), s)
    s.send(':q\r', 2)
    s.screen.reset()
    # Vim's exit status is %X00030001 (success, with a facility code):
    # what DCL tests is the severity.
    s.dcl('show symbol $severity')
    check('status', '$SEVERITY == "1"' in screen(s), s)
    s.screen.reset()
    s.dcl('directory/notrailing/noheading ttytest.txt;*', 2)
    check('new-version', ';2' in screen(s) and ';1' in screen(s), s)
    s.screen.reset()
    s.dcl('search ttytest.txt;0 "HELP!"', 2)
    check('written-content', 'HELP!' in screen(s), s)

    # The screen size is the terminal's (SET TERMINAL), not a fixed 24x80.
    s.dcl('set terminal/page=12/width=80')
    s.screen.reset()
    s.dcl('vim -u NONE -N -i NONE -n ttytest.txt;1', 4)
    rows = [s.row(i) for i in range(24)]
    k = rows.index('line 001') if 'line 001' in rows else -99
    check('page-size', k >= 0 and rows[k + 10] == 'line 011'
          and '"ttytest.txt' in rows[k + 11] and 'line 012' not in rows, s)
    s.send(':q\r', 2)
    s.dcl('set terminal/page=24/width=80')
    s.dcl('delete/nolog ttytest.txt;*')
    s.dcl('delete/symbol/global vim')
    s.dcl('deassign vimruntime')
    s.dcl('deassign tmp')
    s.dcl('logout', 2)

    passed = sum(results)
    summary = 'TTYTEST: %d passed, %d failed (%s)' % (passed, len(results) - passed, node)
    print(summary)
    log.write(summary + '\n')
    sys.exit(0 if passed == len(results) else 1)


if __name__ == '__main__':
    main()
