#!/usr/bin/env bash
#
# Prepares the "doc" branch of a specification repository:
#   - installs the freshly generated artifacts under <version>/, all named after
#     the published document: <spec_full_name>.html, .pdf and -class-diagram.svg
#   - records metadata for that version in <version>/version.yml
#   - refreshes the latest-stable/ alias (files keep their published name);
#     when that version has an HTML specification, its copy as index.html makes
#     <repo>/latest-stable/ a fixed link, as on the Keyple and Keypop sites
#   - regenerates index.md, whose front matter carries the full version list
#
# Presentation is NOT handled here: index.md only exposes data and delegates
# rendering to the Jekyll include "specification-versions.html", which lives in
# the central documentation repository (_includes/ of its gh-pages branch).
# Re-styling the page therefore never requires releasing this actions repo.
#
# Usage: prepare_specification.sh <repo_name> <spec_version> <spec_full_name> [<doc_name>]
#   doc_name: human readable API name (the :doc-name: attribute of index.adoc),
#             shown on the documentation site instead of the repository name

set -euo pipefail
shopt -s nullglob

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <repo_name> <spec_version> <spec_full_name> [<doc_name>]" >&2
  exit 2
fi

repo_name=$1
spec_version=$2
spec_full_name=$3
doc_name=${4:-}

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
  # Any published diagram name: "<spec_full_name>-class-diagram.svg" (current),
  # "class-diagram.svg" and "api_class_diagram.svg" (former naming schemes, the
  # latter spelled with underscores).
  for f in "$dir"/*class-diagram*.svg "$dir"/*class_diagram*.svg; do
    diagram=$(basename "$f")
    break
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

# The directory is wiped first: a re-publication of the same version may carry
# different file names (document reference date, diagram name), and stale files
# must not survive next to the new ones.
echo "Installing artifacts into $spec_version/..."
rm -rf -- "$spec_version"
mkdir -p "$spec_version"

for ext in svg html pdf; do
  case $ext in
    svg) src="$GENERATED_DIR/class-diagram.svg"    ; dst="$spec_version/$spec_full_name-class-diagram.svg" ;;
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

# The version being published is always (re)written: its artifacts have just been
# installed, so its metadata must describe them. Other versions keep theirs, which
# keeps the doc branch diff minimal; version.yml content is deterministic anyway.
write_version_yml "$spec_version"

# Backfill the other versions exactly once (idempotent across runs).
for dir in $(version_dirs); do
  [ -f "$dir/version.yml" ] || { echo "Backfilling metadata for $dir..."; write_version_yml "$dir"; }
done

# ---------------------------------------------------------------------------
# latest-stable/ alias, with published file names preserved, and fixed link
# ---------------------------------------------------------------------------

latest_stable=$(version_dirs | grep -v SNAPSHOT | sort -Vr | head -n 1) || true
latest_stable_path=""

rm -rf latest-stable
if [ -n "$latest_stable" ]; then
  echo "Refreshing latest-stable/ -> $latest_stable"
  mkdir -p latest-stable
  # Documents keep their published name: the date prefix is part of their identity.
  for f in "$latest_stable"/*; do
    case $(basename "$f") in version.yml) continue ;; esac
    cp -f "$f" latest-stable/
  done

  # Fixed link, for versions published in the specification format only (HTML
  # to view online, HTML/PDF/SVG to download); former versions, with a class
  # diagram only, get none. Published names change with every release, so the
  # entry point is a copy of the HTML specification (self-contained, images are
  # embedded) as index.html: its anchors also work under latest-stable/#...
  html=""
  for f in latest-stable/*.html; do html=$f; break; done
  if [ -n "$html" ]; then
    cp -f "$html" latest-stable/index.html
    latest_stable_path="latest-stable/"
  fi
fi

# ---------------------------------------------------------------------------
# Regenerate index.md (data only; presentation lives in the Jekyll include)
# ---------------------------------------------------------------------------

echo "Regenerating index.md..."
# YAML double-quoted string: escape backslashes, then double quotes.
doc_name_yaml=${doc_name//\\/\\\\}
doc_name_yaml=${doc_name_yaml//\"/\\\"}
{
  printf -- '---\n'
  printf 'layout: default\n'
  printf 'title: "%s"\n' "$repo_name"
  printf 'repository: "%s"\n' "$repo_name"
  printf 'doc_name: "%s"\n' "$doc_name_yaml"
  printf 'latest_stable: "%s"\n' "$latest_stable"
  printf 'latest_stable_path: "%s"\n' "$latest_stable_path"
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
