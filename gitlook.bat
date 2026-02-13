@echo off
rem Script Parameters:
rem 1. The optional filename search term

rem Get the search term
if "%~1"=="" (
    set "searchtermvar="
) else (
    set "searchtermvar=%1"
)



setlocal

rem Detect Git version to determine escaping behavior
for /F "tokens=3 delims= " %%V in ('git --version') do set gitVersion=%%V
for /F "tokens=1,2 delims=." %%A in ("%gitVersion%") do (
    set gitMajor=%%A
    set gitMinor=%%B
)

rem Check if Git version is older than 2.48
set oldEscapingBehaviour=false
if %gitMajor% LSS 2 set oldEscapingBehaviour=true
if %gitMajor% EQU 2 if %gitMinor% LSS 48 set oldEscapingBehaviour=true

if "%oldEscapingBehaviour%"=="true" (
    rem Older Git versions require different escaping
    set "awkCommand=awk 'BEGIN { FS = \"\\t\" } NF == 3 { hash = $1; date = $2; author = $3; next } NF > 0 { print hash, date, author, $0 }'"
) else (
    rem Newer Git versions handle escaping differently
    set "awkCommand=awk 'BEGIN { FS = \"\\t\" } NF == 3 { hash = \$1; date = \$2; author = \$3; next } NF > 0 { print hash, date, author, \$0 }'"
)

if "%searchtermvar%"=="" (
    for /F "tokens=* USEBACKQ" %%A in (`bash -c "git --no-pager log -v --name-only --date=short --pretty=format:\"%%h%%x09%%ad%%x09%%an\" | %awkCommand%" 
        ^| fzf -m --ansi --color "hl:-1:underline,hl+:-1:underline:reverse"  --delimiter " " --bind "shift-up:preview-up,shift-down:preview-down,ctrl-u:preview-page-up,ctrl-d:preview-page-down" --preview "bash -c 'git log --name-only -v {1} -1'" --preview-window "right:40%%,border-left"`) do @echo %%A
) else (
    for /F "tokens=* USEBACKQ" %%A in (`bash -c "git --no-pager log -v --name-only --date=short --pretty=format:\"%%h%%x09%%ad%%x09%%an\" | %awkCommand%" 
        ^| rg --ignore-case --color=never --no-heading %searchtermvar% ^
        ^| fzf -m --ansi --color "hl:-1:underline,hl+:-1:underline:reverse"  --delimiter " " --bind "shift-up:preview-up,shift-down:preview-down,ctrl-u:preview-page-up,ctrl-d:preview-page-down" --preview "bash -c 'git log --name-only -v {1} -1'" --preview-window "right:40%%,border-left"`) do @echo %%A
)
