import sys,re
d=sys.stdin.read()
es=re.findall(r"<entry>(.*?)</entry>",d,re.S)
if not es:
    print("ZERO ENTRIES / EMPTY RESPONSE len=%d"%len(d))
    sys.exit()
for e in es:
    t=re.search(r"<title>(.*?)</title>",e,re.S).group(1).strip().replace("\n"," ")
    i=re.search(r"<id>(.*?)</id>",e,re.S).group(1).strip().split("/abs/")[-1]
    p=re.search(r"<published>(.*?)</published>",e,re.S).group(1)[:7]
    s=re.search(r"<summary>(.*?)</summary>",e,re.S).group(1).strip()
    s=" ".join(s.split())
    print("* [%s %s] %s"%(i,p,t))
    print("   "+s[:400])
