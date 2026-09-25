#!/bin/bash
# engineering-rules status line, two rows. The first says where you are: directory, git
# branch and dirty state, and the model. The second holds the meters: the context in use,
# session uptime, the claude.ai plan usage and how often the conversation was compacted; it is
# left out while all are empty.
# Receives Claude Code's status-line JSON on stdin; install.sh points settings.json's
# statusLine here.
# It is re-rendered continuously, so the compaction scan keeps a cursor per transcript and
# reads only the bytes added since the last render. Runs on the bash macOS ships (3.2).

ESC=$'\033'
reset="${ESC}[0m"
bold_green="${ESC}[1;32m"
green="${ESC}[0;32m"
bold_cyan="${ESC}[1;36m"
bold_blue="${ESC}[1;34m"
red="${ESC}[0;31m"
yellow="${ESC}[0;33m"
bold_magenta="${ESC}[1;35m"
dim="${ESC}[2m"
gray="${ESC}[0;90m"
CACHE_DIR="${TMPDIR:-/tmp}"
# Claude Code writes one transcript line carrying COMPACT_MARKER per compaction. A copy quoted
# inside a message or a tool result has its quotes escaped, so it never matches.
COMPACT_MARKER='"subtype":"compact_boundary"'
AUTO_TRIGGER='"trigger":"auto"'

# One jq call for every field, one field per line, so an empty field keeps its place.
read_status_fields() {
  printf '%s' "$1" | jq -r '.cwd // .workspace.current_dir // "", .transcript_path // "", .model.display_name // "",
    (.context_window.used_percentage, .rate_limits.five_hour.used_percentage, .rate_limits.seven_day.used_percentage
      | . // "" | tostring)' 2>/dev/null
}

render_git_segment() {
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$branch" ] || return 0
  dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  printf '  %sgit:(%s%s%s)%s' "$bold_blue" "$red" "$branch" "$bold_blue" "$reset"
  [ -n "$dirty" ] && printf ' %s✗%s' "$yellow" "$reset"
  return 0
}

render_model_segment() {
  [ -n "$model_name" ] || return 0
  printf '  %s│%s %s%s%s' "$gray" "$reset" "$bold_magenta" "$model_name" "$reset"
}

# level_color <percent>: green, yellow from 50, red from 75.
level_color() {
  if [ "$1" -ge 75 ]; then printf '%s' "$red"
  elif [ "$1" -ge 50 ]; then printf '%s' "$yellow"
  else printf '%s' "$green"
  fi
}

# format_meter <label> <percent>: " ctx:42%", the label dim and the percentage coloured by
# level_color; nothing when Claude Code sent no percentage or one that is not a number.
format_meter() {
  [ -n "$2" ] || return 0
  pct=$(printf '%.0f' "$2" 2>/dev/null) || return 0
  printf ' %s%s:%s%s%s%%%s' "$dim" "$1" "$reset" "$(level_color "$pct")" "$pct" "$reset"
}

# The share of the context window in use, "ctx:42%".
render_context_segment() {
  meter=$(format_meter ctx "$used_pct")
  [ -n "$meter" ] || return 0
  printf '  %s│%s%s' "$gray" "$reset" "$meter"
}

# BSD date first (macOS), GNU date second (Linux); empty when neither can parse it.
read_epoch() {
  clean_ts=$(printf '%s' "$1" | sed -E 's/\.[0-9]+Z$/Z/')
  date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$clean_ts" "+%s" 2>/dev/null || date -u -d "$clean_ts" +%s 2>/dev/null
}

format_duration() {
  elapsed=$1
  [ "$elapsed" -lt 0 ] && elapsed=0
  days=$(( elapsed / 86400 ))
  hrs=$(( (elapsed % 86400) / 3600 ))
  mins=$(( (elapsed % 3600) / 60 ))
  secs=$(( elapsed % 60 ))
  if [ "$days" -gt 0 ]; then printf '%dd %dh %dm' "$days" "$hrs" "$mins"
  elif [ "$hrs" -gt 0 ]; then printf '%dh %dm' "$hrs" "$mins"
  elif [ "$mins" -gt 0 ]; then printf '%dm %ds' "$mins" "$secs"
  else printf '%ds' "$secs"
  fi
}

# Elapsed wall time since the first timestamp in the transcript.
render_session_segment() {
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || return 0
  start_ts=$(head -n 200 "$transcript_path" 2>/dev/null | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | head -n 1)
  [ -n "$start_ts" ] || return 0
  start_epoch=$(read_epoch "$start_ts")
  [ -n "$start_epoch" ] || return 0
  printf '  %s│%s %sup %s%s' "$gray" "$reset" "$dim" "$(format_duration $(( $(date -u +%s) - start_epoch )))" "$reset"
}

# transcript_cache <scan>: the cursor file one scan keeps for this transcript.
transcript_cache() {
  printf '%s/engineering-rules-%s-%s' "$CACHE_DIR" "$1" "$(printf '%s' "$transcript_path" | cksum | cut -d ' ' -f 1)"
}

# read_bytes <offset> <count>: that slice of the transcript. dd moves the shared descriptor to
# the offset without reading, where tail -c +N crawls through a large file on macOS.
read_bytes() {
  { dd bs=1 skip="$1" count=0 2>/dev/null; head -c "$2"; } < "$transcript_path"
}

# ends_on_a_line <size>: the transcript's byte before <size> is a newline, so no line is half written.
ends_on_a_line() {
  [ -z "$(read_bytes $(( $1 - 1 )) 1)" ]
}

# The claude.ai plan's rolling five-hour window and its weekly one. Claude Code sends them for
# Pro and Max once the first response is in, and may send either window without the other.
render_usage_segment() {
  usage="$(format_meter 5h "$five_hour_pct")$(format_meter 7d "$seven_day_pct")"
  [ -n "$usage" ] || return 0
  printf '  %s│%s%s' "$gray" "$reset" "$usage"
}

# is_count <value>...: every value is a whole number.
is_count() {
  for value in "$@"; do
    case "$value" in ''|*[!0-9]*) return 1 ;; esac
  done
}

