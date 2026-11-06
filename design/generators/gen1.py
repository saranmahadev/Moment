import sys
sys.path.insert(0, '/home/claude/gen')
from lib import *

# ---------------- Home ----------------
def home():
    h = 3300
    hdr = ('<div style="display:flex;align-items:flex-start;justify-content:space-between"><div style="display:flex;flex-direction:column;gap:4px">%s<span style="font-size:14.5px;color:%s">6 November 2026</span></div>%s</div>'
           % (h1('Friday', 38), SEC, cbtn('search', 'Search', 'Search.dc.html')))
    mood = ('<div style="display:flex;align-items:center;justify-content:space-between;padding:10px 12px 10px 18px;box-sizing:border-box;%s"><span style="font-size:15px;font-weight:600">How are you?</span><div style="display:flex">%s</div></div>'
            % (glass('card', 28), ''.join('<button aria-label="Log mood %s" style="width:44px;height:48px;border:0;background:transparent;font-size:28px;line-height:1;padding:0">%s</button>' % (n, e) for e, n in [('😊', 'happy'), ('😌', 'calm'), ('😐', 'neutral'), ('😔', 'sad'), ('😤', 'frustrated')])))
    cards = ''.join([
        hdr, chips_row('all'), mood,
        day('TODAY · FRI 6 NOV'),
        c_emoji('21:40', '😌', 'Calm', 4),
        c_text('20:12', P1 + ' ' + P2, 31),
        c_audio('18:05', 'Voice note', '0:42'),
        c_place('17:30', 'Favourite bench', '±12 m'),
        c_video('12:20', '0:48', 'Walk to the station', 0),
        c_photo('08:40', 'Morning light on the balcony.', 0),
        day('YESTERDAY · THU 5 NOV'),
        c_emoji('22:10', '😤', 'Frustrated', 2),
        c_text('18:30', 'Train delayed again. Walked the last stretch instead.', 9, 3),
        c_photo('13:05', 'Lunch under the neem tree.', 1),
        c_video('09:50', '0:21', 'Rain on the window', 1),
        c_audio('07:15', 'Morning thoughts', '1:12'),
        c_place('06:40', 'Tea stall', '±8 m'),
        '<p style="text-align:center;font-size:13px;color:%s;margin:28px 0 0">Older logs live in Library.</p>' % SEC,
    ])
    return shell('Home', flow(cards, 60, 12, 160) + nav('home'), 390, h)


# ---------------- Lock ----------------
def lock():
    keys = ''
    for n in '123456789':
        keys += '<button aria-label="%s" style="width:76px;height:76px;padding:0;font-size:28px;font-weight:500;color:%s;%s">%s</button>' % (n, INK, glass('card', 38), n)
    keys += '<a href="Main.dc.html" aria-label="Unlock with Face ID" style="width:76px;height:76px;display:flex;align-items:center;justify-content:center;color:%s">%s</a>' % (INK, ic('face', 30, 1.6))
    keys += '<button aria-label="0" style="width:76px;height:76px;padding:0;font-size:28px;font-weight:500;color:%s;%s">0</button>' % (INK, glass('card', 38))
    keys += '<button aria-label="Delete last digit" style="width:76px;height:76px;padding:0;border:0;background:transparent;color:%s;display:flex;align-items:center;justify-content:center">%s</button>' % (SEC, ic('backspace', 28, 1.6))
    dots_ = ''.join('<div style="width:14px;height:14px;border-radius:7px;box-sizing:border-box;%s"></div>' % ('background:%s' % INK if i < 2 else 'border:1.5px solid %s' % SEC) for i in range(4))
    body = ('<div style="position:absolute;top:96px;left:0;right:0;display:flex;flex-direction:column;align-items:center;gap:10px">'
            '<div style="width:64px;height:64px;display:flex;align-items:center;justify-content:center;%s">%s</div>%s'
            '<p style="margin:0;font-size:14.5px;color:%s">Everything stays on this device</p></div>' % (glass('surface', 32), ic('lock', 26), '<div style="height:6px"></div>' + h1('Moment', 38), SEC) +
            '<div role="img" aria-label="2 of 4 digits entered" style="position:absolute;top:276px;left:0;right:0;display:flex;justify-content:center;gap:18px">%s</div>' % dots_ +
            '<div style="position:absolute;top:340px;left:53px;right:53px;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px;justify-items:center">%s</div>' % keys +
            '<p style="position:absolute;bottom:34px;left:0;right:0;margin:0;text-align:center;font-size:13px;color:%s">No account · No cloud · No tracking</p>' % SEC)
    return shell('Lock', body)


