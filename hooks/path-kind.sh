#!/bin/bash
# Used by the code-rules hook and the risk-zone guard: the path as the project knows it, and
# what kind of file it names, by the law's own definitions (the code rules, production code)
# and the law scout's globs (9.5).
# File-name globs look at the name alone and directory globs at the path, so a directory
# that happens to be called `x.test.y` does not turn everything under it into a test file.

# path_kind <path>: prose, generated, test or code.
path_kind() {
  name=${1##*/}
  case "$name" in
    *.md|*.mdx|*.markdown|*.txt|*.rst|*.adoc|*.log|*.csv|*.svg|LICENSE*) printf prose; return ;;
    *.generated.*|*.min.js|*.min.css|*.lock|package-lock.json|*.snap) printf generated; return ;;
  esac
  case "$1" in
    */docs/*|docs/*) printf prose; return ;;
    */node_modules/*|node_modules/*|*/dist/*|dist/*|*/build/*|build/*|*/vendor/*|vendor/*|*/migrations/*|migrations/*|*/generated/*|generated/*) printf generated; return ;;
    */tests/*|tests/*|*/test/*|test/*|*/spec/*|spec/*|*/__tests__/*|__tests__/*) printf test; return ;;
  esac
  case "$name" in
    *.test.*|*.spec.*|*_test.*|*_spec.*|test_*) printf test ;;
    *) printf code ;;
  esac
}

# relative_path <path> <cwd>: the path as the project knows it, so the role, test, language and
# folder globs see the name a diff would show: relative to the git root, else to the session's
# cwd, else the file name alone. Directories are resolved physically from the nearest one that
# exists (a new file's folder may not yet, and its name is judged too), so a symlinked temp dir
# matches, and a result that still climbs with `..` falls back to the name alone, so nothing
# lands outside.
relative_path() {
  dir=${1%/*}
  [ "$dir" = "$1" ] && dir=.
  near=$dir
  while [ ! -d "$near" ]; do case "$near" in */*) near=${near%/*} ;; *) near=.; break ;; esac; done
  rest=${dir#"$near"}
  physical="$(cd "$near" 2>/dev/null && pwd -P)${rest:+/${rest#/}}/${1##*/}"
  top=$(git -C "$near" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$top" ] && [ "${physical#"$top"/}" != "$physical" ]; then known=${physical#"$top"/}
  elif [ -n "$2" ] && [ "${1#"$2"/}" != "$1" ]; then known=${1#"$2"/}
  else known=${1##*/}
  fi
  case "/$known/" in */../*) known=${1##*/} ;; esac
  printf '%s' "$known"
}
