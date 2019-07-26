@echo off
rem Script parameters:
rem 1. Environment to initialise

@setlocal
@for /F "delims=" %%I in ("%~dp0..") do @set drive=%%~fI
@set drivep=%drive%
@if #%drive:~-1%# == #\# set drivep=%drive:~0,-1%
@endlocal

rem This environment variable is set when at least a single environment has
rem been initialised.  And is used to control the exit status.
set environment_initialised=0

if "%1" == "cppdev86" call :cppdev86 || goto :error
if "%1" == "cppdev64" call :cppdev64 || goto :error
if "%1" == "vs15ce86" goto :vs15ce86 || goto :error
if "%1" == "vs15ce64" goto :vs15ce64 || goto :error
if "%1" == "python27_86" goto :python27_86 || goto :error
if "%1" == "python37_86" goto :python37_86 || goto :error
if "%1" == "python37_64" goto :python37_64 || goto :error
if "%1" == "gpg" goto :gpg || goto :error

if %environment_initialised% EQU 0 goto :error
goto :success

:show_environment
set environment_name=%1
set environment_name=%environment_name:"=%
@echo Initialising %environment_name% environment.
set environment_initialised=1
goto :EOF

:cppdev86
call :vs15ce86 || goto :error
goto :EOF

:cppdev64
call :vs15ce64 || goto :error
goto :EOF

:vs15ce86
call :show_environment "vs15ce86"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio\2017\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" x86
goto :EOF

:vs15ce64
call :show_environment "vs15ce64"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio\2017\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" amd64
goto :EOF

:python27_86
call :show_environment "python27_86"
set PATH=C:\Python27;c:\Python27\Scripts;%PATH%
goto :EOF

:python37_86
call :show_environment "python37_86"
set PATH=%LocalAppData%\Programs\Python\Python37-32;%PATH%
goto :EOF

:python37_64
call :show_environment "python37_64"
set PATH=%LocalAppData%\Programs\Python\Python37;%PATH%
goto :EOF

:gpg
call :show_environment "gpg"
set GNUPGHOME=p:\keys
goto :EOF

:error
echo Script exiting with an error.
exit /B 1
goto end

:success
exit /B 0
goto end

:end

