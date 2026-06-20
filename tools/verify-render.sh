for f in ../src/markdown/*.md
do
    md=$(grep -c "^## " "$f")
    html=$(grep -c "<h2" "docs/$(basename "$f" .md).html")
    echo "$f : $md -> $html"
done

