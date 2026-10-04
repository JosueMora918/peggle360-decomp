# dev.ps1 - Herramientas de depuracion usadas durante la recompilacion.
# Uso (desde la raiz del proyecto, con rexglue.exe en el PATH):
#   . .\tools\dev.ps1
#   Find-Func '0x827BEE70'                       -> en que funcion cae esa direccion
#   Add-Funcs @('0x827BEE70 = {}')               -> anade entradas al manifiesto (con copia de seguridad)
#   Run-Cycle                                    -> regenera, compila, ejecuta y analiza el ultimo fallo

# Dice en que funcion registrada cae una direccion de invitado y muestra su ensamblador inicial.
function Find-Func([string]$addr) {
  $t = [uint32]$addr
  $f = Select-String -Path generated\default\*.cpp -Pattern 'DEFINE_REX_FUNC\(sub_([0-9A-F]{8})\)' |
    ForEach-Object { [pscustomobject]@{ A = [uint32]('0x' + $_.Matches[0].Groups[1].Value); P = $_.Path; L = $_.LineNumber } } |
    Sort-Object A
  $b = $f | Where-Object { $_.A -le $t } | Select-Object -Last 1
  $n = $f | Where-Object { $_.A -gt $t } | Select-Object -First 1
  '{0} -> funcion registrada anterior: sub_{1:X8}; siguiente: sub_{2:X8} (a {3} bytes del destino)' -f $addr, $b.A, $n.A, ($n.A - $t)
  if ($b.A -eq $t) { 'OJO: es el inicio exacto de una funcion registrada' }
  $lines = Get-Content $b.P
  $end = $b.L
  while ($lines[$end] -notmatch '^\}') { $end++ }
  $lines[($b.L - 1)..$end] | Where-Object { $_ -match '^\s*// ' } | Select-Object -First 25
}

# Anade lineas al manifiesto, antes de la primera [[entrypoint.switch_tables]] si existe.
# Importante: las entradas nuevas NO deben ir despues de una tabla [[...]] o TOML las trataria como suyas.
function Add-Funcs([string[]]$lines) {
  Copy-Item peggle_manifest.toml ('peggle_manifest.bak_' + (Get-Date -Format HHmmss))
  $p = Get-Content peggle_manifest.toml
  $m = $p | Select-String '^\[\[entrypoint\.switch_tables\]\]' | Select-Object -First 1
  if ($m) {
    $i = $m.LineNumber - 1
    ($p[0..($i - 1)] + $lines + '' + $p[$i..($p.Count - 1)]) | Set-Content peggle_manifest.toml
  } else {
    ($p + $lines) | Set-Content peggle_manifest.toml
  }
}

# Regenera el codigo, compila, lanza el juego y analiza el ultimo FATAL / violation.
function Run-Cycle {
  rexglue codegen --ignore-stamp 2>&1 | Select-String 'Codegen summary|\[E\]|Failed'
  $b = cmake --build out/build/win-amd64-release 2>&1 | Select-String 'error|FAILED'
  if ($b) { $b | Select-Object -First 10; return }
  $log = 'run_' + (Get-Date -Format HHmmss) + '.log'
  $g = Join-Path (Get-Location) 'extracted'
  $a = "--game_data_root=`"$g`" --gpu_plugin=xenos --no-fullscreen --license_mask=1 --protect_on_release --mnk_mode --log_level=info --log_file=$log"
  Start-Process .\out\build\win-amd64-release\peggle.exe -Wait -ArgumentList $a
  $f = Select-String -Path $log -Pattern 'FATAL|violation|STUB' | Select-Object -First 10
  $f | ForEach-Object { $_.Line }
  $m = $f | Where-Object { $_.Line -match 'guest address (0x[0-9A-Fa-f]+)' } | Select-Object -First 1
  if ($m) { $m.Line -match 'guest address (0x[0-9A-Fa-f]+)' | Out-Null; Find-Func $Matches[1] }
}
