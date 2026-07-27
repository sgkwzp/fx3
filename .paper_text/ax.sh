#!/bin/bash
q="$1"; m="${2:-20}"
enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$q")
echo "#### QUERY: $q"
curl -sS -L --max-time 40 "https://export.arxiv.org/api/query?search_query=${enc}&start=0&max_results=${m}&sortBy=submittedDate&sortOrder=descending" -o /d/paperscode/fx3/.paper_text/_ax.xml
python3 -c '
import sys,xml.etree.ElementTree as ET
ns={"a":"http://www.w3.org/2005/Atom"}
try: r=ET.fromstring(sys.stdin.read())
except Exception as e:
    print("PARSE_FAIL",e); sys.exit()
es=r.findall("a:entry",ns)
if not es: print("  (no results)")
for e in es:
    i=e.find("a:id",ns).text.split("/abs/")[-1]
    t=" ".join(e.find("a:title",ns).text.split())
    d=e.find("a:published",ns).text[:10]
    s=" ".join(e.find("a:summary",ns).text.split())[:280]
    print(f"- {i} | {d} | {t}\n    {s}")
'
echo
