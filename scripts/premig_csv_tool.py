#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# CSV Viewer/Picker – TTY-basiert (kein curses)
# Features: Multi-/Single-Select, Farben, Navigation, /dev/tty Nutzung

import sys
import os
import csv
import tty
import termios
import fcntl
import re
# Selektions-Indikator nur für ausgewählte Zeilen
SELECT_INDICATOR = "> "

CSI = "\x1b["

COLOR_NAMES = {
    "default": None,
    "black": 0, "red": 1, "green": 2, "yellow": 3,
    "blue": 4, "magenta": 5, "cyan": 6, "white": 7,
}

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')

def to_int(s, d=0):
    try:
        return int(str(s).strip())
    except Exception:
        return d

def parse_args(argv):
    selection = "single"
    joiner = ","
    header_on = True
    header_fg = "white"
    header_bg = "default"
    result_file = None
    read_only_flag = None
    start_at_page_flag = None

    rest = []
    args_iter = iter(argv[1:])
    for a in args_iter:
        if a == "--":
            rest.extend(list(args_iter))
            break
        if a.startswith("--selection="):     selection = a.split("=",1)[1].strip().lower()
        elif a.startswith("--join="):        joiner = a.split("=",1)[1]
        elif a.startswith("--header="):      header_on = a.split("=",1)[1].strip().lower() not in ("off","0","no","false")
        elif a.startswith("--header-fg="):   header_fg = a.split("=",1)[1].strip().lower()
        elif a.startswith("--header-bg="):   header_bg = a.split("=",1)[1].strip().lower()
        elif a.startswith("--result-file="): result_file = a.split("=",1)[1]
        elif a.startswith("--read-only="):   read_only_flag = a.split("=",1)[1].strip().upper() in ("Y","YES","1","TRUE")
        elif a.startswith("--start-at-page="): start_at_page_flag = to_int(a.split("=",1)[1].strip(), 1)
        else:
            rest.append(a)

    if not (10 <= len(rest) <= 16):
        sys.stderr.write(
            f"usage: {os.path.basename(argv[0])} "
            "[--selection=single|multiple] [--join=,] "
            "[--header=on|off] [--header-fg=color] [--header-bg=color] "
            "[--result-file=/path/to/file] [--read-only=Y|N] [--start-at-page=N] "
            "<file> <delim> <headers_csv> <sourcecols_csv> <widths_csv> "
            "<hotkey_col> <x> <y> <return_col> <rows_per_page> "
            "[normal_fg] [normal_bg] [selected_fg] [selected_bg] "
            "[cursor_fg] [cursor_bg]\n"
        )
        sys.exit(2)

    (fpath, delim, headers_csv, sourcecols_csv, widths_csv,
     hotkey_col, xpos, ypos, ret_col, rows_per_page, *opt) = rest

    headers = [s.strip() for s in headers_csv.split(",") if s.strip()]
    sourcecols = [to_int(s, 1) for s in sourcecols_csv.split(",") if str(s).strip()]
    widths = [to_int(s, 0) for s in widths_csv.split(",") if str(s).strip()]
    if len(headers) != len(sourcecols) or len(sourcecols) != len(widths):
        sys.stderr.write("Error: headers, sourcecols, widths must have same length.\n")
        sys.exit(2)

    nfg = (opt[0].strip().lower() if len(opt)>=1 else "white")
    nbg = (opt[1].strip().lower() if len(opt)>=2 else "default")
    sfg = (opt[2].strip().lower() if len(opt)>=3 else "black")
    sbg = (opt[3].strip().lower() if len(opt)>=4 else "cyan")
    cfg_cursor_fg = (opt[4].strip().lower() if len(opt)>=5 else "black")
    cfg_cursor_bg = (opt[5].strip().lower() if len(opt)>=6 else "yellow")

    read_only = bool(read_only_flag) if read_only_flag is not None else False
    start_at_page = start_at_page_flag if (start_at_page_flag and start_at_page_flag > 0) else 1
    selection = "multiple" if selection in ("multiple", "multi") else "single"
    marker_w = 0 if read_only else (4 if selection == "multiple" else 0)

    cfg = {
        "file": fpath,
        "delim": delim,
        "headers": headers,
        "sourcecols": sourcecols,
        "widths": widths,
        "hotkey_col": (max(1, to_int(hotkey_col)) - 1) if (to_int(hotkey_col) > 0 and not read_only) else -1,
        "x": to_int(xpos),
        "y": to_int(ypos),
        "ret_col": max(1, to_int(ret_col)) - 1,
        "rows_per_page": max(1, to_int(rows_per_page)),
        "normal_fg": nfg, "normal_bg": nbg,
        "sel_fg": sfg,   "sel_bg": sbg,
        "cursor_fg": cfg_cursor_fg, "cursor_bg": cfg_cursor_bg,
        "selection": "single" if read_only else selection,
        "joiner": joiner,
        "header_on": header_on,
        "header_fg": header_fg, "header_bg": header_bg,
        "result_file": result_file,
        "readonly": read_only,
        "start_at_page": start_at_page,
        "marker_w": marker_w,
    }

        # Linke Indikator-Spalte (fixe Breite in Zeichen)
    cfg["cursor_w"] = 2
    return cfg
