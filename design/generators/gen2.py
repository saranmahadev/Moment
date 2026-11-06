import sys
sys.path.insert(0, '/home/claude/gen')
from lib import *

LIST_H = 1100


def list_header(t, count):
    top = '<div style="display:flex;align-items:center;justify-content:space-between">%s%s</div>' % (cbtn('chev-l', 'Back to Library', 'Library.dc.html'), cbtn('search', 'Search', 'Search.dc.html'))
    ttl = ('<div style="display:flex;align-items:center;gap:12px">%s<div style="display:flex;flex-direction:column;gap:2px">%s<span style="font-size:14px;color:%s">%s</span></div></div>'
           % (badge(t, 48), h1(t.plural, 34), SEC, count))
    return top + ttl


def page_list(t, count, content, h=LIST_H):
    body = flow(list_header(t, count) + '<div style="display:flex">%s</div>' % sortchip() + content, 60, 14, 140) + nav('library')
    return shell(t.plural, body, 390, h)


def list_text():
    t = T['text']
    items = ''.join([
        c_text('Fri 6 Nov · 20:12', P1 + ' ' + P2, 31),
        c_text('Thu 5 Nov · 18:30', 'Train delayed again. Walked the last stretch instead.', 9),
        c_text('Wed 4 Nov · 21:05', 'Call with Mum ran long, in the best way. She told the story about the mango tree again, and I let her.', 21),
        c_text('Tue 3 Nov · 22:40', 'Started the new book. The first chapter already feels like a quiet street.', 13),
        c_text('Mon 2 Nov · 19:15', 'Rain all day. Tea, soup, nothing else needed.', 8),
    ])
    return page_list(t, '48 logs', items, 1200)


def list_emoji():
    t = T['emoji']
    days = [('Mon', '😊'), ('Tue', '😐'), ('Wed', '😔'), ('Thu', '😤'), ('Fri', '😌'), ('Sat', ''), ('Sun', '')]
    cells = ''
    for d, e in days:
        today = d == 'Fri'
        st = ('border:1.5px solid %s;background:%s;' % (t.color, t.tint)) if today else 'border:1.5px solid transparent;'
        cells += ('<div style="height:74px;border-radius:18px;box-sizing:border-box;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;%s"><span style="font-size:12.5px;font-weight:600;color:%s">%s</span><span style="font-size:26px;line-height:1;height:26px">%s</span></div>'
                  % (st, SEC, d, e))
    week = '<div style="box-sizing:border-box;padding:12px 10px;%s">%s%s</div>' % (glass('surface', 26), label('THIS WEEK', '0 8px 8px'), '<div style="display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:2px">%s</div>' % cells)
    items = ''.join([
        c_emoji('Fri 6 Nov · 21:40', '😌', 'Calm', 4),
        c_emoji('Fri 6 Nov · 08:10', '😊', 'Happy', 3),
        c_emoji('Thu 5 Nov · 22:10', '😤', 'Frustrated', 2),
        c_emoji('Wed 4 Nov · 20:30', '😔', 'Sad', 3),
        c_emoji('Tue 3 Nov · 13:00', '😐', 'Neutral', 2),
    ])
    return page_list(t, '112 logs', week + items, 1180)


def list_photo():
    t = T['photo']

    def grid(n, start):
        return '<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px">%s</div>' % ''.join(
            '<a href="View-Photo.dc.html" aria-label="Open photo" style="height:112px;border-radius:16px;background:%s;border:1px solid rgba(255,255,255,0.7)"></a>' % GR[(start + i) % 4] for i in range(n))
    content = label('NOVEMBER 2026', '4px 4px 0') + grid(9, 0) + label('OCTOBER 2026', '10px 4px 0') + grid(9, 2)
    return page_list(t, '236 logs', content, 1000)


