# Peggle (Xbox 360) — Progreso del desarrollo

Toolchain: **ReXGlue SDK v0.10.0.2-dev.gc94f5eb** (Windows, LLVM/Clang + Ninja).
Probado en Windows 11 con una NVIDIA RTX 3070.

## Fase 1: Datos de partida (HECHO)

- Archivos del juego ya extraídos a `extracted/` (incluye `default.xex`).
- Título: Title ID `58410889`, Media ID `111272B2`, versión `0.0.1.2`, XEX del 2009-02-17.
- Rango de código `0x82130000–0x82E6EA4A`; imagen `0x82000000–0x831D0000`.
- No hay actualización de título: el runtime busca `default.xexp`, no lo encuentra y sigue sin él.

## Fase 2: Compilar e instalar el SDK (HECHO)

- `cmake --build ... --target install` produce `rexglue.exe`, `rexruntime.dll` y el plugin gráfico `rexgpu-xenos.dll`.
- Dos problemas, en este orden:
  1. El enlazado fallaba con `machine type x86 conflicts with x64`: el entorno no era x64 y se colaba el `clang` de `C:\Windows`. Se resolvió con la *x64 Native Tools Command Prompt* y fijando en CMake el compilador de `C:\Program Files\LLVM`.
  2. Con Clang 23.1.2, `simde` falla con `__builtin_nontemporal_store` sobre una `union`. Se parcheó `thirdparty/simde/simde/x86/sse.h` (`#elif 0 && ...` en `simde_mm_stream_pi`).
- Ambos cambios se hicieron juntos, así que no sé cuál fue el decisivo.

## Fase 3: Andamiaje y codegen (HECHO)

- `rexglue init --project-name peggle --xex-path extracted/default.xex` → `peggle_manifest.toml`, CMake, `src/main.cpp`, `src/peggle_app.h`.
- Primer `rexglue codegen`: **152 `UnresolvedCall`** (saltos `b` a direcciones que no estaban en ninguna función).
- Se registraron los destinos en `[entrypoint.functions]` con la sintaxis `0x... = {}`:
  1. Prueba con 3 direcciones (152 → 133) para validar la sintaxis.
  2. Script que extrae los destinos únicos del log (113 más) → queda 1 error (`0x8213CDE0`).
  3. Una entrada más → codegen limpio, unos 133 archivos `peggle_recomp.N.cpp`.

## Fase 4: Compilación (HECHA)

- `cmake --preset win-amd64-release` contra el SDK instalado, con el compilador de LLVM fijado.
- Fallaron 5 archivos con `use of undeclared label`: una función se tragaba el código de la siguiente.
  - 4 casos se resolvieron acotando la función contenedora con `size` (`0x8223AF98`, `0x822BAFCC`, `0x8222FF24`, `0x825A1BA4`).
  - El quinto (`sub_827BCC18`) era una **tabla de saltos** (`bctr` en `0x827BCC5C`, índices de un byte) leída más allá de su final. Se declaró a mano con `[[entrypoint.switch_tables]]`, conservando los casos 0–43; los casos 44 y 45 apuntaban a código de la función vecina.
- Enlazado: 11 símbolos `XUsbcam*` sin definir (la API de la cámara de Xbox). Se añadió `src/stubs.cpp` con `REX_EXPORT_STUB(__imp__XUsbcam...)` y se registró en `CMakeLists.txt`.
  - El primer intento, sin el prefijo `__imp__`, compilaba pero no enlazaba.
- Resultado: `peggle.exe` enlazado.

## Fase 5: Arranque (HECHO)

- Primera ejecución: ventana negra que se cierra. El log decía `[FATAL] Call to invalid or unregistered function at guest address 0x8213C3A0`, siempre la misma.
- Clase de fallo (en orden): funciones alcanzables solo por puntero, que el análisis no ve.
  1. **Thunks de salto** `lis / addi / mtctr / bctr` (16 bytes) en `0x8213xxxx`–`0x8215xxxx`. Se registraron **6.315** de golpe con un script que busca esos huecos tras otro thunk igual.
  2. **Forwarders de vtable** (`lwz` del puntero virtual, `mtctr`, `bctr`): `0x822D2008`, `0x822C8AF0`, `0x82750D28`, entre otros.
  3. Un script de cierre de huecos (`Close-Gaps`) añadió ~190 entradas más.
- Más adelante se quitaron **63** de esas entradas porque el codegen avisaba `not in any code region`: eran datos, no código.
- **Sin gráficos al principio:** el log decía `Runtime initialized without graphics system`. El backend gráfico es un plugin: se copió `rexgpu-xenos.dll` junto al `.exe` y se lanzó con `--gpu_plugin=xenos`. Aparecieron vídeo (Direct3D 12) y audio.
- **Modo demo:** el juego se creía una demo. Con `--license_mask=1` se detecta como juego completo.

## Fase 6: Menú y primer nivel (HECHO)

