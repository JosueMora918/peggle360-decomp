@echo off
cd /d "%~dp0"

if not exist "%~dp0extracted\default.xex" (
  echo No encuentro extracted\default.xex.
  echo Copia ahi los archivos de tu copia del juego ^(ver LEEME.txt^).
  pause
  exit /b 1
)

set "XH="
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%~dp0extracted\default.xex" SHA256') do if not defined XH set "XH=%%H"
set "XH=%XH: =%"
if /i not "%XH%"=="5F21710ECFD3D2B88C4D47C6B4916F61F282E0D941EC42E119AC12EB24E193B5" (
  echo AVISO: tu default.xex no coincide con la version esperada.
  echo   Esperado: 5F21710ECFD3D2B88C4D47C6B4916F61F282E0D941EC42E119AC12EB24E193B5
  echo   El tuyo:  %XH%
  echo Si el juego falla, vuelve a preparar los archivos ^(ver LEEME.txt^).
  timeout /t 8
)

out\build\win-amd64-release\peggle.exe --game_data_root="%~dp0extracted" --gpu_plugin=xenos --fullscreen --license_mask=1 --protect_on_release --mnk_mode --log_level=info --log_file=peggle.log --present_letterbox
