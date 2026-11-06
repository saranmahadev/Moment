import sys, json
sys.path.insert(0, '/home/claude/gen')
from lib import *


def pushed_header(back, title, right=''):
    return '<div style="display:flex;align-items:center;justify-content:space-between">%s%s</div>%s' % (cbtn('chev-l', 'Back', back), right, h1(title, 34))


def grouped(rows):
    return '<div style="overflow:hidden;%s">%s</div>' % (glass('card', 24), ''.join(rows))


def row(title, sub='', right='', href=None, last=False, h=56):
    bd = '' if last else 'border-bottom:1px solid rgba(27,31,42,0.08);'
    left = '<div style="display:flex;flex-direction:column;gap:2px;flex:1"><span style="font-size:15.5px;font-weight:500">%s</span>%s</div>' % (title, ('<span style="font-size:12.5px;line-height:1.35;color:%s">%s</span>' % (SEC, sub)) if sub else '')
    st = 'min-height:%dpx;box-sizing:border-box;padding:8px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px;color:%s;%s' % (h, INK, bd)
    if href:
        return '<a href="%s" style="%s">%s%s</a>' % (href, st, left, right)
    return '<div style="%s">%s%s</div>' % (st, left, right)


def sw(on, lab):
    return ('<button role="switch" aria-checked="%s" aria-label="%s" style="width:52px;height:32px;border-radius:16px;border:0;padding:3px;box-sizing:border-box;display:flex;justify-content:%s;background:%s;flex:none"><span style="width:26px;height:26px;border-radius:13px;background:#FFFFFF;box-shadow:0 2px 6px rgba(0,0,0,0.25)"></span></button>'
            % ('true' if on else 'false', lab, 'flex-end' if on else 'flex-start', INK if on else '#8B91A3'))


def val(txt, chev=True):
    return '<span style="display:flex;align-items:center;gap:6px;font-size:15px;color:%s;flex:none">%s%s</span>' % (SEC, txt, ic('chev-r', 18) if chev else '')


# ---------------- Calendar ----------------
def calendar():
    data = {1: ['emoji'], 2: ['text', 'photo'], 3: ['audio'], 4: ['emoji', 'text', 'place'], 5: ['emoji', 'text', 'photo', 'video'], 6: ORDER}
    days = [(d, True) for d in (26, 27, 28, 29, 30, 31)] + [(d, False) for d in range(1, 31)] + [(d, True) for d in range(1, 7)]
    cells = ''
    for d, dim in days:
        today = (not dim) and d == 6
        st = 'border:1.5px solid %s;background:rgba(27,31,42,0.08);' % INK if today else 'border:1.5px solid transparent;'
        dts = ''
        if not dim and d in data:
            dts = '<span style="display:flex;flex-wrap:wrap;justify-content:center;gap:2px;width:22px;height:12px;overflow:hidden">%s</span>' % ''.join('<span style="width:6px;height:6px;border-radius:3px;background:%s"></span>' % T[k].color for k in data[d])
        else:
            dts = '<span style="height:12px"></span>'
        cells += ('<div style="height:50px;border-radius:14px;box-sizing:border-box;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;%s"><span style="font-size:13px;font-weight:%s;color:%s">%d</span>%s</div>'
                  % (st, 600 if today else 500, '#5F667A' if dim else INK, d, dts))
    grid = ('<div style="box-sizing:border-box;padding:14px 10px 10px;%s"><div style="display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:2px;padding-bottom:6px;font-size:12px;font-weight:600;color:%s;text-align:center"><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span><span>S</span></div>'
            '<div style="display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:2px">%s</div></div>' % (glass('surface', 28), SEC, cells))
    head_ = '<div style="display:flex;align-items:center;justify-content:space-between">%s<div style="display:flex;gap:8px">%s%s</div></div>' % (h1('November 2026', 32), cbtn('chev-l', 'Previous month', None, 44), cbtn('chev-r', 'Next month', None, 44))
    sel = [('emoji', '21:40', 'Calm · strength 4 of 5'), ('text', '20:12', 'Quiet evening. Finished the book I…'), ('audio', '18:05', 'Voice note · 0:42'),
           ('place', '17:30', 'Favourite bench'), ('video', '12:20', 'Walk to the station · 0:48'), ('photo', '08:40', 'Morning light on the balcony.')]
    rows = ''
    for k, tm, pv in sel:
        t = T[k]
        rows += ('<a href="View-%s.dc.html" style="display:flex;align-items:center;gap:12px;min-height:56px;box-sizing:border-box;padding:0 14px;color:%s;%s">%s<div style="flex:1;display:flex;flex-direction:column"><span style="font-size:12.5px;font-weight:600;color:%s">%s · %s</span><span style="font-size:14.5px">%s</span></div>%s</a>'
                 % (t.file, INK, glass('card', 20), badge(t, 34), t.color, t.name, tm, pv, ic('chev-r', 18, 1.75, 'none', SEC)))
    legend = '<div style="display:flex;flex-wrap:wrap;gap:6px 14px;padding:0 4px;font-size:12.5px;color:%s">%s</div>' % (SEC, ''.join('<span style="display:inline-flex;align-items:center;gap:6px"><span style="width:8px;height:8px;border-radius:4px;background:%s"></span>%s</span>' % (T[k].color, T[k].name) for k in ORDER))
    body = flow(head_ + grid + legend + chips_row('all') + label('FRIDAY 6 NOVEMBER · 6 LOGS', '6px 4px 0') + rows, 60, 12, 160) + nav('calendar')
    return shell('Calendar', body, 390, 1100)


