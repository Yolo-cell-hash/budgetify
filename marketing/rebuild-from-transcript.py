#!/usr/bin/env python3
"""Reconstruct budgetify-launch-film.html by replaying the previous session's
Write/Edit operations from the local transcript, then re-running the two
programmatic passes (font/logo base64 injection, six-royal SPR swap)."""
import json, re, base64, subprocess, pathlib, sys

J = pathlib.Path.home() / '.claude/projects/-Users-jaykeer-AndroidStudioProjects-budget-tracker/8339bfd4-a78d-4622-a75e-992adc4c3273.jsonl'
REPO = pathlib.Path('/Users/jaykeer/AndroidStudioProjects/budget_tracker')
OUT = pathlib.Path(__file__).parent / 'budgetify-launch-film.html'
TARGET = 'budgetify-launch-film.html'

ops, errored = [], set()
for line in J.open():
    try: rec = json.loads(line)
    except json.JSONDecodeError: continue
    msg = rec.get('message') or {}
    content = msg.get('content')
    if not isinstance(content, list): continue
    for blk in content:
        if not isinstance(blk, dict): continue
        if blk.get('type') == 'tool_use' and blk.get('name') in ('Write', 'Edit'):
            inp = blk.get('input') or {}
            if TARGET in (inp.get('file_path') or ''):
                ops.append((blk['id'], blk['name'], inp))
        elif blk.get('type') == 'tool_result' and blk.get('is_error'):
            errored.add(blk.get('tool_use_id'))

doc, applied, skipped = None, 0, 0
for uid, name, inp in ops:
    if uid in errored: skipped += 1; continue
    if name == 'Write':
        doc = inp['content']; applied += 1
    else:
        old, new = inp['old_string'], inp['new_string']
        if doc is None: sys.exit('Edit before Write?!')
        n = doc.count(old)
        if n == 0: sys.exit(f'REPLAY MISMATCH (op {applied+skipped}): old_string not found: {old[:90]!r}')
        if n > 1 and not inp.get('replace_all'): sys.exit(f'REPLAY AMBIGUOUS: {old[:90]!r}')
        doc = doc.replace(old, new) if inp.get('replace_all') else doc.replace(old, new, 1)
        applied += 1
print(f'replayed ops: {applied} applied, {skipped} skipped-as-errored')

# Pass 1: font + logo base64 (same downscale settings as the original build).
scratch = pathlib.Path(__file__).parent
subprocess.run(['sips', '-Z', '400', '-s', 'format', 'jpeg', '-s', 'formatOptions', '78',
                str(REPO / 'assets/branding/logo.png'), '--out', str(scratch / 'logo400.jpg')],
               check=True, capture_output=True)
b64 = lambda p: base64.b64encode(pathlib.Path(p).read_bytes()).decode()
for tok, path in [('__M500__', REPO / 'assets/fonts/manrope-500.ttf'),
                  ('__M800__', REPO / 'assets/fonts/manrope-800.ttf'),
                  ('__LOGO__', scratch / 'logo400.jpg')]:
    assert tok in doc, f'{tok} placeholder missing'
    doc = doc.replace(tok, b64(path))

# Pass 2: six-royal SPR swap extracted from the real widget source.
src = (REPO / 'lib/widgets/royal_avatars.dart').read_text()
CONSTS = {'_outline': '#15171E', '_eyeWhite': '#F2F5F8', '_gold': '#F2C14E', '_goldDeep': '#C09232'}
def rows_of(name):
    m = re.search(r"const List<String> %s = \[(.*?)\];" % name, src, re.S)
    return re.findall(r"'([^']*)'", m.group(1))
def pal_of(name):
    m = re.search(r"const Map<String, Color> %s = \{(.*?)\};" % name, src, re.S)
    pal = {}
    for k, v in re.findall(r"'(.)':\s*([^,\n]+),", m.group(1)):
        v = v.strip()
        cm = re.match(r"Color\(0xFF([0-9A-Fa-f]{6})\)", v)
        pal[k] = '#' + cm.group(1).upper() if cm else CONSTS[v]
    return pal
royals = {}
for block in re.findall(r"RoyalAvatar\((.*?)\n  \)", src, re.S):
    gid = re.search(r"id: '(\w+)'", block)
    if not gid: continue
    rowsref = re.search(r"rows: (_\w+Rows)", block).group(1)
    royals[gid.group(1)] = {
        'rows': rows_of(rowsref), 'pal': pal_of(rowsref.replace('Rows', 'Palette')),
        'ew': int(re.search(r"eyeRowWhites: (\d+)", block).group(1)),
        'ei': int(re.search(r"eyeRowIris: (\d+)", block).group(1)),
        'closed': re.findall(r"'([^']*)'", re.search(r"eyesClosed: \[(.*?)\]", block, re.S).group(1)),
    }
assert len(royals) == 6, royals.keys()
doc, n = re.subn(r"const SPR=\{.*?\}\};", 'const SPR=' + json.dumps(royals, separators=(',', ':')) + ';', doc, count=1, flags=re.S)
assert n == 1, 'SPR literal not found'

OUT.write_text(doc)
print(f'reconstructed {OUT} ({len(doc)//1024} KB)')
for marker in ['__exportLocal', 'T_END=58.0', 'rung mystery', 'Streak Reward Road', 'ry-darkprince', 'recmode #frame']:
    assert marker in doc, f'missing marker: {marker}'
assert 'ry-medic' not in doc, 'medic should be absent'
assert '__M500__' not in doc and '__LOGO__' not in doc
print('all markers verified')
