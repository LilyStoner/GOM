@echo off
setlocal
if not defined DELIVERY_COPY_MINIMIZED (
  set "DELIVERY_COPY_MINIMIZED=1"
  start "" /min "%~f0"
  exit /b
)
set "SCRIPT=%~dp0DeliveryCopy.ps1"
set "LOG=%~dp0DeliveryCopy_startup_error.log"

if not exist "%SCRIPT%" (
  powershell.exe -WindowStyle Hidden -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('DeliveryCopy.ps1 was not found. Extract the ZIP first.','Delivery Copy')"
  echo DeliveryCopy.ps1 was not found.
  echo Extract the ZIP first, then run this CMD file from the extracted folder.
  pause
  exit /b 1
)

powershell.exe -WindowStyle Hidden -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" 1>"%LOG%" 2>&1
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  powershell.exe -WindowStyle Hidden -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show('Delivery Copy could not start. See DeliveryCopy_startup_error.log beside the app.','Delivery Copy')"
  echo.
  echo Delivery Copy could not start. Details are in:
  echo %LOG%
  echo.
  type "%LOG%"
  pause
  exit /b %EXITCODE%
)

if exist "%LOG%" del "%LOG%" >nul 2>&1
exit /b 0