# tally_compactions: transcript lines on stdin, "<compactions> <automatic ones>" on stdout.
tally_compactions() {
  LC_ALL=C grep -F "$COMPACT_MARKER" | awk -v mark="$AUTO_TRIGGER" 'index($0, mark) { n++ } END { printf "%d %d", NR, n }'
}

# How often this conversation was compacted, "compacted 3x (2 auto)", hidden until the first.
# The cursor file holds "<bytes counted> <compactions> <automatic ones>". A render counts only
# the bytes added since and waits while the last line is still being written, so no
# compaction is counted twice or split between two renders.
render_compact_segment() {
  [ -n "$transcript_path" ] && [ -f "$transcript_path" ] || return 0
  cache=$(transcript_cache compactions)
  size=$(wc -c < "$transcript_path" | tr -d ' ')
  offset=0 total=0 auto=0
  [ -f "$cache" ] && read -r offset total auto < "$cache"
  if ! is_count "$offset" "$total" "$auto" || [ "$size" -lt "$offset" ]; then offset=0 total=0 auto=0; fi
  if [ "$size" -gt "$offset" ] && ends_on_a_line "$size"; then
    read -r added added_auto <<< "$(read_bytes "$offset" $(( size - offset )) | tally_compactions)"
    total=$(( total + added )) auto=$(( auto + added_auto ))
    printf '%s %s %s\n' "$size" "$total" "$auto" > "$cache" 2>/dev/null
  fi
  [ "$total" -gt 0 ] || return 0
  note=""
  [ "$auto" -gt 0 ] && note=" ($auto auto)"
  printf '  %s│%s %scompacted %sx%s%s' "$gray" "$reset" "$dim" "$total" "$note" "$reset"
}

input=$(cat)
{
  IFS= read -r cwd; IFS= read -r transcript_path; IFS= read -r model_name
  IFS= read -r used_pct; IFS= read -r five_hour_pct; IFS= read -r seven_day_pct
} <<< "$(read_status_fields "$input")"
[ -n "$cwd" ] || cwd=$(pwd)
project_name=${cwd##*/}
printf '%s➜%s %s%s%s%s%s\n' "$bold_green" "$reset" "$bold_cyan" "$project_name" "$reset" \
  "$(render_git_segment)" "$(render_model_segment)"
# Every meter opens with "  │ "; the row drops the one in front of its first meter.
meters="$(render_context_segment)$(render_session_segment)$(render_usage_segment)$(render_compact_segment)"
if [ -n "$meters" ]; then printf '%s\n' "${meters#"  $gray"*"$reset "}"; fi
