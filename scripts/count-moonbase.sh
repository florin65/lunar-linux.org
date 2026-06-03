#!/bin/sh

#MOONBASE="/path/to/moonbase"
#OUT="/path/to/site/data/moonbase-stats.json"

MOONBASE="../../moonbase"
OUT="../data/moonbase-stats.json"

COUNT=$(find "$MOONBASE" -type f -name DETAILS | wc -l)

cat > "$OUT" <<EOF
{
"modules": $COUNT
}
EOF
