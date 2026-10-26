#!/usr/bin/env bash
# Regenerate the macOS and Windows copies of the gitflow scripts from linux/.
#
#   scripts/gitflow/make_variants.sh          (from anywhere; kit tooling, not shipped)
#
# linux/*.sh is the one source to edit; this writes
#   macos/<name>.tool  same bash code (written for bash 3.2 + BSD tools), its
#                      own paths (macos/<name>.tool); executable, so a
#                      double-click opens it in Terminal
#   win/<name>.cmd     a cmd.exe launcher that finds Git for Windows' bash.exe
#                      and runs the rest of the same file with it, then the
#                      bash code with win\<name>.cmd paths
# Own-folder mentions are rewritten (linux/x.sh, linux/, x.sh); lists of all
# three folders and lines naming the VPS (always Linux) stay as they are.
# The README.md files are written by hand, never generated.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v perl >/dev/null 2>&1 || { echo "ERROR: perl is required" >&2; exit 1; }

WIN_LAUNCHER=':<<"::CMDLITERAL"
@echo off
setlocal
rem Windows launcher: runs the bash part of this file with Git for Windows bash.exe
set "GF_BASH="
for /f "delims=" %%G in ('"'"'where git.exe 2^>nul'"'"') do if not defined GF_BASH if exist "%%~dpG..\bin\bash.exe" set "GF_BASH=%%~dpG..\bin\bash.exe"
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
::CMDLITERAL'

WIN_LIB_LAUNCHER=':<<"::CMDLITERAL"
@echo off
echo lib.cmd holds the helpers shared by the other win\*.cmd scripts - run one of those instead. 1>&2
exit /b 1
::CMDLITERAL'

# convert <src> <dest dir prefix> <ext> <win 0|1>  -> the converted text on stdout
convert() {
  GF_D="$2" GF_E="$3" GF_WIN="$4" perl -pe '
    BEGIN { ($D, $E, $W) = @ENV{qw(GF_D GF_E GF_WIN)} }
    s{linux/, macos/ and win/}{\@GF1\@}g; s{linux/, macos/ or win/}{\@GF2\@}g;
    s{linux/ macos/ win/}{\@GF3\@}g;     s{linux/ \(\.sh\), macos/ \(\.tool\), win/ \(\.cmd\)}{\@GF4\@}g;
    unless (/VPS/) {
      s{bash linux/([a-z_]+)\.sh}{win\\$1.cmd}g if $W;
      s{linux/([a-z_]+)\.sh}{$D$1.$E}g;
      s{linux/}{$D}g;
      s{\b([a-z_]+)\.sh\b}{$1.$E}g;
    }
    s{\@GF1\@}{linux/, macos/ and win/}g; s{\@GF2\@}{linux/, macos/ or win/}g;
    s{\@GF3\@}{linux/ macos/ win/}g;      s{\@GF4\@}{linux/ (.sh), macos/ (.tool), win/ (.cmd)}g;
  ' "$1"
}

mkdir -p "$KIT/macos" "$KIT/win"
n=0
for src in "$KIT"/linux/*.sh; do
  base="$(basename "$src" .sh)"
  # macOS: same file, own names; executable except the library
  convert "$src" "macos/" tool 0 > "$KIT/macos/$base.tool"
  if [ "$base" = lib ]; then chmod -x "$KIT/macos/$base.tool"; else chmod +x "$KIT/macos/$base.tool"; fi
  # Windows: the launcher replaces the shebang line
  {
    if [ "$base" = lib ]; then printf '%s\n' "$WIN_LIB_LAUNCHER"; else printf '%s\n' "$WIN_LAUNCHER"; fi
    convert "$src" 'win\' cmd 1 | sed '1{/^#!/d;}'
  } > "$KIT/win/$base.cmd"
  chmod -x "$KIT/win/$base.cmd"
  n=$((n + 1))
done
echo "generated $n macos/*.tool and $n win/*.cmd from linux/*.sh"
