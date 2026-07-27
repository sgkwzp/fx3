import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
print("count:", d["meta"]["count"])
for w in d["results"]:
    print("-", w.get("publication_year"), "|", (w.get("title") or "")[:120])
