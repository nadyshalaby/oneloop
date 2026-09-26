#!/bin/bash
# Guard: every section the rule files cite has a page, and every page is reachable. A citation is
# an n.m with a major from 1 to 17 and a minor with no leading zero, with no word, digit, dot,
# dollar, slash or minus before it and no digit, decimal or unit after it (a full stop ends the
# sentence, not the number); the number in a references/ path; a group (15.x, "section 17"); or
# each member of a same-major range (6.3 to 6.11). Not counted: fenced code; a line that sets a
# design value (px, em, rgba(, cubic-bezier(, a {typography.} token, line-height), whose
# decimals are values; every 0.x, which reads as a value (CLS under 0.1, an alpha of 0.9) and
# has had no page since the orientation map went; and the tests, which quote old numbers on
# purpose. A page is reachable when a root (the law, the skills, the agents, the hooks, the
# settings, the bin scripts) or a reachable page cites it; 01-always-on-law/ is the
# law's long form and always live. Needs perl. ROOT_DIR points the test at another copy, for a
# watched failure. Run: bash tests/references.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=${ROOT_DIR:-$(repo_root)} || exit 1
command -v perl >/dev/null || { printf 'FAIL perl not found, nothing was scanned\n'; exit 1; }

# The program citations runs: one "file:line: n.m" row per citation, a group as n.x.
read -r -d '' CITES <<'PERL'
our $fence;
sub scan {
  my $unit = qr/^\s?(?:px|em|rem|ms|s|x|k|KB|MB|GB|mm|lb)\b|^\s?(?:\xC3\x97|%)|^:\d/;
  if (/^\s*```/) { $fence = !$fence; return }
  return if $fence;
  print "$ARGV:$.: $1\n" while m{references/[\w.-]+/(\d{1,2}\.\d{1,2})-}g;
  return if /\d(?:px|em)\b|rgba?\(|cubic-bezier\(|\{typography\.|line-?height/i;
  print "$ARGV:$.: ", ($1 // $2), ".x\n" while /\b(1[0-7]|[1-9])\.x\b|\b[Ss]ections? (1[0-7]|[1-9])\b(?!\d|\.\d)/g;
  while (/(?<![\w.\$\/-])(\d{1,2})\.([1-9]\d?) to \1\.([1-9]\d?)(?!\d|\.\d)/g) { print "$ARGV:$.: $1.$_\n" for $2 .. $3 }
  while (/(?<![\w.\$\/-])(1[0-7]|[1-9])\.([1-9]\d?)(?!\d|\.\d)/g) {
    print "$ARGV:$.: $1.$2\n" unless substr($_, pos($_)) =~ $unit;
  }
}
scan();
if (eof) { close ARGV; $fence = 0 }
PERL

# citations: every citation in the files named on stdin, one path per line.
citations() { tr '\n' '\0' | xargs -0 perl -ne "$CITES"; }

# page_numbers: the number of every reference page, space-separated.
page_numbers() {
  find "$ROOT/references" -name '*.md' | sed -E 's#.*/([0-9]+\.[0-9]+)-[^/]*$#\1#' | sort -u | tr '\n' ' '
}

# dangling: the citation rows, from the files named on stdin, whose page or group does not exist.
dangling() {
  citations | awk -v have="$(page_numbers)" '
    BEGIN { n = split(have, h, " "); for (i = 1; i <= n; i++) { page[h[i]] = 1; split(h[i], m, "."); page[m[1] ".x"] = 1 } }
    !($NF in page) { print }'
}

# roots: the files that load on their own; a page is read only because a root or a read page cites it.
roots() {
  ls "$ROOT"/law/*.md "$ROOT"/skills/*/SKILL.md "$ROOT"/agents/*.md "$ROOT"/hooks/*.sh \
    "$ROOT"/settings/* "$ROOT"/bin/*.sh
}

# rule_files: every file the dangling check reads, the roots, the README and the pages.
rule_files() { roots; printf '%s\n' "$ROOT/README.md"; find "$ROOT/references" -name '*.md'; }

# new_pages <cited> <seen>: the pages not yet seen whose number or group is in the cited list.
new_pages() {
  find "$ROOT/references" -name '*.md' | grep -vxF -f <(printf '%s\n' "$2" | sed '/^$/d') \
    | while IFS= read -r p; do
      n=$(basename "$p" | sed -E 's/^([0-9]+\.[0-9]+)-.*/\1/')
      if printf '%s\n' "$1" | grep -qxF -e "$n" -e "${n%%.*}.x"; then printf '%s\n' "$p"; fi
    done
}

# unreached: the pages no chain of citations from the roots reaches.
unreached() {
  seen=$(find "$ROOT/references/01-always-on-law" -name '*.md')
  front=$(roots; printf '%s\n' "$seen")
  while [ -n "$front" ]; do
    cited=$(printf '%s\n' "$front" | citations | sed 's/.*: //' | sort -u)
    front=$(new_pages "$cited" "$seen")
    seen=$(printf '%s\n%s' "$seen" "$front" | sed '/^$/d')
  done
  find "$ROOT/references" -name '*.md' | grep -vxF -f <(printf '%s\n' "$seen") | sed "s#^$ROOT/##"
}

test_every_cited_section_has_a_page() {
  assert_eq "every cited section has a page" "" "$(rule_files | dangling | sed "s#^$ROOT/##")"
}

test_every_page_is_reachable() {
  assert_eq "every page is reachable from the roots" "" "$(unreached)"
}

# The check can fail: two mentions of missing pages and a missing group are named, and the
# values that look like numbers (a type scale, an alpha, an easing, a line height, a web vital,
# a size, a ratio, a factor, fenced code) stay quiet.
test_a_planted_missing_page_is_named() {
  cat > "$WORK/planted.md" <<'EOF'
The ledger (5.1) and the map (4.4, step 2) went, and so did the spec review (8.x).
| `{typography.display-xl}` | 54px | 600 | 1.12 | -0.8px | Page hero |
- The lit top edge: `inset 0 1px 0 rgba(255,255,255,0.9)` on every raised surface.
The standard easing is `cubic-bezier(0.4, 0, 0.2, 1)` for everything.
- Keep line-height at 1.65 or more on body copy.
- [ ] Lighthouse run: LCP under 2.5s, INP under 200ms, CLS under 0.1.
It is how a readable 2.3MB file once reported as clean, at 4.1× the time and a 4.5:1 contrast.
- Three classes and a factory to multiply by `0.9`.
```
the old ledger lived in (5.2)
```
EOF
  out=$(printf '%s\n' "$WORK/planted.md" | dangling | sed "s#^$WORK/##" | sort | tr '\n' ' ')
  assert_eq "only the planted mentions are named" "planted.md:1: 4.4 planted.md:1: 5.1 planted.md:1: 8.x " "$out"
}

# The walk can fail: a page nothing cites is named, and the same page stops being named once a
# page the roots reach cites it.
test_a_planted_orphan_is_named() {
  mkdir -p "$WORK/tree"
  cp -R "$ROOT"/law "$ROOT"/skills "$ROOT"/agents "$ROOT"/hooks "$ROOT"/settings \
    "$ROOT/bin" "$ROOT/references" "$WORK/tree/"
  printf '# 14.9 [ref] Nobody points here\n' > "$WORK/tree/references/14-anti-patterns/14.9-nobody-points-here.md"
  orphan=$(ROOT="$WORK/tree"; unreached)
  assert_eq "a page nothing cites is named" "references/14-anti-patterns/14.9-nobody-points-here.md" "$orphan"
  printf 'See also 14.9.\n' >> "$(find "$WORK/tree/references" -name '14.1-*.md')"
  assert_eq "a page cited through a reached page is not" "" "$(ROOT="$WORK/tree"; unreached)"
}

test_every_cited_section_has_a_page
test_every_page_is_reachable
test_a_planted_missing_page_is_named
test_a_planted_orphan_is_named
report
