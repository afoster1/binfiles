@echo off
set p4Client=%1
set changeList=%2
set fileSpec=%3
set useGui=%4
if [%changeList%]==[] set %changeList=default
if [%fileSpec%]==[] set %fileSpec=...

if [%useGui%]==[] goto :cmd
    for /f "usebackq delims=#" %%F in (`p4 -c %p4Client% opened -c %changeList% %fileSpec%`) do (
        "c:\program files\perforce\p4vc" -c %p4Client% diff "%%F"
        pause
    )
    goto :eof
:cmd
    for /f "usebackq delims=#" %%F in (`p4 -c %p4Client% opened -c %changeList% %fileSpec%`) do @p4 -c %p4Client% diff -du5 "%%F"