def list_video():
    t = T['video']

    def tile(i, d, dur):
        play = '<span style="width:36px;height:36px;border-radius:18px;display:flex;align-items:center;justify-content:center;%s">%s</span>' % (glass('strong', 18), ic('play', 14, 1.5, INK, INK))
        chip = '<span style="position:absolute;right:8px;bottom:8px;height:24px;padding:0 8px;display:flex;align-items:center;font-size:12px;font-weight:600;%s">%s</span>' % (glass('strong', 12), dur)
        return ('<a href="View-Video.dc.html" style="display:flex;flex-direction:column;gap:8px;color:%s"><div role="img" aria-label="Video thumbnail placeholder" style="position:relative;height:96px;border-radius:16px;display:flex;align-items:center;justify-content:center;background:%s">%s%s</div>'
                '<span style="font-size:13.5px;font-weight:500;padding:0 2px">%s</span></a>' % (INK, VGR[i % 2], play, chip, d))
    vids = [('Fri 6 Nov', '0:48'), ('Thu 5 Nov', '0:21'), ('Tue 3 Nov', '1:05'), ('Sun 1 Nov', '0:33'), ('Fri 30 Oct', '0:12'), ('Wed 28 Oct', '2:04'), ('Mon 26 Oct', '0:27'), ('Sat 24 Oct', '0:55')]
    grid = '<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px 12px">%s</div>' % ''.join(tile(i, d, du) for i, (d, du) in enumerate(vids))
    return page_list(t, '19 logs', label('NOVEMBER 2026', '4px 4px 0') + grid, 1000)


def list_audio():
    t = T['audio']

    def row(title, meta, dur, i):
        btn = '<span style="width:44px;height:44px;border-radius:22px;flex:none;display:flex;align-items:center;justify-content:center;background:%s">%s</span>' % (INK, ic('play', 16, 1.5, '#FFFFFF', '#FFFFFF'))
        return ('<a href="View-Audio.dc.html" style="display:flex;align-items:center;gap:14px;box-sizing:border-box;padding:14px 16px;color:%s;%s">%s<div style="flex:1;display:flex;flex-direction:column;gap:4px"><span style="font-size:15.5px;font-weight:600">%s</span><span style="font-size:13px;color:%s">%s</span></div>'
                '<div style="width:64px;display:flex">%s</div><span style="font-size:13px;font-weight:500;color:%s;width:34px;text-align:right">%s</span></a>'
                % (INK, glass('card', 22), btn, title, SEC, meta, wave(WV[i:i + 8], t.color, 24, 0.8, 3), SEC, dur))
    rows = ''.join([row('Voice note', 'Fri 6 Nov · 18:05', '0:42', 0), row('Morning thoughts', 'Thu 5 Nov · 07:15', '1:12', 2), row('Walking home', 'Tue 3 Nov · 21:50', '0:28', 4),
                    row('Idea for the weekend', 'Sun 1 Nov · 11:20', '0:51', 1), row('Rain on the roof', 'Fri 30 Oct · 16:40', '0:19', 3), row('Call notes', 'Wed 28 Oct · 18:10', '2:03', 5)])
    return page_list(t, '31 logs', rows, 960)


def list_place():
    t = T['place']

    def row(name, meta, acc):
        return ('<a href="View-Location.dc.html" style="display:flex;align-items:center;gap:14px;box-sizing:border-box;padding:14px 16px;color:%s;%s">%s<div style="flex:1;display:flex;flex-direction:column;gap:3px"><span style="font-size:15.5px;font-weight:600">%s</span><span style="font-size:13px;color:%s">%s</span></div>%s</a>'
                % (INK, glass('card', 22), badge(t, 40), name, SEC, meta, chip_static(acc)))
    mp = '<div style="border-radius:28px;overflow:hidden;box-shadow:0 10px 36px rgba(40,50,100,0.12);border:1px solid rgba(255,255,255,0.75)">%s</div>' % mapbox(220, ((30, 40), (62, 30), (48, 72), (76, 64)), 0, 34)
    rows = ''.join([row('Favourite bench', 'Fri 6 Nov · 17:30', '±12 m'), row('Tea stall', 'Thu 5 Nov · 06:40', '±8 m'), row('River walk', 'Tue 3 Nov · 17:05', '±15 m'),
                    row('Corner bookshop', 'Sun 1 Nov · 12:30', '±10 m'), row('Home balcony', 'Fri 30 Oct · 08:00', '±6 m')])
    return page_list(t, '27 logs', mp + rows, 1020)


# ---------------- detail pages ----------------
def view_header(t, back):
    return '<div style="display:flex;align-items:center;justify-content:space-between">%s<div style="display:flex;gap:10px">%s%s</div></div>' % (
        cbtn('chev-l', 'Back to ' + t.plural, back), cbtn('pencil', 'Edit'), cbtn('trash', 'Move to Trash'))


