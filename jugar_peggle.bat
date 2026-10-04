@echo off
cd /d "%~dp0"
out\build\win-amd64-release\peggle.exe --game_data_root="%~dp0extracted" --gpu_plugin=xenos --fullscreen --license_mask=1 --protect_on_release --mnk_mode --log_level=info --log_file=peggle.log --present_letterbox