# ---------------- Search ----------------
def search():
    field = ('<div style="display:flex;align-items:center;gap:10px;flex:1;height:48px;box-sizing:border-box;padding:0 16px;font-size:16px;%s">%s<span style="flex:1">balcony</span>%s</div>'
             % (glass('card', 24), ic('search', 18), ic('x', 18)))
    top = '<div style="display:flex;align-items:center;gap:10px">%s%s</div>' % (cbtn('chev-l', 'Back', 'Main.dc.html'), field)
    hit = lambda s: s.replace('balcony', '<span style="background:rgba(245,158,11,0.35);border-radius:4px;padding:0 2px">balcony</span>')

    def res(k, title, sub, href=None):
        t = T[k]
        return ('<a href="View-%s.dc.html" style="display:flex;align-items:center;gap:12px;min-height:60px;box-sizing:border-box;padding:8px 14px;color:%s;%s">%s<div style="flex:1;display:flex;flex-direction:column;gap:2px"><span style="font-size:15px;line-height:1.35">%s</span><span style="font-size:12.5px;color:%s">%s</span></div></a>'
                % (t.file, INK, glass('card', 20), badge(t, 34), hit(title), SEC, sub))

    def grp(k, n):
        t = T[k]
        return '<div style="display:flex;align-items:center;gap:8px;padding:8px 4px 0">%s<span style="font-size:12px;font-weight:600;letter-spacing:0.08em;color:%s">%s · %d</span></div>' % (ic(t.icon, 14, 2, 'none', t.color), t.color, t.name.upper(), n)
    out = (grp('text', 2) + res('text', 'Morning light on the balcony. First coffee, no phone.', 'Fri 6 Nov · 08:40') + res('text', 'Wrote the whole page sitting on the balcony floor.', 'Mon 26 Oct · 17:20') +
           grp('photo', 1) + res('photo', 'Morning light on the balcony.', 'Fri 6 Nov · 08:40') +
           grp('audio', 1) + res('audio', 'Balcony thoughts · 0:42', 'Thu 5 Nov · 07:15') +
           grp('place', 1) + res('place', 'Home balcony', 'Fri 30 Oct · 08:00'))
    note = '<p style="margin:6px 4px 0;font-size:12.5px;color:%s">Search runs on this device. Nothing is sent anywhere.</p>' % SEC
    return shell('Search', flow(top + chips_row('all') + out + note, 60, 10, 40))


