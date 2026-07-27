#!/bin/bash
# usage: aq.sh "search_query" [max]
Q="$1"; M="${2:-15}"
curl -sL -m 45 "http://export.arxiv.org/api/query?search_query=${Q}&start=0&max_results=${M}" \
 | tr -d '\n' | sed 's|<entry>|\n|g' | grep 'arxiv.org/abs' \
 | awk '{ id=""; ti="";
   if (match($0,/abs\/[^<]*/)) id=substr($0,RSTART+4,RLENGTH-4);
   s=$0; sub(/.*<title>/,"",s); sub(/<\/title>.*/,"",s); gsub(/  +/," ",s);
   print id" :: "substr(s,1,150) }'
echo "=== done: $Q"
