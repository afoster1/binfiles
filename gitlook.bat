@echo off
rem Script Parameters:
rem 1. The optional filename search term

rem Get the search term
if "%~1"=="" (
    set searchtermvar=.*
) else (
    set searchtermvar=%1
)

setlocal enabledelayedexpansion

for /F "tokens=* USEBACKQ" %%A in (`bash -c "git --no-pager log -v --name-only --date=short --pretty=format:\"%%h %%ad %%an\" | awk '/^[0-9a-f]{7,40}[[:space:]]/ { hash = $1; date = $2; author = substr($0, length($1) + length($2) + 3); next } NF > 0 { print hash, date, author, $0 }'" ^
| rg --ignore-case --color=never --no-heading %searchtermvar% ^
| fzf -m --ansi --color "hl:-1:underline,hl+:-1:underline:reverse"  --delimiter " " --bind "shift-up:preview-up,shift-down:preview-down,ctrl-u:preview-page-up,ctrl-d:preview-page-down" --preview "bash -c 'git log --name-only -v {1} -1'" --preview-window "right:40%%,border-left"`) do @echo %%A