# ---------------- Settings hub ----------------
def settings():
    g1 = grouped([row('Privacy and backup', 'App lock, encrypted backup, export', ic('chev-r', 18), 'Privacy.dc.html'),
                  row('Trash', 'Deleted logs stay for 30 days', val('3 logs'), 'Trash.dc.html', True)])
    g2 = grouped([row('Quick emoji row', 'Five emoji on Home', val('Edit')), row('Evening reminder', 'Local notification at 21:00', sw(True, 'Evening reminder')),
                  row('Video and photo quality', '', val('Original'), None, True)])
    g3 = grouped([row('Theme', '', val('System')), row('Reduce transparency', 'Swaps glass for solid surfaces', sw(False, 'Reduce transparency'), None, True)])
    g4 = grouped([row('How Moment stays local', '', ic('chev-r', 18)), row('Version', '', '<span style="font-size:15px;color:%s">1.0</span>' % SEC, None, True)])
    body = flow(h1('Settings', 38) + label('YOUR DATA') + g1 + label('LOGGING') + g2 + label('APPEARANCE') + g3 + label('ABOUT') + g4, 60, 10, 140) + nav('settings')
    return shell('Settings', body, 390, 960)


# ---------------- Privacy and backup ----------------
def privacy():
    status = ('<div style="display:flex;align-items:center;gap:14px;padding:16px;%s"><div style="width:48px;height:48px;border-radius:24px;flex:none;display:flex;align-items:center;justify-content:center;background:rgba(27,31,42,0.08)">%s</div>'
              '<div style="display:flex;flex-direction:column;gap:2px"><span style="%sfont-size:22px;line-height:1.2">Local only</span><span style="font-size:13.5px;line-height:1.35;color:%s">No account, no servers, no internet permission.</span></div></div>'
              % (glass('strong', 24), ic('shield', 24), SERIF, SEC))
    g_sec = grouped([row('App lock', 'PIN with Face ID', sw(True, 'App lock')), row('Lock after', '', val('Immediately'), None, True)])
    g_bak = grouped([row('Encrypted backup', 'Last backup: never', pbtn('Back up now', None, 44, 18, 'font-size:14.5px;'), None, False, 64), row('Restore from backup', 'Choose a backup file', ic('chev-r', 18), None, True)])
    exp_chips = ''.join('<span style="display:inline-flex;align-items:center;gap:6px;height:36px;padding:0 12px;border-radius:18px;font-size:13.5px;font-weight:500;background:%s;border:1.5px solid %s;color:%s">%s%s</span>' % (T[k].tint, T[k].color, INK, ic('check', 14, 2.5, 'none', T[k].color), T[k].name) for k in ORDER)
    g_exp = '<div style="box-sizing:border-box;padding:14px 16px;display:flex;flex-direction:column;gap:12px;%s"><div style="display:flex;flex-direction:column;gap:2px"><span style="font-size:15.5px;font-weight:500">Export</span><span style="font-size:12.5px;color:%s">Markdown, JSON and original files. Choose types.</span></div><div style="display:flex;flex-wrap:wrap;gap:8px">%s</div>%s</div>' % (glass('card', 24), SEC, exp_chips, sbtn('Export selected types', None, 48, 20, '', 'download'))
    g_loc = grouped([row('Look up place names', 'Uses the internet. Keep off to stay fully offline.', sw(False, 'Look up place names'), None, True, 64)])
    store = [('video', 'Video', 92, '2.4 GB'), ('photo', 'Photo', 42, '1.1 GB'), ('audio', 'Audio', 8, '180 MB'), ('text', 'Text', 2, '4 MB'), ('emoji', 'Emoji', 1, '<1 MB'), ('place', 'Location', 1, '<1 MB')]
    bars = ''.join('<div style="display:flex;align-items:center;gap:10px;font-size:13px"><span style="width:62px;color:%s">%s</span><div style="flex:1;height:8px;border-radius:4px;background:rgba(27,31,42,0.1)"><div style="width:%d%%;height:8px;border-radius:4px;background:%s"></div></div><span style="width:58px;text-align:right;font-weight:500">%s</span></div>' % (SEC, n, p, T[k].color, s) for k, n, p, s in store)
    g_store = '<div style="box-sizing:border-box;padding:16px;display:flex;flex-direction:column;gap:12px;%s"><span style="font-size:15.5px;font-weight:500">Storage by type</span>%s</div>' % (glass('card', 24), bars)
    body = flow('<div style="display:flex;align-items:center">%s</div>' % cbtn('chev-l', 'Back', 'Settings.dc.html') + h1('Privacy and backup', 34) + status + label('SECURITY') + g_sec + label('BACKUP') + g_bak + label('EXPORT') + g_exp + label('PLACE NAMES') + g_loc + label('STORAGE') + g_store, 60, 10, 60)
    return shell('Privacy and backup', body, 390, 1260)