# ---------------- Add sheet ----------------
def add():
    under = flow(c_text('20:12', P1, 15, 3) + c_photo('08:40', 'Morning light on the balcony.', 0), 60, 12)
    scrim = '<div aria-hidden="true" style="position:absolute;left:0;right:0;top:0;bottom:0;background:rgba(27,31,42,0.16)"></div>'
    tiles = ''
    for k in ORDER:
        t = T[k]
        tiles += ('<a href="New-%s.dc.html" style="display:flex;flex-direction:column;gap:10px;box-sizing:border-box;padding:16px;min-height:124px;color:%s;%s">%s'
                  '<span style="font-size:16px;font-weight:600">%s</span><span style="font-size:13px;line-height:1.35;color:%s">%s</span></a>'
                  % (t.file, INK, glass('card', 22), badge(t, 40), t.name, SEC, t.blurb))
    sheet = ('<div style="position:absolute;left:0;right:0;bottom:0;box-sizing:border-box;padding:12px 20px 40px;display:flex;flex-direction:column;gap:14px;%sborder-radius:36px 36px 0 0">'
             '<div aria-hidden="true" style="align-self:center;width:40px;height:5px;border-radius:3px;background:rgba(27,31,42,0.25)"></div>'
             '<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;flex-direction:column;gap:2px">%s<span style="font-size:14px;color:%s">Each type is its own log. Pick one.</span></div>%s</div>'
             '<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px">%s</div></div>'
             % (glass('strong', 36), h1('Add to your log', 28), SEC, cbtn('x', 'Close', 'Main.dc.html'), tiles))
    return shell('Add sheet', under + scrim + sheet)


# ---------------- Library ----------------
def library():
    counts = {'text': ('48 logs', 'Today'), 'emoji': ('112 logs', 'Today'), 'photo': ('236 logs', 'Today'), 'video': ('19 logs', 'Today'), 'audio': ('31 logs', 'Today'), 'place': ('27 logs', 'Today')}
    tiles = ''
    for k in ORDER:
        t = T[k]
        c, last = counts[k]
        tiles += ('<a href="List-%s.dc.html" style="display:flex;flex-direction:column;gap:6px;box-sizing:border-box;padding:16px;min-height:150px;color:%s;%s">%s<span style="flex:1"></span>'
                  '<span style="%sfont-size:25px;line-height:1.1">%s</span><span style="font-size:13px;color:%s">%s · Last: %s</span></a>'
                  % (t.file, INK, glass('card', 24), badge(t, 44), SERIF, t.plural, SEC, c, last))
    top = '<div style="display:flex;align-items:center;justify-content:space-between">%s%s</div>' % (h1('Library', 38), cbtn('search', 'Search', 'Search.dc.html'))
    sub = '<p style="margin:0;font-size:14.5px;color:%s">Everything you have logged, one section per type.</p>' % SEC
    trash = ('<a href="Trash.dc.html" style="display:flex;align-items:center;gap:12px;min-height:56px;box-sizing:border-box;padding:0 18px;color:%s;%s">%s<span style="font-size:15.5px;font-weight:500;flex:1">Trash</span><span style="font-size:13px;color:%s">3 logs</span>%s</a>'
             % (INK, glass('card', 24), ic('trash', 20), SEC, ic('chev-r', 18)))
    body = flow(top + sub + '<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:6px">%s</div>' % tiles + trash, 60, 12)
    return shell('Library', body + nav('library'))


# ---------------- Create screens ----------------
def create_header(t, save='Save'):
    return ('<div style="display:flex;align-items:center;justify-content:space-between">%s<div style="display:flex;align-items:center;gap:8px;%sheight:44px;padding:0 16px 0 8px;font-size:15px;font-weight:600">%s%s</div>%s</div>'
            % (cbtn('x', 'Close without saving', 'Main.dc.html'), glass('card', 22), badge(t, 28), t.name, pbtn(save, 'Main.dc.html')))


def time_pill(txt='Fri 6 Nov · 21:42'):
    return '<div style="display:flex;justify-content:center">%s</div>' % sbtn(txt, None, 40, 16, 'font-size:14px;', 'pencil')