- Se llega al menú principal y al primer nivel.
- Crash al completar el nivel (fuegos artificiales): `Unhandled guest access violation: read of guest 0x43FA000C`.
  - `0x43FA0000` es el float 500.0. El código lo trataba como puntero.
  - Localizado con el desplazamiento de fallo del Visor de eventos + un archivo de mapa del enlazador (`/MAP`): función `sub_8226AEB0`, un manejador de mensajes (mensaje 5).
  - Un hook de diagnóstico mostró que el bloque recibido contenía dos floats (645.0 y 500.0) donde en las llamadas buenas había un puntero a vtable.
- El fallo es **intermitente**.
  - `--allow_game_relative_writes` no ayudó.
  - `--protect_on_release` redujo la frecuencia pero no lo eliminó.
- **Mitigación actual:** un hook de `sub_8226AEB0` en `src/stubs.cpp` que salta la llamada si el puntero interno no es legible (`VirtualQuery`).
  - Causa raíz **sin confirmar**; mi hipótesis es un puntero a memoria ya liberada o reutilizada.
  - Una primera versión (heurística por rango de direcciones) descartaba más de lo debido. La actual no ha tenido que actuar en las pruebas posteriores, pero eso no demuestra que el bug haya desaparecido.

## Fase 7: Modos de juego (HECHO para lo probado)

- Funcionan: todas las opciones del menú, campaña con progreso guardado, Quick Play, Master Duel, niveles de los Maestros, instant replay y multijugador local.
  - Quick Play y Master Duel fallaban por una función más (`0x821BC7B0`, un thunk de 8 bytes tras `sub_821BC510`).
- El progreso se guarda en `Documents\peggle\58410889\profile\`. El juego sigue intentando escribir `userdata/stat__*.dat` y falla; no he comprobado si eso afecta a las estadísticas.
- Memoria: `WorkingSet` de unos 470 MB a unos 750 MB en algo más de una hora; el Administrador de tareas muestra unos 280 MB (memoria privada). No es una fuga confirmada.

## Fase 8: Controles (HECHO, solo teclado)

- Con `--mnk_mode`: `A`/`D` mueven el cañón, `Espacio` dispara, `I` apuntado preciso (gatillo izquierdo), `P` instant replay, `Enter` Start, `W/A/S/D` en los menús. Lista completa en `how_to_play.txt`.
- **Ratón: descartado por ahora.** El driver del SDK solo envía el ratón al stick derecho (que Peggle ignora) y no tiene soporte de rueda.
  - Se intentó un parche (`--mnk_mouse_left`), pero la recompilación del SDK falló (se coló el Clang 23 de `C:\Windows`; errores en `simde` `sse4.1.h:2146` y un símbolo `_tzcnt_u64` en Tracy). Se revirtió.

## Fase 9: Empaquetado (HECHO)

- `README.md`, `.gitignore`, `how_to_play.txt` y `tools/dev.ps1` (comandos de depuración: `Find-Func`, `Add-Funcs`, `Run-Cycle`).
- `make_release.ps1`: ordena la carpeta (`-Tidy`), genera el repositorio limpio (sin juego, sin código generado, sin binarios) y un paquete de binarios para uso privado.
- Primer commit hecho; comprobado que no se cuelan `.xex`, `.exe`, `.dll` ni `generated/default`.

## Pendiente

- [ ] **DLC *Peggle Nights*:** sin soporte. En Xbox 360 se entrega como paquetes STFS y no sé si el runtime los enumera y monta. Primer paso: `--log_level=debug` y buscar `Content` o `Enumerator` en el log.
- [ ] **Ratón:** apuntado relativo (parche del driver MnK, hay que arreglar la recompilación del SDK) o absoluto (hook de la función del juego que actualiza el ángulo).
- [ ] **Causa raíz del crash intermitente** de `sub_8226AEB0` (hoy solo está mitigado).
- [ ] La función de 1,3 MB `0x82BBA280` aparece en cada codegen como `exceeds max_file_size_bytes`. No ha dado problemas, pero es la primera sospechosa si algo se rompe pronto.
- [ ] Stubs de Xbox Live: `XNetLogonGetTitleID` y mensajes `XLIVEBASE` sin implementar (irrelevante para juego local).
- [ ] Probar con mando XInput (se detecta, no se ha jugado con él).
- [ ] Probar el paquete de binarios en un equipo limpio (¿basta con las DLL incluidas y el Visual C++ Redistributable?).
- [ ] Poder reconstruir el SDK desde cero sin depender del `clang` de `C:\Windows`.

## Notas

- Las ~6.500 entradas de funciones del manifiesto vienen de scripts heurísticos y de iterar con fallos de ejecución; no están verificadas una por una.
- Un `size` mal estimado puede tapar funciones vecinas (pasó con `0x8213C3A0`: 80 bytes → eran 16).
- Flags del lanzador: `--gpu_plugin=xenos --license_mask=1 --protect_on_release --mnk_mode --fullscreen --present_letterbox`.
