from collections import namedtuple

OUT = '/home/claude/moment-canvas/project'
INK = '#1B1F2A'
SEC = '#3A4152'
FONT = '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Newsreader:ital,wght@0,400;0,500;1,400&display=swap">'
SERIF = "font-family:'Newsreader',Georgia,serif;"

TT = namedtuple('TT', 'key name plural color tint icon file blurb')
T = {
    'text': TT('text', 'Text', 'Text', '#1D4ED8', 'rgba(29,78,216,0.14)', 'type', 'Text', 'Write what is on your mind'),
    'emoji': TT('emoji', 'Emoji', 'Emoji', '#B45309', 'rgba(245,158,11,0.24)', 'smile', 'Emoji', 'Log how you feel'),
    'photo': TT('photo', 'Photo', 'Photos', '#BE185D', 'rgba(236,72,153,0.16)', 'camera', 'Photo', 'Take or choose a photo'),
    'video': TT('video', 'Video', 'Videos', '#6D28D9', 'rgba(139,92,246,0.18)', 'video', 'Video', 'Record or choose a video'),
    'audio': TT('audio', 'Audio', 'Audio', '#0F766E', 'rgba(20,184,166,0.20)', 'mic', 'Audio', 'Record a voice note'),
    'place': TT('place', 'Location', 'Locations', '#15803D', 'rgba(34,197,94,0.20)', 'pin', 'Location', 'Pin where you are'),
}
ORDER = ['text', 'emoji', 'photo', 'video', 'audio', 'place']

ICONS = {
    'type': '<polyline points="4 7 4 4 20 4 20 7"/><line x1="9" x2="15" y1="20" y2="20"/><line x1="12" x2="12" y1="4" y2="20"/>',
    'smile': '<circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" x2="9.01" y1="9" y2="9"/><line x1="15" x2="15.01" y1="9" y2="9"/>',
    'camera': '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
    'video': '<path d="m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5"/><rect x="2" y="6" width="14" height="12" rx="2"/>',
    'mic': '<path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" x2="12" y1="19" y2="22"/>',
    'pin': '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
    'plus': '<path d="M5 12h14"/><path d="M12 5v14"/>',
    'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'calendar': '<path d="M8 2v4"/><path d="M16 2v4"/><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>',
    'home': '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    'grid': '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    'sliders': '<line x1="21" x2="14" y1="4" y2="4"/><line x1="10" x2="3" y1="4" y2="4"/><line x1="21" x2="12" y1="12" y2="12"/><line x1="8" x2="3" y1="12" y2="12"/><line x1="21" x2="16" y1="20" y2="20"/><line x1="12" x2="3" y1="20" y2="20"/><line x1="14" x2="14" y1="2" y2="6"/><line x1="8" x2="8" y1="10" y2="14"/><line x1="16" x2="16" y1="18" y2="22"/>',
    'chev-l': '<path d="m15 18-6-6 6-6"/>',
    'chev-r': '<path d="m9 18 6-6-6-6"/>',
    'chev-d': '<path d="m6 9 6 6 6-6"/>',
    'x': '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    'play': '<polygon points="6 3 20 12 6 21 6 3"/>',
    'pause': '<rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/>',
    'stop': '<rect width="14" height="14" x="5" y="5" rx="2"/>',
    'trash': '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>',
    'pencil': '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"/><path d="m15 5 4 4"/>',
    'shield': '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    'lock': '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
    'backspace': '<path d="M20 5H9l-7 7 7 7h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Z"/><line x1="18" x2="12" y1="9" y2="15"/><line x1="12" x2="18" y1="9" y2="15"/>',
    'face': '<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><path d="M9 9h.01"/><path d="M15 9h.01"/>',
    'restore': '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
    'image': '<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>',
    'flip': '<path d="M11 19H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h5"/><path d="M13 5h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-5"/><circle cx="12" cy="12" r="3"/><path d="m18 22-3-3 3-3"/><path d="m6 2 3 3-3 3"/>',
    'crosshair': '<circle cx="12" cy="12" r="10"/><line x1="22" x2="18" y1="12" y2="12"/><line x1="6" x2="2" y1="12" y2="12"/><line x1="12" x2="12" y1="6" y2="2"/><line x1="12" x2="12" y1="22" y2="18"/>',
    'check': '<path d="M20 6 9 17l-5-5"/>',
    'zap': '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
    'bold': '<path d="M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8"/>',
    'italic': '<line x1="19" x2="10" y1="4" y2="4"/><line x1="14" x2="5" y1="20" y2="20"/><line x1="15" x2="9" y1="4" y2="20"/>',
    'list': '<path d="M3 12h.01"/><path d="M3 18h.01"/><path d="M3 6h.01"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M8 6h13"/>',
    'quote': '<path d="M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z"/><path d="M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z"/>',
    'copy': '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    'skip-b': '<polygon points="19 20 9 12 19 4 19 20"/><line x1="5" x2="5" y1="19" y2="5"/>',
    'skip-f': '<polygon points="5 4 15 12 5 20 5 4"/><line x1="19" x2="19" y1="5" y2="19"/>',
}


