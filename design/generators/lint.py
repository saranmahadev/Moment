import sys, glob, re
from html.parser import HTMLParser
VOID={'meta','link','br','img','input','hr','script'}
class P(HTMLParser):
    def __init__(s):
        super().__init__(); s.st=[]; s.err=[]
    def handle_starttag(s,t,a):
        if t in VOID: return
        s.st.append((t,s.getpos()))
    def handle_startendtag(s,t,a): pass
    def handle_endtag(s,t):
        if t in VOID: return
        if not s.st or s.st[-1][0]!=t:
            s.err.append(('mismatch',t,s.getpos(), s.st[-1] if s.st else None)); 
            # try recover
            for i in range(len(s.st)-1,-1,-1):
                if s.st[i][0]==t: del s.st[i:]; break
        else: s.st.pop()
bad=0
for f in sorted(glob.glob('/home/claude/moment-canvas/project/*.dc.html')):
    p=P(); p.feed(open(f,encoding='utf-8').read())
    if p.err or p.st:
        bad+=1; print(f.split('/')[-1], p.err[:2], p.st[:3])
    txt=open(f,encoding='utf-8').read()
    if '{{' in txt.replace('{"$preview":{"width"',''): print('hole?', f)
print('files', len(glob.glob('/home/claude/moment-canvas/project/*.dc.html')), 'bad', bad)
