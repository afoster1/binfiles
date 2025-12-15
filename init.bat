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

if "%1" == "cpp86" call :cpp86 || goto :error
if "%1" == "cpp64" call :cpp64 || goto :error
if "%1" == "vs18p" goto :vs18p || goto :error
if "%1" == "vs18c" goto :vs18c || goto :error
if "%1" == "vs17p" goto :vs17p || goto :error
if "%1" == "vs17c" goto :vs17c || goto :error
if "%1" == "vs17c86" goto :vs17c86 || goto :error
if "%1" == "vs17c64" goto :vs17c64 || goto :error
if "%1" == "vs16p" goto :vs16p || goto :error
if "%1" == "vs16p86" goto :vs16p86 || goto :error
if "%1" == "vs16p64" goto :vs16p64 || goto :error
if "%1" == "vs15p" goto :vs15p || goto :error
if "%1" == "vs14p" goto :vs14p || goto :error
if "%1" == "vs15c86" goto :vs15c86 || goto :error
if "%1" == "vs15c64" goto :vs15c64 || goto :error
if "%1" == "python27_86" goto :python27_86 || goto :error
if "%1" == "python37_86" goto :python37_86 || goto :error
if "%1" == "python37_64" goto :python37_64 || goto :error
if "%1" == "python3" goto :python3 || goto :error
if "%1" == "gpg" goto :gpg || goto :error
if "%1" == "winsdk100" goto :winsdk100 || goto :error
if "%1" == "winsdk100_64" goto :winsdk100_64 || goto :error
if "%1" == "wix3" goto :wix3 || goto :error
if "%1" == "nodejs" goto :nodejs || goto :error
if "%1" == "rojo" goto :rojo || goto :error
if "%1" == "java" goto :java || goto :error

if %environment_initialised% EQU 0 goto :error
goto :success

:show_environment
set environment_name=%1
set environment_name=%environment_name:"=%
@echo Initialising %environment_name% environment.
set environment_initialised=1
title %environment_name%
goto :EOF

:cpp86
call :vs17c86 || goto :error
goto :EOF

:cpp64
call :vs17c64 || goto :error
goto :EOF

rem Visual Studio 2026
:vs18p
call :show_environment "vs18p"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\18\Professional
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:vs18c
call :show_environment "vs18c"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\18\Community
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

rem Visual Studio 2022
:vs17p
call :show_environment "vs17p"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\2022\Professional
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:vs17c
call :show_environment "vs17c"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\2022\Community
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:vs17c86
call :show_environment "vs17c86"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\2022\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvars32.bat"
goto :EOF

:vs17c64
call :show_environment "vs17c64"
set VS_HOME=C:\Program Files\Microsoft Visual Studio\2022\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvars64.bat"
goto :EOF

rem Visual Studio 2019
:vs16p
call :show_environment "vs16p"
set VS_HOME=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:vs16p86
call :show_environment "vs16p86"
set VS_HOME=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" x86
goto :EOF

:vs16p64
call :show_environment "vs16p64"
set VS_HOME=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" x64
goto :EOF

rem Visual Studio 2017
:vs15p
call :show_environment "vs15p"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio\2017\Professional
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:vs15c86
call :show_environment "vs15c86"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio\2017\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" x86
goto :EOF

:vs15c64
call :show_environment "vs15c64"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio\2017\Community
call "%VS_HOME%\VC\Auxiliary\Build\vcvarsall.bat" amd64
goto :EOF

rem Visual Studio 2015
:vs14p
call :show_environment "vs14p"
set VS_HOME=c:\Program Files (x86)\Microsoft Visual Studio 14.0
call "%VS_HOME%\Common7\Tools\VsDevCmd.bat"
goto :EOF

:python27_86
call :show_environment "python27_86"
set PATH=C:\Python27;c:\Python27\Scripts;%PATH%
goto :EOF

:python36_86
call :show_environment "python36_86"
set PATH=%LocalAppData%\Programs\Python\Python36-32;%PATH%
goto :EOF

:python36_64
call :show_environment "python36_64"
set PATH=%LocalAppData%\Programs\Python\Python36;%PATH%
goto :EOF

:python37_86
call :show_environment "python37_86"
set PATH=%LocalAppData%\Programs\Python\Python37-32;%PATH%
goto :EOF

:python37_64
call :show_environment "python37_64"
set PATH=%LocalAppData%\Programs\Python\Python37;%PATH%
goto :EOF

:python3
call :show_environment "python3"
set PATH=%LocalAppData%\Programs\Python\Python313;%LocalAppData%\Programs\Python\Python313\Scripts;%PATH%
goto :EOF

:gpg
call :show_environment "gpg"
set GNUPGHOME=p:\keys
goto :EOF

:winsdk100
call :show_environment "winsdk100"
set _NT_SYMBOL_PATH=.;SRV*c:\symbols\*http://msdl.microsoft.com/download/symbols
set PATH="C:\Program Files (x86)\Windows Kits\10\bin\x86";"C:\Program Files (x86)\Windows Kits\10\Debuggers\x86";%PATH%
goto :EOF

:winsdk100_64
call :show_environment "winsdk100_64"
set _NT_SYMBOL_PATH=.;SRV*c:\symbols\*http://msdl.microsoft.com/download/symbols
set PATH="C:\Program Files (x86)\Windows Kits\10\bin\x64";"C:\Program Files (x86)\Windows Kits\10\Debuggers\x64";%PATH%
goto :EOF

:wix3
call :show_environment "wix3"
set WIX_HOME="C:\Program Files (x86)\WiX Toolset v3.11"
set PATH=%WIX_Home%\bin;%PATH%
goto :EOF

:nodejs
call :show_environment "nodejs"
set NODEJS_HOME="C:\Program Files\nodejs"
set PATH=%NODEJS_HOME%;%PATH%
goto :EOF

:rojo
call :show_environment "rojo"
set ROJO_HOME="%HOMEDRIVE%%HOMEPATH%\.aftman\bin"
set PATH=%ROJO_HOME%;%PATH%
goto :EOF

:java
call :show_environment "java"
set JAVA_HOME="C:\Program Files\Java\jdk-25"
set PATH=%JAVA_HOME%\bin;%PATH%
goto :EOF

:error
echo Script exiting with an error.
exit /B 1
goto end

:success
exit /B 0
goto end

:end

