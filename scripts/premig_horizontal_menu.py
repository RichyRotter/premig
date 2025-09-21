#!/usr/bin/env python3
# Multiline horizontal menu (manual line breaks only, no auto-wrap, no full clear)
# - Items: CSV, optional [h]otkey like [n]ew
# - Force line breaks with token: //
# - Arrows: LEFT/RIGHT across items, UP/DOWN between your manual rows
# - Hotkey selects immediately (now with highlight before return)
# - Hint printed below
# - Selected = bold green on blue background

import sys, os, re, tty, termios, fcntl

CSI = "\x1b["

# ---------- parsing ----------
def parse_tokens(csv: str):
    rx = re.compile(r'^\[(.)\](.*)$')
    raw = [s for s in csv.split(',')]
    tokens, labels, clean, hot = [], [], [], []
    for s in raw:
        t = s.strip()
        if t == "":
            continue
        if t == "//":
            tokens.append(("BR", None))
            continue
        m = rx.match(t)
        if m:
            k, rest = m.group(1), m.group(2)
            labels.append(f'[{k}]{rest}')
            clean.append(rest)
            hot.append(k.lower())
        else:
            labels.append(t)
            clean.append(t)
            hot.append(t[:1].lower() if t else '')
        tokens.append(("IT", len(labels)-1))
    return tokens, labels, clean, hot

# ---------- colors ----------
def color(s, *, fg=None, bg=None, bold=False):
    parts = []
    if bold: parts.append("1")
    if fg is not None: parts.append(str(fg))
    if bg is not None: parts.append(str(bg))
    return s if not parts else f"\x1b[{';'.join(parts)}m{s}\x1b[0m"

FG_WHITE = 37
FG_GREEN = 32
BG_BLACK = 40
BG_SELECT = 44   # blue background

# ---------- raw mode ----------
def enable_raw(fd):
    old = termios.tcgetattr(fd)
    tty.setraw(fd)
    return old

def restore(fd, old):
    termios.tcsetattr(fd, termios.TCSADRAIN, old)

# ---------- input ----------
def read_key(IN):
    ch = IN.read(1)
    if ch == b'\x1b':
        fd = IN.fileno()
        fl_old = fcntl.fcntl(fd, fcntl.F_GETFL)
        try:
            fcntl.fcntl(fd, fcntl.F_SETFL, fl_old | os.O_NONBLOCK)
            tail = IN.read(2) or b""
        finally:
            fcntl.fcntl(fd, fcntl.F_SETFL, fl_old)
        if tail.startswith(b'[') and len(tail) >= 2:
            c = tail[1:2]
            if   c == b'C': return 'RIGHT'
            elif c == b'D': return 'LEFT'
            elif c == b'A': return 'UP'
            elif c == b'B': return 'DOWN'
        return 'ESC'
    if ch in (b'\r', b'\n'): return 'ENTER'
    if ch in (b'\x03',):     return 'CTRL_C'
    try:
        return ch.decode(errors='ignore')
    except:
        return ''

# ---------- layout (manual rows only) ----------
def build_rows_manual(tokens):
    rows, cur = [], []
    for kind, idx in tokens:
        if kind == "BR":
            rows.append(cur); cur=[]
        else:
            cur.append(idx)
    rows.append(cur)
    return rows

def render_item(label, selected):
    m = re.match(r'^\[(.)\](.*)$', label)
    if selected:
        if m:
            k, rest = m.group(1), m.group(2)
            return "".join([
                color(" ", fg=FG_GREEN, bg=BG_SELECT, bold=True),
                color("[", fg=FG_GREEN, bg=BG_SELECT, bold=True),
                color(k,  fg=FG_GREEN, bg=BG_SELECT, bold=True),
                color("]", fg=FG_GREEN, bg=BG_SELECT, bold=True),
                color(rest, fg=FG_GREEN, bg=BG_SELECT, bold=True),
                color(" ", fg=FG_GREEN, bg=BG_SELECT, bold=True),
            ])
        return color(f" {label} ", fg=FG_GREEN, bg=BG_SELECT, bold=True)
    else:
        if m:
            k, rest = m.group(1), m.group(2)
            return "".join([
                color(" ", fg=FG_WHITE, bg=None, bold=False),
                color("[", fg=FG_WHITE),
                color(k,  fg=FG_GREEN, bold=True),
                color("]", fg=FG_WHITE),
                color(rest, fg=FG_WHITE),
                color(" ", fg=FG_WHITE),
            ])
        return color(f" {label} ", fg=FG_WHITE)

