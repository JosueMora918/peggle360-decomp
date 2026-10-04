# Peggle (Xbox 360) para PC — recompilación estática con ReXGlue

Port nativo para PC de **Peggle** (Xbox Live Arcade), hecho con [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk), que convierte el código PowerPC de Xbox 360 en C++ que corre de forma nativa.

> **Este repositorio no incluye el juego.** No contiene `default.xex`, assets, ejecutables ni el código generado a partir del binario del juego. Necesitas tu propia copia de Peggle para Xbox 360. Proyecto no oficial, sin relación con EA, PopCap ni Microsoft.

## Estado

Probado en Windows 11 con una NVIDIA RTX 3070.

**Funciona**
- Menú principal y todas sus opciones
- Campaña, con progreso guardado
- Quick Play, Master Duel y los niveles de los Maestros
- Instant replay
- Multijugador local
- Vídeo (Direct3D 12) y audio

**Limitaciones conocidas**
- Sin soporte para el DLC *Peggle Nights*.
- Sin ratón: se juega con teclado (ver [controles](#controles)). El mando XInput se detecta, pero no lo he probado a fondo.
- Sin Xbox Live: las llamadas de red y de estadísticas en línea no están implementadas. Los logros se registran solo en local.
- El juego intenta escribir `userdata/...` y falla; el progreso de la campaña se guarda por otra vía.
- El uso de memoria sube despacio durante la sesión (unos 750 MB tras más de una hora, medido como `WorkingSet`).
- Hay un fallo intermitente en un manejador de mensajes (`sub_8226AEB0`). Se mitiga con un hook que omite la llamada si el puntero interno no es legible (ver [notas técnicas](#notas-técnicas)); no sé si es el único caso.

## Requisitos para jugar

- Windows 10/11 de 64 bits
- GPU con soporte de Direct3D 12
- [Visual C++ Redistributable 2015-2022 (x64)](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)
- Archivos de tu copia de Peggle (Xbox 360), con esta versión:
  - Title ID `58410889`, Media ID `111272B2`, versión `0.0.1.2`
  - SHA-256 de `default.xex`: `5F21710ECFD3D2B88C4D47C6B4916F61F282E0D941EC42E119AC12EB24E193B5`
  - El port se generó solo con `default.xex` (sin actualización de título). No lo he probado con `default.xexp`.

## Cómo jugar (paquete de binarios)

1. Descomprime tu archivo de Peggle (XBLA) con wxPirs y desencripta el default.xex con XeXTool.
2. Comandos usados para XeXTool: xextool -c u -e u -o default_clean.xex default.xex; xextool -b Thunderball.exe default_clean.xex 
3. Copia el contenido de tu copia del juego en la carpeta `extracted\` (debe quedar `extracted\default.xex`).
4. Ejecuta `jugar_peggle.bat`.

## Controles

El juego usa la emulación de mando por teclado del SDK (`--mnk_mode`). Lista completa en [`how_to_play.txt`](how_to_play.txt).

| Acción | Tecla |
|---|---|
| Mover el cañón / moverse por los menús | `A` / `D` / `W` / `S` |
| Disparar | `Espacio` |
| Apuntado preciso (más lento) | `I` |
| Instant replay | `P` |
| Start | `Enter` |

## Compilar desde el código fuente

### Requisitos
- Visual Studio 2022 Build Tools (C++ y Windows SDK)
- LLVM/Clang. Versión usada para compilar: `clang version 23.1.2`
- CMake 3.25 o superior, Ninja y Git
- Una copia de Peggle para Xbox 360 en `extracted\`

### 1. Compilar e instalar el SDK
Desde la **x64 Native Tools Command Prompt for VS 2022**. La versión usada es `0.10.0.2-dev.gc94f5eb` (la que muestra `rexglue --version`).

```bat
git clone --recursive https://github.com/rexglue/rexglue-sdk
cd rexglue-sdk
cmake --list-presets
cmake --preset win-amd64 -DCMAKE_C_COMPILER="C:/Program Files/LLVM/bin/clang.exe" -DCMAKE_CXX_COMPILER="C:/Program Files/LLVM/bin/clang++.exe"
cmake --build out/build/win-amd64 --target install
```

Comprueba con `--list-presets` el nombre exacto del preset.

**Nota sobre Clang:** el SDK no compiló con Clang 23.1.2. `simde` falla con errores de `__builtin_nontemporal_*` aplicado a una `union`, primero en `thirdparty/simde/simde/x86/sse.h` (`__builtin_nontemporal_store` en `simde_mm_stream_pi`) y después en `x86/sse4.1.h` (`__builtin_nontemporal_load`, línea ~2146). Para compilar usé la versión de LLVM indicada arriba, tras cambiar en `sse.h` la rama `#elif HEDLEY_HAS_BUILTIN(__builtin_nontemporal_store) && (...)` por `#elif 0 && HEDLEY_HAS_BUILTIN(...)`. No sé si esa edición era necesaria con esa versión de LLVM; no he probado a compilar sin ella.

### 2. Generar el código y compilar el proyecto
Añade `rexglue.exe` al `PATH` (`rexglue-sdk\out\install\win-amd64\bin`) y, desde la raíz de este repositorio:

```bat
rexglue codegen
cmake --preset win-amd64-release "-DCMAKE_PREFIX_PATH=<RUTA>/rexglue-sdk/out/install/win-amd64" "-DCMAKE_C_COMPILER=C:/Program Files/LLVM/bin/clang.exe" "-DCMAKE_CXX_COMPILER=C:/Program Files/LLVM/bin/clang++.exe"
cmake --build out/build/win-amd64-release
copy <RUTA>\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll out\build\win-amd64-release\
jugar_peggle.bat
```

`rexglue codegen` tarda unos 40 segundos y genera `generated\default\` a partir de tu `default.xex` y de `peggle_manifest.toml`. Ese código no se sube al repositorio.

## Notas técnicas

- **`peggle_manifest.toml`**: límites de función y una tabla de saltos (`[[entrypoint.switch_tables]]`) que el análisis automático no resolvía, obtenidos iterando con los fallos de ejecución.
- **`src/stubs.cpp`**: 11 stubs de la API de la cámara de Xbox (`XUsbcam*`, que el binario importa pero Peggle no usa) y el hook de `sub_8226AEB0`.
- **Flags del lanzador**: `--gpu_plugin=xenos` (backend gráfico), `--license_mask=1` (evita el modo demo), `--mnk_mode` (teclado como mando), `--protect_on_release` (reduce un fallo intermitente por memoria liberada; no lo elimina), y `--fullscreen`/`--present_letterbox` para la pantalla.
- **Herramientas**: `tools/dev.ps1` agrupa los comandos de PowerShell usados para localizar funciones y regenerar.

## Créditos

- [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk) (BSD-3-Clause), basado en el trabajo de [Xenia](https://xenia.jp).
- El proyecto de recompilación de Lumines Live de sp00nznet sirvió de base y de referencia para el flujo de trabajo.
- Peggle es propiedad de sus respectivos dueños.
- **Aviso de asistencia por IA:** Partes del código, refactorizaciones y documentación de este proyecto han sido desarrolladas con el soporte de **Claude Code** (Anthropic).

## Licencia

Consulta [`LICENSE`](LICENSE) para el código propio de este repositorio. El SDK de ReXGlue tiene su propia licencia.