def read_csv_rows(path, delim):
    rows = []
    with open(path, newline='', encoding="utf-8") as f:
        rdr = csv.reader(f, delimiter=delim)
        for r in rdr:
            if not r or all((c.strip()=="" for c in r)):
                continue
            rows.append([c.strip() for c in r])
    return rows

def color_seq(fg_name=None, bg_name=None, bold=False):
    parts=[]
    if bold:
        parts.append("1")
    if fg_name in COLOR_NAMES and COLOR_NAMES[fg_name] is not None:
        parts.append(str(30 + COLOR_NAMES[fg_name]))
    if bg_name in COLOR_NAMES and COLOR_NAMES[bg_name] is not None:
        parts.append(str(40 + COLOR_NAMES[bg_name]))
    return f"\x1b[{';'.join(parts)}m" if parts else ""

def pad(s, w):
    return (s or "")[:w].ljust(w)

def clip_ansi(s, width):
    out=[]; vis=0; i=0
    while i < len(s) and vis < width:
        if s[i] == '\x1b':
            m = ANSI_RE.match(s, i)
            if m:
                out.append(m.group(0))
                i = m.end()
                continue
        ch = s[i]
        out.append(ch)
        if ch not in '\r\n':
            vis += 1
        i += 1
    out.append("\x1b[0m")
    return "".join(out)

def tty_raw(fd):
    old = termios.tcgetattr(fd)
    tty.setraw(fd)
    return old

def tty_restore(fd, old):
    termios.tcsetattr(fd, termios.TCSADRAIN, old)

def gotoxy(out, x, y):
    out.write(f"{CSI}{y+1};{x+1}H")

def clear_line(out):
    out.write(f"{CSI}2K")

def draw_text(out, x, y, s, width=None):
    gotoxy(out, x, y)
    clear_line(out)
    out.write(clip_ansi(s, width) if width is not None else s)
    out.flush()

def read_key(IN):
    ch = IN.read(1)
    if not ch:
        return ''
    if ch == b'\x1b':
        fd = IN.fileno()
        fl = fcntl.fcntl(fd, fcntl.F_GETFL)
        try:
            fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
            tail = IN.read(3) or b""
        finally:
            fcntl.fcntl(fd, fcntl.F_SETFL, fl)
        if tail.startswith(b'['):
            t = tail[1:2]
            if t == b'A': return 'UP'
            if t == b'B': return 'DOWN'
            if t == b'C': return 'RIGHT'
            if t == b'D': return 'LEFT'
            if tail.startswith(b'[5'): return 'PGUP'
            if tail.startswith(b'[6'): return 'PGDN'
            if tail.startswith(b'[H'): return 'HOME'
            if tail.startswith(b'[F'): return 'END'
        return 'ESC'
    if ch in (b'\r', b'\n'):
        return 'ENTER'
    if ch == b'\x03':
        return 'CTRL_C'
    try:
        return ch.decode(errors='ignore')
    except Exception:
        return ''

