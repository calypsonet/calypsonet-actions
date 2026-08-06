#!/usr/bin/env bash
#
# Prepares the "doc" branch of a specification repository:
#   - installs the freshly generated artifacts under <version>/
#   - records metadata for that version in <version>/version.yml
#   - refreshes the latest-stable/ alias (files keep their published name)
#   - regenerates index.md, whose front matter carries the full version list
#
# Presentation is NOT handled here: index.md only exposes data and delegates
# rendering to the Jekyll include "specification-versions.html", which lives in
# the central documentation repository (_includes/ of its gh-pages branch).
# Re-styling the page therefore never requires releasing this actions repo.
#
# Usage: prepare_specification.sh <repo_name> <spec_version> <spec_full_name>

set -euo pipefail
shopt -s nullglob

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <repo_name> <spec_version> <spec_full_name>" >&2
  exit 2
fi

repo_name=$1
spec_version=$2
spec_full_name=$3

# The HTML/PDF/SVG artifacts are produced by the reusable spec workflow in the
# workspace root, i.e. next to the clone we are about to create. Resolve the
# path BEFORE changing directory. Overridable for local testing.
: "${GENERATED_DIR:=$(pwd)/generated}"

# Where to clone the specification repositories from. Overridable for testing.
: "${SPEC_REPO_BASE_URL:=https://github.com/calypsonet}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Size in bytes, portable.
file_size() {
  stat -c%s "$1" 2>/dev/null || wc -c <"$1" | tr -d ' '
}

# Human readable size, e.g. "1.4 MB" / "812 kB".
human_size() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1048576) printf "%.1f MB", b / 1048576;
    else              printf "%d kB", (b + 1023) / 1024;
  }'
}

# List directories that look like a published version (name starts with a
# digit), e.g. "1.0.0" or "1.2.0-SNAPSHOT". This deliberately excludes Jekyll
# and asset directories carried by the doc branch (_layouts, media,
# latest-stable, ...), which must never be mistaken for a version.
version_dirs() {
  local d
  for d in */; do
    d=${d%/}
    case $d in [0-9]*) printf '%s\n' "$d" ;; esac
  done
}

# Emit the YAML metadata block for one version directory.
write_version_yml() {
  local dir=$1
  local status="stable"
  case $dir in *-SNAPSHOT) status="snapshot" ;; esac

  local diagram="" html="" pdf=""
  for f in "$dir"/class-diagram.svg "$dir"/api_class_diagram.svg; do
    [ -f "$f" ] && diagram=$(basename "$f") && break
  done
  for f in "$dir"/*.html; do html=$(basename "$f"); break; done
  for f in "$dir"/*.pdf;  do pdf=$(basename "$f");  break; done

  {
    printf '  - version: "%s"\n'  "$dir"
    printf '    status: %s\n'     "$status"
    printf '    files:\n'
    if [ -n "$diagram" ]; then
      printf '      diagram:\n'
      printf '        name: "%s"\n' "$diagram"
      printf '        size: "%s"\n' "$(human_size "$(file_size "$dir/$diagram")")"
    fi
    if [ -n "$html" ]; then
      printf '      html:\n'
      printf '        name: "%s"\n' "$html"
      printf '        size: "%s"\n' "$(human_size "$(file_size "$dir/$html")")"
    fi
    if [ -n "$pdf" ]; then
      printf '      pdf:\n'
      printf '        name: "%s"\n' "$pdf"
      printf '        size: "%s"\n' "$(human_size "$(file_size "$dir/$pdf")")"
    fi
  } >"$dir/version.yml"
}

# ---------------------------------------------------------------------------
# Fetch the doc branch
# ---------------------------------------------------------------------------

echo "Cloning $repo_name (branch doc) from $SPEC_REPO_BASE_URL ..."
git clone --branch doc --single-branch "$SPEC_REPO_BASE_URL/$repo_name.git"
cd "$repo_name"

# ---------------------------------------------------------------------------
# Install the new version
# ---------------------------------------------------------------------------

echo "Removing previous SNAPSHOT directories..."
for d in *-SNAPSHOT; do rm -rf -- "$d"; done

echo "Installing artifacts into $spec_version/..."
mkdir -p "$spec_version"

for ext in svg html pdf; do
  case $ext in
    svg) src="$GENERATED_DIR/class-diagram.svg"    ; dst="$spec_version/class-diagram.svg" ;;
    *)   src="$GENERATED_DIR/$spec_full_name.$ext" ; dst="$spec_version/$spec_full_name.$ext" ;;
  esac
  if [ -f "$src" ]; then
    cp -f "$src" "$dst"
    echo "  + $(basename "$dst")"
  else
    echo "  ! missing artifact: $(basename "$src")" >&2
  fi
done

# ---------------------------------------------------------------------------
# Per-version metadata (version.yml), written once per version directory
# ---------------------------------------------------------------------------

# The version being published: (re)write for SNAPSHOTs (their content evolves)
# or when no metadata exists yet. Existing metadata is left untouched to keep
# the doc branch diff minimal; version.yml content is deterministic anyway.
case $spec_version in
  *-SNAPSHOT) write_version_yml "$spec_version" ;;
  *) [ -f "$spec_version/version.yml" ] || write_version_yml "$spec_version" ;;
esac

# Backfill the other versions exactly once (idempotent across runs).
for dir in $(version_dirs); do
  [ -f "$dir/version.yml" ] || { echo "Backfilling metadata for $dir..."; write_version_yml "$dir"; }
done

# ---------------------------------------------------------------------------
# latest-stable/ alias, with published file names preserved
# ---------------------------------------------------------------------------

latest_stable=$(version_dirs | grep -v SNAPSHOT | sort -Vr | head -n 1) || true

rm -rf latest-stable
if [ -n "$latest_stable" ]; then
  echo "Refreshing latest-stable/ -> $latest_stable"
  mkdir -p latest-stable
  # Documents keep their published name: the date prefix is part of their identity.
  for f in "$latest_stable"/*; do
    case $(basename "$f") in version.yml) continue ;; esac
    cp -f "$f" latest-stable/
  done
fi

# ---------------------------------------------------------------------------
# Regenerate index.md (data only; presentation lives in the Jekyll include)
# ---------------------------------------------------------------------------

echo "Regenerating index.md..."
{
  printf -- '---\n'
  printf 'layout: default\n'
  printf 'title: "%s"\n' "$repo_name"
  printf 'repository: "%s"\n' "$repo_name"
  printf 'latest_stable: "%s"\n' "$latest_stable"
  printf 'versions:\n'
  for dir in $(version_dirs | sort -Vr); do
    [ -f "$dir/version.yml" ] && cat "$dir/version.yml"
  done
  printf -- '---\n\n'
  printf '{%% include specification-versions.html %%}\n'
} >index.md

# The former Markdown table is obsolete now that data lives in the front matter.
rm -f list_versions.md

echo "Generated index.md:"
cat index.md

cd ..
echo "Local docs update finished."
