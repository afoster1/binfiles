@echo off
rem Script Parameters:
rem 1. Name of bundle to create.

rem Get the directory name, date and time.
if "%~1"=="" (
    @for %%I in (.) do set dirnamevar=%%~nxI
) else (
    set dirnamevar=%1
)
@for /F "tokens=1-3 delims=/- " %%A in ('date /T') do @set datevar=%%C%%B%%A
@for /F "tokens=1-3 delims=:-. " %%A in ('echo %time%') do @set timevar=%%A%%B%%C&set hour=%%A
@if %hour% LSS 10 set timevar=0%timevar%
@set filename=%datevar%_%timevar%_%dirnamevar%.bundle
git bundle create ..\%filename% --all