def new_text():
    t = T['text']
    surface = ('<div style="position:relative;flex:1;border-radius:28px;box-sizing:border-box;padding:22px;display:flex;flex-direction:column;%s">%s'
               '<span style="margin-top:auto;font-size:13px;color:%s">21 words · Draft saved</span></div>'
               % (glass('surface', 28), '<p style="margin:0;%sfont-size:23px;line-height:1.45">Walking home. The air smells like rain, and the streets are almost empty.<span aria-hidden="true" style="display:inline-block;width:2px;height:26px;margin-left:2px;vertical-align:text-bottom;background:%s"></span></p>' % (SERIF, INK), SEC))
    tools = ''.join('<button aria-label="%s" style="width:50px;height:50px;border:0;border-radius:25px;background:%s;color:%s;display:flex;align-items:center;justify-content:center;padding:0">%s</button>' % (n, 'rgba(27,31,42,0.08)' if on else 'transparent', INK, ic(i, 24)) for i, n, on in [('bold', 'Bold', 0), ('italic', 'Italic', 1), ('list', 'List', 0), ('quote', 'Quote', 0)])
    tb = '<div style="position:absolute;left:16px;right:16px;bottom:22px;height:70px;box-sizing:border-box;padding:0 24px;display:flex;align-items:center;justify-content:space-around;%s">%s</div>' % (glass('strong', 35), tools)
    body = '<div style="position:absolute;top:60px;left:20px;right:20px;bottom:112px;display:flex;flex-direction:column;gap:14px">%s%s%s</div>' % (create_header(t), time_pill(), surface) + tb
    return shell('New text', body)


def new_emoji():
    t = T['emoji']
    big = ('<div style="display:flex;flex-direction:column;align-items:center;gap:10px"><div style="width:150px;height:150px;border-radius:75px;display:flex;align-items:center;justify-content:center;font-size:88px;line-height:1;%s">😌</div>%s</div>'
           % (glass('surface', 75), h1('Calm', 34)))
    levels = ''.join('<button aria-label="Intensity %d of 5" aria-pressed="%s" style="width:44px;height:44px;border-radius:22px;padding:0;font-size:14px;font-weight:600;color:%s;%s">%d</button>'
                     % (i, 'true' if i == 4 else 'false', '#FFFFFF' if i == 4 else INK, ('background:%s;border:1px solid %s;' % (INK, INK)) if i == 4 else glass('card', 22), i) for i in range(1, 6))
    inten = ('<div style="display:flex;flex-direction:column;gap:8px;align-items:center"><span style="font-size:13px;font-weight:600;letter-spacing:0.08em;color:%s">HOW STRONG?</span><div style="display:flex;align-items:center;gap:10px"><span style="font-size:13px;color:%s">Light</span><div style="display:flex;gap:8px">%s</div><span style="font-size:13px;color:%s">Strong</span></div></div>' % (SEC, SEC, levels, SEC))
    em = ['😊', '😌', '🙂', '😄', '🥰', '😴', '😐', '😔', '😢', '😤', '😰', '🤒']
    cells = ''.join('<button aria-label="Emoji %d%s" style="height:60px;border-radius:18px;padding:0;font-size:32px;line-height:1;%s">%s</button>' % (i + 1, ', selected' if e == '😌' else '', ('background:%s;border:1.5px solid %s;' % (t.tint, t.color)) if e == '😌' else 'background:transparent;border:1.5px solid transparent;', e) for i, e in enumerate(em))
    grid = '<div style="box-sizing:border-box;padding:12px;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;%s">%s</div>' % (glass('surface', 28), cells)
    more = '<div style="display:flex;justify-content:center">%s</div>' % sbtn('Browse all emoji', None, 44, 20, '', 'search')
    body = flow(create_header(t, 'Log mood') + big + inten + grid + more, 60, 18)
    return shell('New emoji', body)