def when(t, txt):
    return '<div style="display:flex;align-items:center;gap:10px">%s<span style="font-size:14px;font-weight:500;color:%s">%s</span></div>' % (badge(t, 32), SEC, txt)


def view_text():
    t = T['text']
    paper = ('<div style="box-sizing:border-box;padding:26px 24px;display:flex;flex-direction:column;gap:16px;%s">%s%s<span style="font-size:13px;color:%s">31 words</span></div>'
             % (glass('surface', 28), body_text(P1, 24), body_text(P2, 24), SEC))
    return shell('Text', flow(view_header(t, 'List-Text.dc.html') + when(t, 'Friday 6 November · 20:12') + paper, 60, 16))


def view_emoji():
    t = T['emoji']
    big = ('<div style="display:flex;flex-direction:column;align-items:center;gap:14px;margin-top:20px"><div style="width:200px;height:200px;border-radius:100px;display:flex;align-items:center;justify-content:center;font-size:112px;line-height:1;%s">😌</div>%s'
           '<div style="display:flex;align-items:center;gap:12px">%s<span style="font-size:14px;font-weight:500;color:%s">Strong · 4 of 5</span></div></div>' % (glass('surface', 100), h1('Calm', 40), dots(4, t.color, 14, 8), SEC))
    actions = '<div style="display:flex;gap:10px;margin-top:20px">%s%s</div>' % (sbtn('Change emoji', None, 52, 20, 'flex:1;', 'smile'), sbtn('Change strength', None, 52, 20, 'flex:1;'))
    return shell('Emoji', flow(view_header(t, 'List-Emoji.dc.html') + when(t, 'Friday 6 November · 21:40') + big + actions, 60, 16))


def view_photo():
    t = T['photo']
    img = '<div role="img" aria-label="Photo placeholder" style="height:420px;border-radius:28px;background:%s;box-shadow:0 10px 36px rgba(40,50,100,0.14)"></div>' % GR[0]
    cap = '<div style="box-sizing:border-box;padding:18px 20px;display:flex;flex-direction:column;gap:10px;%s">%s<div style="display:flex;gap:8px;flex-wrap:wrap">%s%s</div></div>' % (glass('surface', 26), body_text('Morning light on the balcony.', 24), chip_static('Original quality', 'image'), chip_static('Stored on this device', 'lock'))
    return shell('Photo', flow(view_header(t, 'List-Photo.dc.html') + when(t, 'Friday 6 November · 08:40') + img + cap, 60, 14))


def view_video():
    t = T['video']
    player = ('<div role="img" aria-label="Video player placeholder" style="position:relative;height:197px;border-radius:24px;background:%s;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 36px rgba(40,50,100,0.14)">'
              '<span style="width:64px;height:64px;border-radius:32px;display:flex;align-items:center;justify-content:center;%s">%s</span></div>' % (VGR[0], glass('strong', 32), ic('play', 24, 1.5, INK, INK)))
    scrub = ('<div style="box-sizing:border-box;padding:16px 20px;display:flex;flex-direction:column;gap:12px;%s"><div style="position:relative;height:4px;border-radius:2px;background:rgba(27,31,42,0.18)"><div style="width:25%%;height:4px;border-radius:2px;background:%s"></div>'
             '<span aria-hidden="true" style="position:absolute;left:25%%;top:-7px;width:18px;height:18px;border-radius:9px;background:#FFFFFF;box-shadow:0 2px 8px rgba(0,0,0,0.3);margin-left:-9px"></span></div>'
             '<div style="display:flex;justify-content:space-between;font-size:13px;font-weight:500;color:%s"><span>0:12</span><span>0:48</span></div>'
             '<div style="display:flex;align-items:center;justify-content:center;gap:22px">%s%s%s</div></div>'
             % (glass('surface', 26), t.color, SEC, cbtn('skip-b', 'Back 10 seconds', None, 48), cbtn('play', 'Play', None, 64), cbtn('skip-f', 'Forward 10 seconds', None, 48)))
    cap = '<div style="box-sizing:border-box;padding:16px 20px;display:flex;flex-direction:column;gap:10px;%s">%s%s</div>' % (glass('card', 24), body_text('Walk to the station', 22), '<div style="display:flex;gap:8px">%s</div>' % chip_static('Stored on this device', 'lock'))
    return shell('Video', flow(view_header(t, 'List-Video.dc.html') + when(t, 'Friday 6 November · 12:20') + player + scrub + cap, 60, 14))