def main():
    cfg = parse_args(sys.argv)
    rows = read_csv_rows(cfg["file"], cfg["delim"])
    if not rows:
        sys.stderr.write("No rows.\n")
        sys.exit(1)

    try:
        TTY = open("/dev/tty", "r+b", buffering=0)
    except OSError:
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            sys.stderr.write("No TTY.\n")
            sys.exit(1)
        TTY = None
    IN = TTY if TTY else sys.stdin.buffer
    OUTb = TTY if TTY else sys.stdout.buffer
    OUT = os.fdopen(OUTb.fileno(), "w", buffering=1)

    def fmt_row(r):
        parts=[]
        for sc, w in zip(cfg["sourcecols"], cfg["widths"]):
            idx = sc-1
            cell = r[idx] if 0 <= idx < len(r) else ""
            parts.append(pad(cell, w))
        return " ".join(parts)

    formatted = [fmt_row(r) for r in rows]

    norm = color_seq(cfg["normal_fg"], cfg["normal_bg"], bold=False)
    selc = color_seq(cfg["sel_fg"], cfg["sel_bg"], bold=False)
    curs = color_seq(cfg["cursor_fg"], cfg["cursor_bg"], bold=True)
    hdrc = color_seq(cfg["header_fg"], cfg["header_bg"], bold=True)
    reset = "\x1b[0m"

    page_h = cfg["rows_per_page"]
    x0 = cfg["x"]
    y0 = cfg["y"]
    region_w = cfg["cursor_w"] + cfg["marker_w"] + sum(cfg["widths"]) + (len(cfg["widths"]) - 1)

    def row_hotkey(r):
        c = cfg["hotkey_col"]
        if c >= 0 and c < len(r) and r[c]:
            return r[c][0].lower()
        return ""

    hotkeys = [row_hotkey(r) for r in rows]

    header_line = ""
    if cfg["header_on"]:
        hdr_cells = [pad(h, w) for h, w in zip(cfg["headers"], cfg["widths"])]
        header_line = " ".join(hdr_cells)

    help_line = (
        "                                        " if cfg["readonly"] else
        ("↑/↓ PgUp/PgDn Enter=OK  q/ESC=Cancel" if cfg["selection"] == "single"
         else "↑/↓ PgUp/PgDn SPACE=toggle a=all n=none Enter=done q/ESC")
    )

    total = len(rows)
    max_page = max(1, (total + page_h - 1) // page_h)
    page = min(max(cfg["start_at_page"], 1), max_page) - 1
    idx = min(total - 1, max(0, page * page_h))
    selected = set()

    OUT.write("\x1b[?7l")

    def ensure_visible():
        nonlocal page
        if idx < page * page_h or idx >= (page + 1) * page_h:
            page = idx // page_h

    def draw():
        y = y0
        if cfg["header_on"]:
            line = (" " * (cfg["cursor_w"] + cfg["marker_w"])) + hdrc + header_line + reset
            draw_text(OUT, x0, y, line, region_w)
            y += 1
        start = page * page_h
        end = min(total, start + page_h)
        for i in range(start, end):
            x = x0
        
            # Farbwahl (Cursor vs. selektiert vs. normal)
            if i == idx:
                color = curs
            elif i in selected:
                color = selc
            else:
                color = norm
        
            # (1) Indikator-Spalte links: NUR wenn die Zeile ausgewählt ist
            indi = SELECT_INDICATOR if (i in selected) else " " * cfg["cursor_w"]
            draw_text(OUT, x, y, color + indi + reset, region_w)
            x += cfg["cursor_w"]
        
            # (2) (Optional) Marker-Spalte für Mehrfachauswahl, falls vorhanden
            if cfg["marker_w"]:
                mark = "[x] " if i in selected else "[ ] "
                draw_text(OUT, x, y, color + mark + reset, region_w)
                x += cfg["marker_w"]
        
            # (3) Tabelleninhalt
            draw_text(OUT, x, y, color + formatted[i] + reset, region_w - (x - x0))
            y += 1

        while (y - y0 - (1 if cfg["header_on"] else 0)) < page_h:
            draw_text(OUT, x0, y, "", region_w)
            y += 1

        draw_text(OUT, x0, y0 + (1 if cfg["header_on"] else 0) + page_h, norm + help_line + reset, region_w)

    if cfg["readonly"]:
        old = tty_raw(IN.fileno())
        try:
            draw()
        finally:
            tty_restore(IN.fileno(), old)
            OUT.write("\x1b[?7h"); OUT.flush()
            if TTY: TTY.close()
        sys.exit(0)

    old = tty_raw(IN.fileno())
    try:
        draw()
        while True:
            k = read_key(IN)
            if k in ('CTRL_C', 'ESC', 'q', 'Q'):
                OUT.write("\x1b[?7h"); OUT.flush()
                sys.exit(1)
            if k == 'ENTER':
                if cfg["selection"] == "multiple":
                    selected_lines = []
                    for i in sorted(selected):
                        line = cfg["joiner"].join(rows[i])
                        selected_lines.append(line)
                    result = "\n".join(selected_lines)
                else:
                    r = rows[idx]
                    result = cfg["joiner"].join(r)

                if cfg["result_file"]:
                    with open(cfg["result_file"], "w", encoding="utf-8") as f:
                        f.write(result + "\n")
                else:
                    print(result)
                OUT.write("\x1b[?7h"); OUT.flush()
                sys.exit(0)

            if k == 'UP':
                if idx > 0:
                    idx -= 1
                    ensure_visible()
                    draw()
            elif k == 'DOWN':
                if idx < total - 1:
                    idx += 1
                    ensure_visible()
                    draw()
            elif k == 'PGUP':
                idx = max(0, idx - page_h)
                ensure_visible()
                draw()
            elif k == 'PGDN':
                idx = min(total - 1, idx + page_h)
                ensure_visible()
                draw()
            elif k == 'HOME':
                idx = 0
                ensure_visible()
                draw()
            elif k == 'END':
                idx = total - 1
                ensure_visible()
                draw()
            elif cfg["selection"] == "multiple":
                if k == ' ':
                    if idx in selected:
                        selected.remove(idx)
                    else:
                        selected.add(idx)
                    draw()
                elif k in ('a', 'A'):
                    selected = set(range(total))
                    draw()
                elif k in ('n', 'N'):
                    selected.clear()
                    draw()
                elif k.lower() in hotkeys:
                    i = hotkeys.index(k.lower())
                    if i in selected:
                        selected.remove(i)
                    else:
                        selected.add(i)
                    idx = i
                    ensure_visible()
                    draw()
    finally:
        tty_restore(IN.fileno(), old)
        OUT.write("\x1b[?7h")
        OUT.flush()
        if TTY:
            TTY.close()

if __name__ == "__main__":
    main()