# ---------------- Trash ----------------
def trash():
    info = '<div style="display:flex;align-items:center;gap:12px;box-sizing:border-box;padding:14px 16px;font-size:14px;line-height:1.4;color:%s;%s">%s<span>Deleted logs stay here for 30 days, then are removed for good along with their files.</span></div>' % (SEC, glass('card', 22), ic('trash', 20))
    items = [('photo', 'Photo', 'Lunch under the neem tree.', 'Deleted 2 days ago'), ('text', 'Text', 'Rain all day. Tea, soup, nothing else needed.', 'Deleted 5 days ago'), ('audio', 'Audio', 'Call notes · 2:03', 'Deleted 9 days ago')]
    rows = ''
    for k, n, pv, when_ in items:
        t = T[k]
        rows += ('<div style="display:flex;align-items:center;gap:12px;box-sizing:border-box;padding:12px 12px 12px 14px;%s">%s<div style="flex:1;display:flex;flex-direction:column;gap:2px"><span style="font-size:12.5px;font-weight:600;color:%s">%s</span><span style="font-size:14.5px;line-height:1.3">%s</span><span style="font-size:12.5px;color:%s">%s</span></div>%s</div>'
                 % (glass('card', 22), badge(t, 36), t.color, n, pv, SEC, when_, sbtn('Restore', None, 44, 14, 'font-size:14px;', 'restore')))
    empty = '<div style="display:flex;justify-content:center;margin-top:8px">%s</div>' % sbtn('Empty Trash', None, 48, 24, '', 'trash', '#B91C1C')
    return shell('Trash', flow(pushed_header('Settings.dc.html', 'Trash') + info + rows + empty, 60, 12))