def ic(name, size=22, sw=1.75, fill='none', color='currentColor'):
    return ('<svg width="%d" height="%d" viewBox="0 0 24 24" fill="%s" stroke="%s" stroke-width="%s" '
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>') % (size, size, fill, color, sw, ICONS[name])


GL = {
    'card': (0.46, 24, 160, 0.72, '0 8px 32px rgba(40,50,100,0.10)'),
    'strong': (0.62, 28, 170, 0.8, '0 12px 40px rgba(40,50,100,0.16)'),
    'surface': (0.5, 26, 165, 0.75, '0 10px 36px rgba(40,50,100,0.12)'),
}


def glass(kind='card', r=24, extra=''):
    a, b, s, bd, sh = GL[kind]
    return ('background:rgba(255,255,255,%s);backdrop-filter:blur(%dpx) saturate(%d%%);-webkit-backdrop-filter:blur(%dpx) saturate(%d%%);'
            'border:1px solid rgba(255,255,255,%s);box-shadow:%s,inset 0 1px 0 rgba(255,255,255,0.88);border-radius:%dpx;%s') % (a, b, s, b, s, bd, sh, r, extra)


ORB = ['linear-gradient(135deg,#B7C3FF,#8B93F5)', 'linear-gradient(135deg,#FFD3BF,#FFAE9A)', 'linear-gradient(135deg,#BFEFDD,#8ADBC2)']
GR = [
    'linear-gradient(160deg,#F6C9B4 0%,#C7B8F5 55%,#9FD8F0 100%)',
    'linear-gradient(160deg,#BFE3F0 0%,#D9C8F5 50%,#F6D6C0 100%)',
    'linear-gradient(160deg,#CDEBD8 0%,#B8C7F5 55%,#F2C4D6 100%)',
    'linear-gradient(160deg,#F2D9A8 0%,#F0B8C4 55%,#B9B6F0 100%)',
]
VGR = [
    'linear-gradient(160deg,#8E9BD6 0%,#B79AD6 55%,#E9A9B8 100%)',
    'linear-gradient(160deg,#7FB6C9 0%,#9FA6DB 55%,#D6A5C8 100%)',
]
WV = [10, 18, 26, 14, 22, 30, 16, 24, 12, 20, 28, 14, 8, 22, 18, 26, 12, 20]


def shell(title, body, w=390, h=844, interactive=True):
    orbs = ''
    i = 0
    y = 90
    while y < h:
        side = 'left:-70px' if i % 2 == 0 else 'right:-60px'
        orbs += '<div aria-hidden="true" style="position:absolute;%s;top:%dpx;width:240px;height:240px;border-radius:50%%;background:%s;opacity:0.8"></div>\n' % (side, y, ORB[i % 3])
        i += 1
        y += 380
    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<title>Moment: %s</title>\n<script src="./support.js"></script>\n</head>\n<body>\n<x-dc>\n<helmet>\n%s\n<style>\nbody{margin:0}\na{text-decoration:none;color:inherit}\nbutton{font-family:inherit}\n</style>\n</helmet>\n'
            '<div style="position:relative;width:%dpx;height:%dpx;overflow:hidden;box-sizing:border-box;font-family:\'Inter\',system-ui,sans-serif;color:%s;background:#EDF0F7">\n%s%s\n</div>\n</x-dc>\n'
            '<script type="text/x-dc" data-dc-script data-props=\'{"$preview":{"width":%d,"height":%d}}\'>\nclass Component extends DCLogic {\nrenderVals() {\nreturn {};\n}\n}\n</script>\n</body>\n</html>\n') % (title, FONT, w, h, INK, orbs, body, w, h)


