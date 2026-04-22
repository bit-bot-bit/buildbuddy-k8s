#!/usr/bin/env bash

set -euo pipefail

mode="${1:-package}"
chart_file="${2:-Chart.yaml}"

default_initial_version="0.1.0"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

is_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

version_gt() {
  local left="$1"
  local right="$2"
  [[ "$(printf '%s\n%s\n' "$left" "$right" | sort -V | tail -n1)" == "$left" && "$left" != "$right" ]]
}

increment_patch() {
  local version="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  printf '%s.%s.%s' "$major" "$minor" "$((patch + 1))"
}

chart_name="$(awk '/^name:/ { print $2; exit }' "$chart_file")"
raw_version="$(awk '/^version:/ { sub(/^version:[[:space:]]*/, "", $0); print; exit }' "$chart_file" || true)"
raw_version="$(trim "$raw_version")"

if is_semver "$raw_version"; then
  base_version="$raw_version"
else
  base_version="$default_initial_version"
fi

latest_tag="$(git tag -l "${chart_name}-v*" | sort -V | tail -n1 || true)"
if [[ -n "$latest_tag" ]]; then
  latest_version="${latest_tag#${chart_name}-v}"
else
  latest_version=""
fi

if [[ -z "$latest_version" ]]; then
  next_release_version="$base_version"
elif version_gt "$base_version" "$latest_version"; then
  next_release_version="$base_version"
else
  next_release_version="$(increment_patch "$latest_version")"
fi

if [[ "$mode" == "ci" ]]; then
  printf '%s-ci.%s' "$next_release_version" "${GITHUB_RUN_NUMBER:-0}"
else
  printf '%s' "$next_release_version"
fi