def draw(OUT, rows, labels, lin_idx, order, hint):
    prev = getattr(draw, "_lines", 0)
    if prev > 0:
        OUT.write((CSI + f"{prev}F").encode())

    sel_lab_idx = order[lin_idx] if order else None
    lines = 0
    for r in rows:
        OUT.write(("\r" + CSI + "2K").encode())
        parts = []
        for lab_idx in r:
            parts.append(render_item(labels[lab_idx], selected=(lab_idx == sel_lab_idx)))
        line = " ".join(parts)  # NO cropping; no auto-wrap
        OUT.write((line + "\n").encode())
        lines += 1

    OUT.write((CSI + "2K").encode())
    OUT.write(("\r" + " \n").encode())
    #OUT.write(("\r" + "Use ← → / ↑ ↓ or hotkey [x]; Enter=select; q/ESC=quit\n").encode())
    lines += 1

    OUT.flush()
    draw._lines = lines

def find_row_pos(rows, lab_idx):
    for ri, r in enumerate(rows):
        for ci, v in enumerate(r):
            if v == lab_idx:
                return ri, ci
    return 0, 0

def vertical_move(rows, order, idx, up):
    if not order: return idx
    cur_lab = order[idx]
    r, c = find_row_pos(rows, cur_lab)
    if up and r == 0: return idx
    if (not up) and r == len(rows)-1: return idx
    target_row = rows[r-1] if up else rows[r+1]
    c = min(c, len(target_row)-1)
    target_lab = target_row[c]
    for li, lab in enumerate(order):
        if lab == target_lab:
            return li
    return idx

# ---------- main ----------
def run(csv: str):
    try:
        TTY = open("/dev/tty", "r+b", buffering=0)
    except OSError:
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            return None
        TTY = None
    INb  = TTY if TTY else sys.stdin.buffer
    OUTb = TTY if TTY else sys.stdout.buffer

    tokens, labels, clean, hotkeys = parse_tokens(csv)
    if not labels:
        return None

    # Manual rows (only //)
    rows = build_rows_manual(tokens)
    # linear order = just all label indices in appearance order
    order = [idx for t, idx in tokens if t == "IT"]

    idx = 0
    draw(OUTb, rows, labels, idx, order, "hint")

    fd = INb.fileno()
    old = enable_raw(fd)
    try:
        while True:
            k = read_key(INb)
            if k in ('CTRL_C', 'ESC', 'q', 'Q'):
                return None
            if k == 'ENTER':
                return clean[order[idx]]
            if k == 'RIGHT':
                if order: idx = (idx + 1) % len(order)
                draw(OUTb, rows, labels, idx, order, "hint"); continue
            if k == 'LEFT':
                if order: idx = (idx - 1) % len(order)
                draw(OUTb, rows, labels, idx, order, "hint"); continue
            if k == 'UP':
                idx = vertical_move(rows, order, idx, up=True)
                draw(OUTb, rows, labels, idx, order, "hint"); continue
            if k == 'DOWN':
                idx = vertical_move(rows, order, idx, up=False)
                draw(OUTb, rows, labels, idx, order, "hint"); continue

            if isinstance(k, str) and k and k.isprintable():
                l = k.lower()
                # exact hotkey -> select (highlight before return)
                for i, hk in enumerate(hotkeys):
                    if hk == l and hk:
                        for li, lab in enumerate(order):
                            if lab == i:
                                idx = li
                                draw(OUTb, rows, labels, idx, order, "hint")
                                break
                        return clean[i]
                # prefix jump by clean text
                for i, txt in enumerate(clean):
                    if txt.lower().startswith(l) and txt:
                        for li, lab in enumerate(order):
                            if lab == i:
                                idx = li
                                draw(OUTb, rows, labels, idx, order, "hint")
                                break
                        break
    finally:
        restore(fd, old)
        try:
            OUTb.write(b"\n"); OUTb.flush()
        except Exception:
            pass
        if TTY: TTY.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print('usage: premig_horizontal_menu.py "[1]RunCpt,[2]RunTest,//,[3]More..."', file=sys.stderr)
        sys.exit(2)
    res = run(sys.argv[1])
    if res is not None:
        print(res)
        sys.exit(0)
    sys.exit(1)
