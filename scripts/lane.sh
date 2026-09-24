#!/bin/bash
# engineering-rules lane picker.
# Picks the lane a planned change runs in from facts a machine can check, so the choice is never
# an opinion. The fast lane only when the project has a test command, at most 3 code files
# change (tests, docs and generated files do not count), no planned file is a risky kind (login
# or security, money, database, build or deploy settings, a screen or style file) and a test file
# comes with any code file. Anything else is the careful lane, named by the first fact that
# failed. Two facts stay with the plan because a path cannot show them: a line saying the change
# touches no money, login, state machine, migration, concurrency or data-loss code, and that it
# does not deploy; missing either one makes the change careful too.
#
# The kinds come from the files that define them: hooks/path-kind.sh (the law's test, prose and
# generated files, pinned to the law scout's globs) and 15.29's own UI and STYLE lists. A risky
# name is matched on the path's words (lower case, camelCase split, word starts), so
# `PasswordReset.ts` reads as password and `display.ts` never reads as pay.
#
# Usage: bash <er>/scripts/lane.sh --test "<the project's test command>" <planned file>...
#   Paths as the repository names them; pass --test "" when the project has none. <er> is
#   $ENGINEERING_RULES_HOME, else this script's own parent directory.
# Output: one line, `lane: fast` or `lane: careful: <the first fact that failed>`.
# Exit: 0 with either lane; 2 on a usage error (no --test, no planned file, an unknown option,
#   or a kind source that cannot be read), with a one-line message on stderr.
set -u

# usage_error <message>: the one-line stderr contract.
usage_error() {
  printf 'lane: %s\n' "$1" >&2
  exit 2
}

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
ER_HOME="${ENGINEERING_RULES_HOME:-$(cd -P "$here/.." && pwd)}"
PATH_KIND="$ER_HOME/hooks/path-kind.sh"
DESIGN_DOC="$ER_HOME/references/15-design/15.29-the-design-scout.md"
[ -r "$PATH_KIND" ] || usage_error "cannot read $PATH_KIND"
# shellcheck source=../hooks/path-kind.sh
. "$PATH_KIND"
# 15.29's UI and STYLE globs as bare extensions, one per line.
UI_EXTS=$(sed -n -E "s/^(UI|STYLE)='(.*)'\$/\\2/p" "$DESIGN_DOC" 2>/dev/null | tr ' ' '\n' | sed -n 's/^\*\.//p')
[ -n "$UI_EXTS" ] || usage_error "no UI or STYLE list in $DESIGN_DOC"

# words <path>: the path's words in lower case, camelCase split, space-padded.
words() {
  printf ' %s ' "$(printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' ' ')"
}

# build_file <name>: true when the file name is a dependency, build, CI or infra settings file.
build_file() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    package.json|package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|pnpm-workspace.yaml|bun.lock|bun.lockb) return 0 ;;
    requirements*.txt|pyproject.toml|setup.py|setup.cfg|poetry.lock|pipfile|pipfile.lock|gemfile|gemfile.lock) return 0 ;;
    go.mod|go.sum|cargo.toml|cargo.lock|composer.json|composer.lock|pom.xml|build.gradle*|settings.gradle*) return 0 ;;
    tsconfig*.json|*.config.js|*.config.ts|*.config.mjs|*.config.cjs|vercel.json|netlify.toml|fly.toml) return 0 ;;
    app.yaml|serverless.yml|serverless.yaml|.gitlab-ci.yml|.travis.yml|azure-pipelines.yml|bitbucket-pipelines.yml) return 0 ;;
    *.tf|*.tfvars|*.hcl) return 0 ;;
  esac
  return 1
}

# ui_file <path>: true when the path's extension is one of 15.29's UI or STYLE extensions.
ui_file() {
  ext=${1##*.}
  [ "$ext" != "$1" ] && printf '%s\n' "$UI_EXTS" | grep -qxF -- "$ext"
}

# risky_kind <path>: the risky kind the path is, nothing when it is none.
risky_kind() {
  case "$(words "$1")" in
    *" auth"*|*" login"*|*" logout"*|*" signin"*|*" signup"*|*" password"*|*" passwd"*|*" credential"*|*" session"*|*" token"*|*" jwt"*|*" oauth"*|*" saml "*|*" sso "*|*" secret"*|*" crypt"*|*" encrypt"*|*" decrypt"*|*" permission"*|*" acl "*|*" rbac "*|*" security"*|*" csrf "*)
      printf 'login or security'; return ;;
    *" payment"*|*" payout"*|*" paypal"*|*" billing"*|*" invoice"*|*" checkout"*|*" stripe"*|*" price"*|*" pricing"*|*" money"*|*" wallet"*|*" refund"*|*" subscription"*|*" ledger"*|*" currency"*|*" charge"*|*" tax "*|*" taxes "*)
      printf 'money'; return ;;
    *" migrat"*|*" schema"*|*" db "*|*" database"*|*" sql "*|*" prisma "*|*" alembic "*|*" flyway "*|*" liquibase "*|*" seed"*)
      printf 'database'; return ;;
    *" deploy"*|*" github "*|*" circleci "*|*" gitlab "*|*" buildkite "*|*" k8s "*|*" kubernetes "*|*" helm "*|*" terraform "*|*" ansible "*|*" infra "*|*" docker"*|*" jenkinsfile "*|*" procfile "*|*" makefile "*|*" env "*)
      printf 'build or deploy settings'; return ;;
  esac
  if build_file "${1##*/}"; then printf 'build or deploy settings'; return; fi
  if ui_file "$1"; then printf 'a screen or style file'; fi
}

# pick_lane <file>...: the lane line, from the facts in order; reads test_cmd.
pick_lane() {
  case "$test_cmd" in *[![:space:]]*) ;; *) echo 'lane: careful: the project has no test command'; return ;; esac
  code=0 tests=0
  for f; do
    case "$(path_kind "$f")" in code) code=$((code + 1)) ;; test) tests=$((tests + 1)) ;; esac
  done
  [ "$code" -le 3 ] || { echo "lane: careful: $code code files change, more than 3"; return; }
  for f; do
    kind=$(risky_kind "$f")
    [ -z "$kind" ] || { echo "lane: careful: $f is $kind"; return; }
  done
  [ "$code" -eq 0 ] || [ "$tests" -gt 0 ] || { echo 'lane: careful: code changes with no test file planned'; return; }
  echo 'lane: fast'
}

test_cmd='' have_test=0
while [ $# -gt 0 ]; do
  case "$1" in
    --test) [ $# -ge 2 ] || usage_error '--test needs the test command, "" when there is none'
            test_cmd=$2 have_test=1; shift 2 ;;
    --) shift; break ;;
    -*) usage_error "unknown option $1" ;;
    *) break ;;
  esac
done
[ "$have_test" -eq 1 ] || usage_error 'usage: lane.sh --test "<test command>" <planned file>...'
[ $# -gt 0 ] || usage_error 'no planned file'
pick_lane "$@"
