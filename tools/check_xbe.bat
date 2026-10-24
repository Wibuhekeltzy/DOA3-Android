@echo off
setlocal
rem Reads assets\default.xbe and prints the XDK library builds it was made with and how many of the
rem SDK's known XDK functions its signatures find. It builds only xbe_symbols, writes nothing to config\
rem and does not recompile the game: it is safe to run before the port's config exists.
rem Report: out\xbe_check.txt
cd /d "%~dp0.."
set "GAME_XBE=default.xbe"
set "PF86=%ProgramFiles(x86)%"
set "VSWHERE=%PF86%\Microsoft Visual Studio\Installer\vswhere.exe"
set "TOOLS=%CD%\out\build\android-tools"
set "LOG=%CD%\out\xbe_check_build.txt"
set "REPORT=%CD%\out\xbe_check.txt"
if not defined ANDROID_HOME set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "NDK=%ANDROID_HOME%\ndk\28.2.13676358"
set "SDKCMAKE=%ANDROID_HOME%\cmake\3.31.6\bin"

echo.
echo   XBE check: XDK build and signature match
echo   ========================================
echo.

if not exist assets\%GAME_XBE% goto :nogame
if not exist "%ANDROID_HOME%\platforms" goto :nosdk
if not exist "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang-cl.exe" goto :nosdk
if not exist "%SDKCMAKE%\cmake.exe" goto :nosdk
set "VSDIR="
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR goto :novs
call "%VSDIR%\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
set "PATH=%SDKCMAKE%;%PATH%"
set "CLANGCL=%VSDIR%\VC\Tools\Llvm\x64\bin\clang-cl.exe"
if not exist "%CLANGCL%" set "CLANGCL=%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang-cl.exe"
where git >nul 2>nul || goto :nogit

if not exist out mkdir out
echo   [1/2] Building xbe_symbols. The first run downloads Zydis and toml++, which takes a few minutes.
cmake -S tools -B "%TOOLS%" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_C_COMPILER=%CLANGCL%" "-DCMAKE_CXX_COMPILER=%CLANGCL%" > "%LOG%" 2>&1 || goto :buildfail
cmake --build "%TOOLS%" --target xbe_symbols >> "%LOG%" 2>&1 || goto :buildfail
set /p SDK=<"%TOOLS%\sdk_dir.txt"
set "SDK=%SDK:/=\%"

echo   [2/2] Reading assets\%GAME_XBE%
echo.
"%TOOLS%\xbe_symbols.exe" assets\%GAME_XBE% "%SDK%\xdk" 1>nul 2>"%REPORT%"
set "RC=%ERRORLEVEL%"
type "%REPORT%"
echo.
if "%RC%"=="0" goto :ok
echo   xbe_symbols stopped with an error, see the lines above. If they say there are no signatures for
echo   these library builds, the SDK cannot name this game's XDK functions yet.
echo   Nothing in config\ was changed. Paste the text above to Claude.
goto :end

:ok
echo   Signatures matched this XBE. Nothing in config\ was changed.
echo   Paste the text above to Claude. It is also saved in %REPORT%
goto :end

:nogame
echo   Put your game's %GAME_XBE% in %CD%\assets first.
goto :fail

:nosdk
echo   The Android SDK was not found complete. Install Android Studio, then in its SDK Manager:
echo   Android SDK Platform 34, NDK 28.2.13676358 and CMake 3.31.6.
goto :fail

:novs
echo   Visual Studio 2022 with "Desktop development with C++" was not found.
goto :fail

:nogit
echo   git is missing: https://git-scm.com/download/win
goto :fail

:buildfail
type "%LOG%"
echo.
echo   Building xbe_symbols failed, see the lines above. Paste them to Claude.
goto :fail

:fail
echo.
echo   CHECK FAILED. Read the last message above.
echo.
if not defined CI pause
exit /b 1

:end
echo.
if not defined CI pause
exit /b 0
