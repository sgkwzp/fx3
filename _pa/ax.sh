#!/bin/bash
q="$1"; m="${2:-20}"
enc=$(python -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$q")
echo "#### QUERY: $q"
curl -sS -L --max-time 45 -o /d/paperscode/fx3/_pa/raw.xml "https://export.arxiv.org/api/query?search_query=${enc}&start=0&max_results=${m}&sortBy=relevance"
python /d/paperscode/fx3/_pa/axp.py < /d/paperscode/fx3/_pa/raw.xml
echo
