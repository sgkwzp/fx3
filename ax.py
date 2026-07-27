import re, sys
x = open(sys.argv[1], encoding='utf-8', errors='replace').read()
ents = re.findall(r'<entry>(.*?)</entry>', x, re.S)
if not ents:
    print("ZERO RESULTS")
lim = int(sys.argv[2]) if len(sys.argv) > 2 else 1400
for e in ents:
    gid = re.search(r'<id>(.*?)</id>', e).group(1)
    t = ' '.join(re.search(r'<title>(.*?)</title>', e, re.S).group(1).split())
    p = re.search(r'<published>(.*?)</published>', e).group(1)[:10]
    s = ' '.join(re.search(r'<summary>(.*?)</summary>', e, re.S).group(1).split())
    print('==', gid, p)
    print('T:', t)
    print('A:', s[:lim])
    print()