# ---------------- App map ----------------
def sitemap(num):
    def chip(n, name, href, x, y, w, h=52, t=None):
        left = badge(t, 30) if t else ''
        return ('<a href="%s" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;box-sizing:border-box;padding:0 14px;display:flex;align-items:center;gap:10px;color:%s;%s">%s<span style="font-size:12.5px;font-weight:600;color:%s">%s</span><span style="font-size:14.5px;font-weight:500">%s</span></a>'
                % (href, x, y, w, h, INK, glass('card', 18), left, SEC, n, name))
    out = '<div style="position:absolute;left:40px;top:44px">%s<p style="margin:6px 0 0;font-size:15px;color:%s">Every log type has its own Create, Section and Detail page. Types are never merged.</p></div>' % (h1('App map: 28 screens', 40), SEC)
    out += '<div style="position:absolute;left:40px;top:150px">%s</div>' % label('CORE · TAB BAR: HOME · LIBRARY · + · CALENDAR · SETTINGS', '0')
    core = [('01', 'Lock', 'Lock.dc.html'), ('02', 'Home', 'Main.dc.html'), ('03', 'Add sheet', 'Add.dc.html'), ('04', 'Library', 'Library.dc.html'), ('23', 'Calendar', 'Calendar.dc.html'),
            ('24', 'Search', 'Search.dc.html'), ('25', 'Settings', 'Settings.dc.html'), ('26', 'Privacy and backup', 'Privacy.dc.html'), ('27', 'Trash', 'Trash.dc.html'), ('28', 'Design language', 'Language.dc.html')]
    for i, (n, name, href) in enumerate(core):
        out += chip(n, name, href, 40 + (i % 5) * 228, 180 + (i // 5) * 68, 212)
    y0 = 400
    out += '<div style="position:absolute;left:40px;top:%dpx">%s</div>' % (y0, label('ONE ROW PER LOG TYPE', '0'))
    for x, txt in [(250, 'CREATE · FROM THE + BUTTON'), (570, 'SECTION · FROM LIBRARY'), (890, 'DETAIL · OPEN A LOG')]:
        out += '<div style="position:absolute;left:%dpx;top:%dpx">%s</div>' % (x, y0 + 28, label(txt, '0'))
    for i, k in enumerate(ORDER):
        t = T[k]
        y = y0 + 58 + i * 66
        out += '<div style="position:absolute;left:40px;top:%dpx;width:190px;height:52px;display:flex;align-items:center;gap:10px">%s<span style="%sfont-size:22px">%s</span></div>' % (y, badge(t, 36), SERIF, t.name)
        out += chip('%02d' % (5 + i), 'New ' + t.name.lower(), 'New-%s.dc.html' % t.file, 250, y, 300, 52)
        out += chip('%02d' % (11 + i), t.plural, 'List-%s.dc.html' % t.file, 570, y, 300, 52)
        out += chip('%02d' % (17 + i), t.name + ' detail', 'View-%s.dc.html' % t.file, 890, y, 300, 52)
    return shell('App map', out, 1240, 920)


# ---------------- Design language ----------------
def language():
    def sw_(name, hexv, bg, border=False):
        b = 'border:1px solid rgba(27,31,42,0.15);' if border else ''
        return '<div style="display:flex;flex-direction:column;gap:6px"><div style="height:48px;border-radius:14px;background:%s;%s"></div><span style="font-size:12.5px;font-weight:600">%s</span><span style="font-size:12px;color:%s;margin-top:-4px">%s</span></div>' % (bg, b, name, SEC, hexv)
    pal = ''.join([sw_('Ground', '#EDF0F7', '#EDF0F7', True), sw_('Ink', '#1B1F2A', '#1B1F2A'), sw_('Secondary', '#3A4152', '#3A4152'), sw_('Switch off', '#8B91A3', '#8B91A3'),
                   sw_('Orb indigo', '#B7C3FF', ORB[0]), sw_('Orb peach', '#FFD3BF', ORB[1]), sw_('Orb mint', '#BFEFDD', ORB[2]), sw_('Danger', '#B91C1C', '#B91C1C')])
    types = ''.join('<div style="display:flex;align-items:center;gap:12px;height:52px;box-sizing:border-box;padding:0 14px;%s">%s<span style="font-size:15px;font-weight:600;color:%s;flex:1">%s</span><span style="font-size:12px;color:%s">%s</span></div>' % (glass('card', 18), badge(T[k], 34), T[k].color, T[k].name, SEC, T[k].color) for k in ORDER)
    gl = lambda title, desc, kind, r: '<div style="min-height:96px;box-sizing:border-box;padding:16px 20px;display:flex;flex-direction:column;gap:4px;%s"><span style="font-size:15.5px;font-weight:600">%s</span><span style="font-size:13px;line-height:1.4;color:%s">%s</span></div>' % (glass(kind, r), title, SEC, desc)
    left = ('<div style="position:absolute;left:40px;top:150px;width:380px;display:flex;flex-direction:column;gap:12px">%s%s%s%s%s</div>'
            % (label('GLASS', '0'), gl('Card', 'White 46%, blur 24, saturation 160%. 1 px white border, soft shadow, radius 24.', 'card', 24),
               gl('Dock and sheets', 'White 62%, blur 28, saturation 170%. Deeper shadow, radius 32 to 36.', 'strong', 32),
               gl('Writing surface', 'White 50%, blur 26, radius 28. The largest glass area, kept quiet.', 'surface', 28),
               gl('Accessible by default', 'Text 4.5:1 or better. Controls 44 px or larger. Reduce Transparency swaps glass for solid #F4F5FA. Type colour is never the only cue: each type also has its own icon and label.', 'strong', 24)))
    right = ('<div style="position:absolute;left:460px;top:150px;width:360px;display:flex;flex-direction:column;gap:12px">%s<div style="display:flex;flex-direction:column;gap:8px">%s</div>%s'
             '<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px 12px">%s</div>%s<div style="display:flex;flex-direction:column;gap:2px"><span style="%sfont-size:32px;line-height:1.2">Quiet evening.</span><span style="font-size:13px;color:%s">Newsreader for your words. Inter for controls.</span></div></div>'
             % (label('SIX LOG TYPES', '0'), types, label('PALETTE', '14px 0 0'), pal, label('TYPE', '14px 0 0'), SERIF, SEC))
    hdr = '<div style="position:absolute;left:40px;top:44px">%s<p style="margin:6px 0 0;font-size:15.5px;color:%s">Minimal and calm: soft colour, frosted glass, one card style per log type.</p></div>' % (h1('Design language', 44), SEC)
    return shell('Design language', hdr + left + right, 860, 1020)


pages = {'Calendar.dc.html': calendar(), 'Search.dc.html': search(), 'Settings.dc.html': settings(), 'Privacy.dc.html': privacy(), 'Trash.dc.html': trash(), 'Sitemap.dc.html': sitemap(0), 'Language.dc.html': language()}
for n, h in pages.items():
    write(n, h)

# ---------- canvas.json ----------
boards = {}
order = []


def add(file, x, y, w, h, title, interactive=True):
    b = {'x': x, 'y': y, 'w': w, 'h': h, 'title': title}
    if interactive:
        b['is_interactive'] = True
    boards[file] = b
    order.append(file)


GAP = 80
col = 470
rowA = 1300
add('Sitemap.dc.html', 0, 0, 1240, 920, '00 App map')
add('Main.dc.html', 0, rowA, 390, 3300, '02 Home: all six log types')
add('Lock.dc.html', col, rowA, 390, 844, '01 Lock')
add('Add.dc.html', col * 2, rowA, 390, 844, '03 Add: pick a type')
add('Library.dc.html', col * 3, rowA, 390, 844, '04 Library: one section per type')
rowB = rowA + 3300 + 400
names = {'text': 'Text', 'emoji': 'Emoji', 'photo': 'Photo', 'video': 'Video', 'audio': 'Audio', 'place': 'Location'}
for i, k in enumerate(ORDER):
    add('New-%s.dc.html' % T[k].file, col * i, rowB, 390, 844, '%02d Create %s' % (5 + i, names[k]))
rowC = rowB + 844 + 400
list_h = {'text': 1200, 'emoji': 1180, 'photo': 1000, 'video': 1000, 'audio': 960, 'place': 1020}
for i, k in enumerate(ORDER):
    add('List-%s.dc.html' % T[k].file, col * i, rowC, 390, list_h[k], '%02d Section: %s' % (11 + i, T[k].plural))
rowD = rowC + 1200 + 400
for i, k in enumerate(ORDER):
    add('View-%s.dc.html' % T[k].file, col * i, rowD, 390, 844, '%02d Detail: %s' % (17 + i, names[k]))
rowE = rowD + 844 + 400
add('Calendar.dc.html', 0, rowE, 390, 1100, '23 Calendar')
add('Search.dc.html', col, rowE, 390, 844, '24 Search')
add('Settings.dc.html', col * 2, rowE, 390, 960, '25 Settings')
add('Privacy.dc.html', col * 3, rowE, 390, 1260, '26 Privacy and backup')
add('Trash.dc.html', col * 4, rowE, 390, 844, '27 Trash')
add('Language.dc.html', col * 5, rowE, 860, 1020, '28 Design language', False)

notes = {
    'n0': {'x': 0, 'y': -300, 'text': 'Moment: every log type is its own thing', 'kind': 'title1', 'maxW': 1240},
    'nA': {'x': 0, 'y': rowA - 300, 'text': 'Home and navigation', 'kind': 'title1', 'maxW': 1800},
    'nB': {'x': 0, 'y': rowB - 300, 'text': 'Create: one screen per type', 'kind': 'title1', 'maxW': 2740},
    'nC': {'x': 0, 'y': rowC - 300, 'text': 'Library sections: one list per type', 'kind': 'title1', 'maxW': 2740},
    'nD': {'x': 0, 'y': rowD - 300, 'text': 'Detail: one view per type', 'kind': 'title1', 'maxW': 2740},
    'nE': {'x': 0, 'y': rowE - 300, 'text': 'Calendar, search and settings', 'kind': 'title1', 'maxW': 3210},
    'nH': {'x': col * 2, 'y': rowA + 900, 'w': 380, 'fill': 'blue', 'text': 'Home is one long feed. Each card is one log of one type, and the tab bar floats at the bottom of the screen while you scroll.'},
}
canvas = {'v': 3, 'createdOnFiles': {'v': 1, 'at': '2026-11-06T16:25:00Z'}, 'title': 'Moment: Glassmorphism UI Mockups', 'launch': {'view': 'canvas'}, 'pages': [],
          'boards': boards, 'order': order, 'notes': notes, 'designSystems': []}
with open('%s/canvas.json' % OUT, 'w') as f:
    json.dump(canvas, f, indent=1)
print('ok', len(pages), len(boards))