def flow(inner, pt=60, gap=12, pb=0, px=20):
    return '<div style="position:relative;padding:%dpx %dpx %dpx;display:flex;flex-direction:column;gap:%dpx">%s</div>' % (pt, px, pb, gap, inner)


def cbtn(icon, label, href=None, size=44):
    st = 'width:%dpx;height:%dpx;display:flex;align-items:center;justify-content:center;flex:none;padding:0;color:%s;%s' % (size, size, INK, glass('card', size // 2))
    if href:
        return '<a href="%s" aria-label="%s" style="%s">%s</a>' % (href, label, st, ic(icon, 22))
    return '<button aria-label="%s" style="%s">%s</button>' % (label, st, ic(icon, 22))


def pbtn(text, href=None, h=44, px=22, extra='', icon=None):
    st = ('height:%dpx;padding:0 %dpx;border-radius:%dpx;display:inline-flex;align-items:center;justify-content:center;gap:8px;'
          'background:%s;color:#FFFFFF;font-size:15px;font-weight:600;border:0;box-shadow:0 6px 18px rgba(27,31,42,0.25);%s') % (h, px, h // 2, INK, extra)
    inner = (ic(icon, 18) if icon else '') + text
    if href:
        return '<a href="%s" style="%s">%s</a>' % (href, st, inner)
    return '<button style="%s">%s</button>' % (st, inner)


def sbtn(text, href=None, h=44, px=20, extra='', icon=None, color=INK):
    st = 'height:%dpx;padding:0 %dpx;display:inline-flex;align-items:center;justify-content:center;gap:8px;font-size:15px;font-weight:500;color:%s;%s%s' % (h, px, color, glass('card', h // 2), extra)
    inner = (ic(icon, 18) if icon else '') + text
    if href:
        return '<a href="%s" style="%s">%s</a>' % (href, st, inner)
    return '<button style="%s">%s</button>' % (st, inner)


def badge(t, size=30):
    return ('<span style="width:%dpx;height:%dpx;border-radius:%dpx;display:inline-flex;align-items:center;justify-content:center;background:%s;color:%s;flex:none">%s</span>'
            % (size, size, size // 2, t.tint, t.color, ic(t.icon, int(size * 0.55), 2)))


def h1(text, size=36):
    return '<h1 style="margin:0;%sfont-weight:500;font-size:%dpx;letter-spacing:-0.01em;line-height:1.15">%s</h1>' % (SERIF, size, text)


def label(text, pad='6px 4px 0'):
    return '<div style="font-size:12px;font-weight:600;letter-spacing:0.08em;color:%s;padding:%s">%s</div>' % (SEC, pad, text)


def nav(active, top=750):
    def item(icon, text, href, key):
        act = key == active
        bg = 'background:rgba(27,31,42,0.08);' if act else ''
        col = INK if act else SEC
        return ('<a href="%s" aria-label="%s" style="width:62px;height:58px;border-radius:26px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;color:%s;font-size:11.5px;font-weight:600;%s">%s%s</a>'
                % (href, text, col, bg, ic(icon, 22), text))
    plus = ('<a href="Add.dc.html" aria-label="Add a log" style="width:56px;height:56px;border-radius:28px;background:%s;color:#FFFFFF;display:flex;align-items:center;justify-content:center;box-shadow:0 6px 18px rgba(27,31,42,0.3)">%s</a>' % (INK, ic('plus', 26, 2)))
    return ('<nav aria-label="Main" style="position:absolute;left:16px;right:16px;top:%dpx;height:72px;box-sizing:border-box;padding:0 8px;display:flex;align-items:center;justify-content:space-around;%s">%s%s%s%s%s</nav>'
            % (top, glass('strong', 36), item('home', 'Home', 'Main.dc.html', 'home'), item('grid', 'Library', 'Library.dc.html', 'library'), plus,
               item('calendar', 'Calendar', 'Calendar.dc.html', 'calendar'), item('sliders', 'Settings', 'Settings.dc.html', 'settings')))


def wave(heights=WV, color=INK, h=32, op=0.7, w=3, done=None, active_color=None):
    bars = ''
    for i, x in enumerate(heights):
        c = color
        o = op
        if done is not None:
            if i < done:
                c = active_color or color
                o = 1
            else:
                o = 0.3
        bars += '<div style="width:%dpx;height:%dpx;border-radius:2px;background:%s;opacity:%s"></div>' % (w, x * h // 32, c, o)
    return '<div aria-hidden="true" style="flex:1;display:flex;align-items:center;justify-content:space-between;height:%dpx">%s</div>' % (h, bars)


def dots(lvl, col, size=8, gap=5):
    out = ''
    for i in range(5):
        c = col if i < lvl else 'rgba(27,31,42,0.2)'
        out += '<span style="width:%dpx;height:%dpx;border-radius:%dpx;background:%s"></span>' % (size, size, size // 2, c)
    return '<span role="img" aria-label="Intensity %d of 5" style="display:flex;gap:%dpx">%s</span>' % (lvl, gap, out)


def mapbox(h, pins=((50, 50),), r=18, big=30):
    pin = ''
    for x, y in pins:
        pin += '<span style="position:absolute;left:%d%%;top:%d%%;transform:translate(-50%%,-100%%);display:flex">%s</span>' % (x, y, ic('pin', big, 2, '#FFFFFF', '#15803D'))
    bg = ('background:repeating-linear-gradient(0deg,rgba(255,255,255,0.55) 0 1px,transparent 1px 28px),'
          'repeating-linear-gradient(90deg,rgba(255,255,255,0.55) 0 1px,transparent 1px 28px),'
          'linear-gradient(135deg,#CFEFD9,#BFE3F0)')
    return '<div role="img" aria-label="Offline map placeholder" style="position:relative;height:%dpx;border-radius:%dpx;overflow:hidden;%s">%s</div>' % (h, r, bg, pin)


def head(t, time):
    return ('<div style="display:flex;align-items:center;gap:8px">%s<span style="font-size:13px;font-weight:600;color:%s">%s</span><span style="margin-left:auto;font-size:13px;font-weight:500;color:%s">%s</span></div>'
            % (badge(t), t.color, t.name, SEC, time))


def card(t, inner, pad=16, href=None):
    href = href or 'View-%s.dc.html' % t.file
    return '<a href="%s" style="display:flex;flex-direction:column;gap:10px;box-sizing:border-box;padding:%dpx;color:%s;%s">%s</a>' % (href, pad, INK, glass('card', 24), inner)


def body_text(txt, size=19, clamp=0):
    cl = ''
    if clamp:
        cl = 'display:-webkit-box;-webkit-line-clamp:%d;-webkit-box-orient:vertical;overflow:hidden;' % clamp
    return '<p style="margin:0;%sfont-size:%dpx;line-height:1.4;%s">%s</p>' % (SERIF, size, cl, txt)


def chip_static(text, icon=None, color=None, h=32):
    ic_ = (ic(icon, 14, 2, 'none', color or SEC) if icon else '')
    return ('<span style="display:inline-flex;align-items:center;gap:6px;height:%dpx;padding:0 12px;border-radius:%dpx;background:rgba(255,255,255,0.6);border:1px solid rgba(255,255,255,0.85);font-size:13px;font-weight:500;color:#3A4152">%s%s</span>'
            % (h, h // 2, ic_, text))


# ---------- the six card types ----------
P1 = 'Quiet evening. Finished the book I started in October, and the flat is finally silent.'
P2 = "I keep thinking about the last chapter. Some endings don't close anything; they just stop asking."


def c_text(time, txt, words, clamp=3):
    t = T['text']
    return card(t, head(t, time) + body_text(txt, 19, clamp) + '<span style="font-size:12.5px;color:%s">%s words</span>' % (SEC, words))


def c_emoji(time, e, name, lvl):
    t = T['emoji']
    row = ('<div style="display:flex;align-items:center;gap:14px"><span style="width:60px;height:60px;border-radius:30px;display:flex;align-items:center;justify-content:center;font-size:34px;line-height:1;background:%s">%s</span>'
           '<div style="display:flex;flex-direction:column;gap:8px"><span style="%sfont-size:24px;line-height:1.1">%s</span>%s</div></div>') % (t.tint, e, SERIF, name, dots(lvl, t.color))
    return card(t, head(t, time) + row)


def c_photo(time, cap, gi=0):
    t = T['photo']
    img = ('<div role="img" aria-label="Photo placeholder" style="height:244px;border-radius:18px;background:%s;display:flex;align-items:center;justify-content:center;color:rgba(27,31,42,0.5)">%s</div>' % (GR[gi % 4], ic('camera', 30, 1.5)))
    return card(t, '<div style="padding:0 4px">' + head(t, time) + '</div>' + img + '<div style="padding:0 4px 2px">' + body_text(cap, 18) + '</div>', 12)


def c_video(time, dur, cap, gi=0):
    t = T['video']
    play = '<span style="width:60px;height:60px;border-radius:30px;display:flex;align-items:center;justify-content:center;color:%s;%s">%s</span>' % (INK, glass('strong', 30), ic('play', 22, 1.5, INK))
    chip = '<span style="position:absolute;right:10px;bottom:10px;height:28px;padding:0 10px;display:flex;align-items:center;font-size:12.5px;font-weight:600;color:%s;%s">%s</span>' % (INK, glass('strong', 14), dur)
    img = ('<div role="img" aria-label="Video thumbnail placeholder" style="position:relative;height:183px;border-radius:18px;background:%s;display:flex;align-items:center;justify-content:center">%s%s</div>' % (VGR[gi % 2], play, chip))
    return card(t, '<div style="padding:0 4px">' + head(t, time) + '</div>' + img + '<div style="padding:0 4px 2px">' + body_text(cap, 18) + '</div>', 12)


def c_audio(time, title, dur):
    t = T['audio']
    btn = '<span style="width:48px;height:48px;border-radius:24px;flex:none;display:flex;align-items:center;justify-content:center;background:%s;color:#FFFFFF">%s</span>' % (INK, ic('play', 18, 1.5, '#FFFFFF', '#FFFFFF'))
    row = '<div style="display:flex;align-items:center;gap:14px">%s<div style="flex:1;display:flex;flex-direction:column;gap:6px"><span style="font-size:15.5px;font-weight:600">%s</span>%s</div><span style="font-size:13px;font-weight:500;color:%s">%s</span></div>' % (btn, title, wave(WV, t.color, 28), SEC, dur)
    return card(t, head(t, time) + row)


def c_place(time, name, acc):
    t = T['place']
    row = '<div style="display:flex;align-items:center;justify-content:space-between;gap:10px">%s%s</div>' % (body_text(name, 19), chip_static(acc))
    return card(t, head(t, time) + mapbox(120, ((50, 62),), 16, 28) + row)


def day(text):
    return '<div style="font-size:12px;font-weight:600;letter-spacing:0.08em;color:%s;padding:12px 4px 0">%s</div>' % (SEC, text)


def chips_row(active='all', cls=''):
    out = ''
    items = [('all', 'All', 'grid', INK)] + [(k, T[k].plural if k != 'place' else 'Location', T[k].icon, T[k].color) for k in ORDER]
    for key, name, icon, col in items:
        act = key == active
        if act:
            st = 'height:44px;padding:0 16px;border-radius:22px;display:inline-flex;align-items:center;gap:8px;flex:none;font-size:14.5px;font-weight:500;background:%s;color:#FFFFFF;border:1px solid %s;' % (INK, INK)
            ico = ic(icon, 16, 2, 'none', '#FFFFFF')
        else:
            st = 'height:44px;padding:0 16px;display:inline-flex;align-items:center;gap:8px;flex:none;font-size:14.5px;font-weight:500;color:%s;%s' % (INK, glass('card', 22))
            ico = ic(icon, 16, 2, 'none', col)
        out += '<span style="%s">%s%s</span>' % (st, ico, name)
    return '<div style="display:flex;gap:8px;overflow:hidden">%s</div>' % out


def sortchip():
    return '<span style="display:inline-flex;align-items:center;gap:6px;height:44px;padding:0 14px;font-size:14px;font-weight:500;color:%s;%s">Newest first%s</span>' % (INK, glass('card', 22), ic('chev-d', 16))


def write(name, html):
    with open('%s/%s' % (OUT, name), 'w', encoding='utf-8') as f:
        f.write(html)