def viewfinder(kind):
    t = T[kind]
    corners = ''
    for pos in ['top:16px;left:16px;border-top:3px solid #FFFFFF;border-left:3px solid #FFFFFF;border-top-left-radius:12px',
                'top:16px;right:16px;border-top:3px solid #FFFFFF;border-right:3px solid #FFFFFF;border-top-right-radius:12px',
                'bottom:16px;left:16px;border-bottom:3px solid #FFFFFF;border-left:3px solid #FFFFFF;border-bottom-left-radius:12px',
                'bottom:16px;right:16px;border-bottom:3px solid #FFFFFF;border-right:3px solid #FFFFFF;border-bottom-right-radius:12px']:
        corners += '<span aria-hidden="true" style="position:absolute;width:28px;height:28px;%s"></span>' % pos
    zoom = ''.join('<span style="min-width:44px;height:36px;display:inline-flex;align-items:center;justify-content:center;padding:0 10px;box-sizing:border-box;font-size:13.5px;font-weight:600;color:%s;%s">%s</span>' % (INK, glass('card', 18) if z != '1×' else 'background:#FFFFFF;border-radius:18px;', z) for z in ['0.5×', '1×', '2×'])
    grad = GR[0] if kind == 'photo' else VGR[0]
    return ('<div role="img" aria-label="Camera viewfinder placeholder" style="position:absolute;left:16px;right:16px;top:124px;bottom:196px;border-radius:32px;overflow:hidden;background:%s;box-shadow:0 10px 36px rgba(40,50,100,0.16)">%s'
            '<div style="position:absolute;left:0;right:0;bottom:22px;display:flex;justify-content:center;gap:8px">%s</div></div>' % (grad, corners, zoom))


def camera(kind):
    t = T[kind]
    top = ('<div style="position:absolute;top:60px;left:20px;right:20px;display:flex;align-items:center;justify-content:space-between">%s%s%s</div>'
           % (cbtn('x', 'Close', 'Main.dc.html'), ('<div style="display:flex;align-items:center;gap:8px;%sheight:44px;padding:0 16px 0 8px;font-size:15px;font-weight:600">%s%s</div>' % (glass('card', 22), badge(t, 28), t.name)) if kind == 'photo' else
                                                    ('<div style="display:flex;align-items:center;gap:8px;%sheight:44px;padding:0 16px;font-size:15px;font-weight:600;font-variant-numeric:tabular-nums"><span aria-hidden="true" style="width:10px;height:10px;border-radius:5px;background:#DC2626"></span>Recording 00:12</div>' % glass('card', 22)),
                                                    cbtn('zap', 'Flash')))
    if kind == 'photo':
        shutter = ('<a href="Main.dc.html" aria-label="Take photo" style="width:80px;height:80px;border-radius:40px;display:flex;align-items:center;justify-content:center;%s"><span style="width:58px;height:58px;border-radius:29px;background:%s"></span></a>' % (glass('strong', 40), INK))
        cap = 'Photo'
    else:
        shutter = ('<a href="Main.dc.html" aria-label="Stop and save video" style="width:80px;height:80px;border-radius:40px;display:flex;align-items:center;justify-content:center;%s"><span style="width:30px;height:30px;border-radius:8px;background:#DC2626"></span></a>' % glass('strong', 40))
    bottom = ('<div style="position:absolute;left:0;right:0;bottom:40px;display:flex;align-items:center;justify-content:space-around;padding:0 28px">%s%s%s</div>' % (cbtn('image', 'Choose from library', None, 56), shutter, cbtn('flip', 'Flip camera', None, 56)))
    return shell('New ' + t.name.lower(), viewfinder(kind) + top + bottom)