def view_audio():
    t = T['audio']
    wv = [10, 18, 26, 14, 22, 30, 16, 24, 12, 20, 28, 14, 8, 22, 18, 26, 12, 20, 30, 16, 24, 10, 18, 26, 14, 22, 12, 20]
    wcard = '<div style="display:flex;align-items:center;height:150px;box-sizing:border-box;padding:0 22px;%s">%s</div>' % (glass('surface', 28), wave(wv, INK, 90, 1, 4, 11, t.color))
    times = '<div style="display:flex;justify-content:space-between;font-size:13px;font-weight:500;color:%s;padding:0 6px"><span>0:17</span><span>0:42</span></div>' % SEC
    ctrl = '<div style="display:flex;align-items:center;justify-content:center;gap:26px;margin-top:10px"><div style="display:flex;flex-direction:column;align-items:center;gap:6px">%s<span style="font-size:12.5px;color:%s">15 s</span></div>' % (cbtn('skip-b', 'Back 15 seconds', None, 56), SEC)
    ctrl += '<button aria-label="Pause" style="width:88px;height:88px;border-radius:44px;padding:0;border:0;background:%s;color:#FFFFFF;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 24px rgba(27,31,42,0.3)">%s</button>' % (INK, ic('pause', 34, 1.75, '#FFFFFF', '#FFFFFF'))
    ctrl += '<div style="display:flex;flex-direction:column;align-items:center;gap:6px">%s<span style="font-size:12.5px;color:%s">15 s</span></div></div>' % (cbtn('skip-f', 'Forward 15 seconds', None, 56), SEC)
    speed = '<div style="display:flex;justify-content:center">%s</div>' % sbtn('Speed 1×', None, 44, 18, 'font-size:14px;')
    ttl = '<div style="display:flex;align-items:center;gap:10px">%s%s</div>' % (h1('Voice note', 32), ic('pencil', 18, 1.75, 'none', SEC))
    return shell('Audio', flow(view_header(t, 'List-Audio.dc.html') + when(t, 'Friday 6 November · 18:05') + ttl + wcard + times + ctrl + speed, 60, 14))


def view_place():
    t = T['place']
    mp = '<div style="border-radius:28px;overflow:hidden;box-shadow:0 10px 36px rgba(40,50,100,0.14);border:1px solid rgba(255,255,255,0.75)">%s</div>' % mapbox(340, ((50, 56),), 0, 52)
    ttl = '<div style="display:flex;align-items:center;gap:10px">%s%s</div>' % (h1('Favourite bench', 32), ic('pencil', 18, 1.75, 'none', SEC))
    chips = '<div style="display:flex;gap:8px;flex-wrap:wrap">%s%s</div>' % (chip_static('Accuracy ±12 m', 'crosshair'), chip_static('Coordinates stored on this device', 'lock'))
    acts = '<div style="display:flex;gap:10px">%s%s</div>' % (sbtn('Copy coordinates', None, 52, 20, 'flex:1;', 'copy'), sbtn('Move pin', None, 52, 20, 'flex:1;', 'crosshair'))
    return shell('Location', flow(view_header(t, 'List-Location.dc.html') + when(t, 'Friday 6 November · 17:30') + mp + ttl + chips + acts, 60, 14))


pages = {
    'List-Text.dc.html': list_text(), 'List-Emoji.dc.html': list_emoji(), 'List-Photo.dc.html': list_photo(),
    'List-Video.dc.html': list_video(), 'List-Audio.dc.html': list_audio(), 'List-Location.dc.html': list_place(),
    'View-Text.dc.html': view_text(), 'View-Emoji.dc.html': view_emoji(), 'View-Photo.dc.html': view_photo(),
    'View-Video.dc.html': view_video(), 'View-Audio.dc.html': view_audio(), 'View-Location.dc.html': view_place(),
}
for n, h in pages.items():
    write(n, h)
print('ok', len(pages))
