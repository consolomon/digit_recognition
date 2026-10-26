:<<"::CMDLITERAL"
@echo off
setlocal
rem Windows launcher: runs the bash part of this file with Git for Windows bash.exe
set "GF_BASH="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined GF_BASH if exist "%%~dpG..\bin\bash.exe" set "GF_BASH=%%~dpG..\bin\bash.exe"
if not defined GF_BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "GF_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GF_BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GF_BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined GF_BASH echo ERROR: Git for Windows is not installed - get it from https://git-scm.com/download/win 1>&2
if not defined GF_BASH exit /b 1
set "GF_SELF=%~f0"
set "GF_SELF=%GF_SELF:\=/%"
set "GF_IGNCR="
"%GF_BASH%" -o igncr -c "exit 0" >nul 2>&1 && set "GF_IGNCR=-o igncr"
"%GF_BASH%" %GF_IGNCR% "%GF_SELF%" %*
set "GF_RC=%errorlevel%"
echo %cmdcmdline% | find /i "%~nx0" >nul && pause
exit /b %GF_RC%
::CMDLITERAL
# Share your work: open (or update) a pull request dev/<dev> -> master.
#
#   win\promote_master.cmd
#   win\promote_master.cmd --help
#
#   --help   show this help
#
# master is the team's controlled sharing display: nobody pushes to it
# directly, the tutor reviews and merges pull requests in GitHub. Steps:
#   1. checks: gh installed and logged in, no uncommitted changes,
#      dev/<dev> pushed (offers the push when it is ahead of origin)
#   2. an open PR dev/<dev> -> master: its title is updated to the current version;
#      otherwise a new PR "<VERSION> merge: dev/<dev> -> master" listing the commits
#   3. prints the PR link and whether GitHub can merge it cleanly
# Conflicts between developers' independent versions are expected and are the
# tutor's business, not yours. You end on dev/<dev>.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.cmd"

case "${1:-}" in
  "") ;;
  --help|-h) gf_help; exit 0 ;;
  *) gf_help >&2; exit 2 ;;
esac

gf_root
need_cmd gh "https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh is not logged in — run: gh auth login"
DEVB="$(dev_branch)"

info "checks"
require_clean_tree
[ "$(current_branch)" = "$DEVB" ] || git checkout -q "$DEVB"
ensure_pushed "$DEVB"

V="$(git show "origin/$DEVB:VERSION" | tr -d '[:space:]')"
TITLE="$V merge: $DEVB → master"
COMMITS="$(git log --no-merges --format='- %h %s' "origin/master..origin/$DEVB" | head -n 50)"
[ -n "$COMMITS" ] || { echo "master already contains everything on $DEVB — no pull request needed"; exit 0; }

info "pull request $DEVB -> master"
PR="$(gh pr list --base master --head "$DEVB" --state open --json number --jq '.[0].number' 2>/dev/null || true)"
if [ -n "$PR" ]; then
  gh pr edit "$PR" --title "$TITLE" >/dev/null
  echo "updated PR #$PR: $TITLE"
else
  BODY="$(printf 'Work of %s, version %s.\n\nCommits not yet on master:\n%s\n' "$DEVB" "$V" "$COMMITS")"
  gh pr create --base master --head "$DEVB" --title "$TITLE" --body "$BODY"
  PR="$(gh pr list --base master --head "$DEVB" --state open --json number --jq '.[0].number')"
fi
gh pr view "$PR" --json url,mergeable --jq '"link: \(.url)\nmergeable: \(.mergeable)"' || true
info "on $DEVB — the tutor reviews and merges the PR"
