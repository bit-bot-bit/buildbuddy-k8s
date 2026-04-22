#!/usr/bin/env bash

set -euo pipefail

version="${1:?version is required}"
chart_file="${2:-Chart.yaml}"

if grep -q '^version:' "$chart_file"; then
  sed -i "s/^version:.*/version: ${version}/" "$chart_file"
else
  awk -v version="$version" '
    /^type:/ && !inserted {
      print
      print "version: " version
      inserted=1
      next
    }
    { print }
    END {
      if (!inserted) {
        print "version: " version
      }
    }
  ' "$chart_file" > "${chart_file}.tmp"
  mv "${chart_file}.tmp" "$chart_file"
fi
