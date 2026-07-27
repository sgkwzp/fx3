#!/bin/bash
# usage: ab.sh id1 id2 ...
for id in "$@"; do
  curl -sL -m 40 "http://export.arxiv.org/api/query?id_list=${id}" \
  | tr -d '\n' | sed 's|<entry>|\n|g' | grep 'arxiv.org/abs' \
  | awk -v ID="$id" '{ s=$0; sub(/.*<title>/,"",s); sub(/<\/title>.*/,"",s);
     a=$0; sub(/.*<summary>/,"",a); sub(/<\/summary>.*/,"",a);
     d=$0; sub(/.*<published>/,"",d); sub(/T.*/,"",d);
     gsub(/  +/," ",s); gsub(/  +/," ",a);
     print "### "ID" ["d"] "s; print a; print "" }'
  sleep 3
done
