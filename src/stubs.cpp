#include <rex/hook.h>

// Xbox Live Vision camera API (xam.xex). Peggle never uses it, but the
// binary imports it, so the linker needs a definition.
REX_EXPORT_STUB(__imp__XUsbcamCreate)
REX_EXPORT_STUB(__imp__XUsbcamDestroy)
REX_EXPORT_STUB(__imp__XUsbcamReset)
REX_EXPORT_STUB(__imp__XUsbcamGetState)
REX_EXPORT_STUB(__imp__XUsbcamGetConfig)
REX_EXPORT_STUB(__imp__XUsbcamSetConfig)
REX_EXPORT_STUB(__imp__XUsbcamSetView)
REX_EXPORT_STUB(__imp__XUsbcamGetView)
REX_EXPORT_STUB(__imp__XUsbcamSetCaptureMode)
REX_EXPORT_STUB(__imp__XUsbcamReadFrame)
REX_EXPORT_STUB(__imp__XUsbcamSnapshot)

// --- PROTECCION v2: solo salta si el puntero interno no es legible ---
#include <windows.h>
static bool guest_readable(const uint8_t* base, uint32_t addr, size_t len) {
  MEMORY_BASIC_INFORMATION mbi;
  const uint8_t* p = base + addr;
  if (!VirtualQuery(p, &mbi, sizeof(mbi))) return false;
  if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_NOACCESS | PAGE_GUARD))) return false;
  return p + len <= static_cast<const uint8_t*>(mbi.BaseAddress) + mbi.RegionSize;
}
extern "C" REX_FUNC(__imp__sub_8226AEB0);
REX_HOOK_RAW(sub_8226AEB0) {
  if (ctx.r5.u32 == 5 || ctx.r5.u32 == 61) {
    const uint32_t p = ctx.r4.u32;
    if (p != 0 && guest_readable(base, p, 8)) {
      const uint32_t c0 = __builtin_bswap32(*reinterpret_cast<const uint32_t*>(base + p));
      const uint32_t c4 = __builtin_bswap32(*reinterpret_cast<const uint32_t*>(base + p + 4));
      if (c0 >= 1 && !guest_readable(base, c4 + 12, 4)) {
        REXKRNL_WARN("sub_8226AEB0: payload invalido omitido msg={} r4={:08X} c0={:08X} c4={:08X}",
                     ctx.r5.u32, p, c0, c4);
        ctx.r3.u64 = 0;
        return;
      }
    }
  }
  __imp__sub_8226AEB0(ctx, base);
}
