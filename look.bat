@echo off
rem Script Parameters:
rem 1. The search term
rem 2. The vim server name to use, or GVIM by default.

rem Get the process group name
if "%~2"=="" (
    set servernamevar=GVIM
) else (
    set servernamevar=%2
)

rem Define how long to wait between opening multiple files
set gvim_wait_period_secs=10

rem Start of "strLen" macro.
set LF=^


::Above 2 blank lines are required - do not remove
@set ^"\n=^^^%LF%%LF%^%LF%%LF%^^":::: StrLen pResult pString
set $strLen=for /L %%n in (1 1 2) do if %%n==2 (%\n%
        for /F "tokens=1,2 delims=, " %%1 in ("!argv!") do (%\n%
            set "str=A!%%~2!"%\n%
              set "len=0"%\n%
              for /l %%A in (12,-1,0) do (%\n%
                set /a "len|=1<<%%A"%\n%
                for %%B in (!len!) do if "!str:~%%B,1!"=="" set /a "len&=~1<<%%A"%\n%
              )%\n%
              for %%v in (!len!) do endlocal^&if "%%~b" neq "" (set "%%~1=%%v") else echo %%v%\n%
        ) %\n%
) ELSE setlocal enableDelayedExpansion ^& set argv=,
rem End of "strLen" macro.

setlocal enabledelayedexpansion

rem Invoke ripgrep, fzf and bat to find the search term
set "started="
set "timeout_done="
@for /F "tokens=* USEBACKQ" %%A in (`rg --ignore-case --color=always --line-number --no-heading %1 ^
| fzf -m --ansi --color "hl:-1:underline,hl+:-1:underline:reverse"  --delimiter ":" --preview "bat --color=always --highlight-line {2} {1}" --preview-window "up,border-bottom,+{2}+3/3,~3"`) do (
    set "_input=%%A"
    
    rem Ensure the output hasn't got any problematic characters
    rem set "_input=Th""i\s&& is not good _maybe_!~*???"
    set "_output="
    set "map=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890\\.-_:"
    %$strLen% len _input
    for /L %%n in (0 1 !len!) DO (
        for /F "delims=*~ eol=*" %%C in ("!_input:~%%n,1!") do (
            if "!map:%%C=!" NEQ "!map!" set "_output=!_output!%%C"
        )
    )
    
    rem Extract the filename and line number.
    for /F "tokens=1-3 delims=:" %%B in ("!_output!") do (
        set "filename=%%B"
        set "line=%%C"
    )
    
    if not "!filename!"=="" (
        if not defined started (
            set "started=1"
            call gvim --servername %servernamevar% --remote-tab-silent +!line! "!filename!"
        ) else (
	    rem It shouldn't take this long to open gvim.... but it does, sigh.
            if not defined timeout_done (
                set "timeout_done=1"
                timeout /t %gvim_wait_period_secs% /nobreak >nul
            )
            call gvim --servername %servernamevar% --remote-tab-wait-silent +!line! "!filename!"
        )
    )
)