def new_audio():
    t = T['audio']
    name = '<div style="display:flex;align-items:center;gap:10px;height:52px;box-sizing:border-box;padding:0 18px;font-size:16px;color:%s;%s">%s<span>Voice note</span></div>' % (INK, glass('card', 26), ic('pencil', 18))
    timer = '<div style="text-align:center;%sfont-size:72px;line-height:1;font-weight:400;font-variant-numeric:tabular-nums;margin-top:18px">00:42</div>' % SERIF
    wavecard = '<div style="display:flex;align-items:center;height:150px;box-sizing:border-box;padding:0 22px;%s">%s</div>' % (glass('surface', 28), wave([10, 18, 26, 14, 22, 30, 16, 24, 12, 20, 28, 14, 8, 22, 18, 26, 12, 20, 30, 16, 24, 10, 18, 26, 14, 22, 12, 20], t.color, 90, 1, 4))
    ctrl = lambda icon, lab, size, href=None, main=False: ('<div style="display:flex;flex-direction:column;align-items:center;gap:8px">%s<span style="font-size:13px;font-weight:500;color:%s">%s</span></div>' % (
        ('<button aria-label="%s" style="width:%dpx;height:%dpx;border-radius:%dpx;padding:0;border:0;background:%s;color:#FFFFFF;display:flex;align-items:center;justify-content:center;box-shadow:0 8px 24px rgba(27,31,42,0.3)">%s</button>' % (lab, size, size, size // 2, INK, ic(icon, 34, 1.75, '#FFFFFF', '#FFFFFF'))) if main else cbtn(icon, lab, href, size), SEC, lab))
    controls = '<div style="display:flex;align-items:flex-start;justify-content:space-around;margin-top:auto;padding-bottom:20px">%s%s%s</div>' % (ctrl('trash', 'Discard', 56, 'Main.dc.html'), ctrl('pause', 'Pause', 88, None, True), ctrl('check', 'Save', 56, 'Main.dc.html'))
    hdr = '<div style="display:flex;align-items:center;justify-content:space-between">%s<div style="display:flex;align-items:center;gap:8px;%sheight:44px;padding:0 16px 0 8px;font-size:15px;font-weight:600">%s%s</div><span style="width:44px"></span></div>' % (cbtn('x', 'Close without saving', 'Main.dc.html'), glass('card', 22), badge(t, 28), t.name)
    body = '<div style="position:absolute;top:60px;left:20px;right:20px;bottom:34px;display:flex;flex-direction:column;gap:16px">%s%s%s%s%s</div>' % (hdr, name, timer, wavecard, controls)
    return shell('New audio', body)


def new_place():
    t = T['place']
    mp = ('<div style="position:absolute;left:0;right:0;top:0;height:560px">%s</div>' % mapbox(560, ((50, 52),), 0, 52))
    top = ('<div style="position:absolute;top:60px;left:20px;right:20px;display:flex;align-items:center;justify-content:space-between">%s<div style="display:flex;align-items:center;gap:8px;%sheight:44px;padding:0 16px 0 8px;font-size:15px;font-weight:600">%s%s</div>%s</div>'
           % (cbtn('x', 'Close without saving', 'Main.dc.html'), glass('card', 22), badge(t, 28), t.name, cbtn('crosshair', 'Use current location')))
    ring = '<div aria-hidden="true" style="position:absolute;left:50%;top:231px;width:120px;height:120px;margin-left:-60px;border-radius:60px;background:rgba(21,128,61,0.16);border:1.5px solid rgba(21,128,61,0.5)"></div>'
    sheet = ('<div style="position:absolute;left:0;right:0;bottom:0;box-sizing:border-box;padding:12px 20px 36px;display:flex;flex-direction:column;gap:14px;%sborder-radius:36px 36px 0 0">'
             '<div aria-hidden="true" style="align-self:center;width:40px;height:5px;border-radius:3px;background:rgba(27,31,42,0.25)"></div>'
             '<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;flex-direction:column;gap:2px">%s<span style="font-size:13.5px;color:%s">Accuracy ±12 m · Fri 6 Nov · 17:30</span></div>%s</div>'
             '<div style="display:flex;align-items:center;gap:10px;height:52px;box-sizing:border-box;padding:0 18px;font-size:16px;color:%s;%s">%s<span>Name this place (optional)</span></div>'
             '<p style="margin:0;font-size:13px;line-height:1.4;color:%s">Place names are typed by you. Nothing is looked up online.</p>'
             '<div style="display:flex;gap:10px">%s%s</div></div>'
             % (glass('strong', 36), h1('Pin this spot', 26), SEC, chip_static('Locked on', 'check', '#15803D', 36), SEC, glass('card', 26), ic('pencil', 18), SEC,
                sbtn('Move pin', None, 52, 20, 'flex:1;', 'crosshair'), pbtn('Save location', 'Main.dc.html', 52, 24, 'flex:1;')))
    return shell('New location', mp + ring + top + sheet)


pages = {
    'Main.dc.html': home(), 'Lock.dc.html': lock(), 'Add.dc.html': add(), 'Library.dc.html': library(),
    'New-Text.dc.html': new_text(), 'New-Emoji.dc.html': new_emoji(), 'New-Photo.dc.html': camera('photo'),
    'New-Video.dc.html': camera('video'), 'New-Audio.dc.html': new_audio(), 'New-Location.dc.html': new_place(),
}
for n, h in pages.items():
    write(n, h)
print('ok', len(pages))
