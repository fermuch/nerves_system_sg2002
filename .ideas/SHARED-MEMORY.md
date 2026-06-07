# Elastic TPU/ION Memory on SG2002 (reCamera) — Implementation Guide

**Target repo:** `nerves_system_sg2002` (https://github.com/fermuch/nerves_system_sg2002, local: `/home/fermuch/Documents/Dev/AYVU/nerves_system_sg2002`)
**Goal:** Replace the fixed 64 MiB ION carveout with a **CMA-backed, reclaimable pool** so big TPU models fit on demand, and RAM not used by the TPU/video pipeline is returned to Linux/BEAM — with **no per-model firmware rebuilds** ever again.
**Status:** Design fully verified against pinned sources (June 2026). Not yet implemented or hardware-tested.
**Effort:** ~3 small file changes + 1 kernel patch in `nerves_system_sg2002`, one full firmware build, one reflash of a test unit, then the validation plan below.

---

## 1. Background: how ION memory works on this system today

The SG2002 has **256 MB DDR total**. The current layout (all from `package/cvitekconfig/genconfig/recamera/memmap.py`, values overridden by `nerves_defconfig`):

| Region | Size | Notes |
|---|---|---|
| FreeRTOS (C906L core) | 2 MB | top of DRAM |
| Linux-visible RAM | 254 MB | `memory@80000000` node, `CVIMMAP_KERNEL_MEMORY_SIZE` |
| └ ION carveout | **64 MB** | inside Linux RAM, **dead-reserved** — Linux can never use it |

The ION pool is shared by **everything multimedia**: TPU model weights + activations (via `libcviruntime`), VB pools (camera frame buffers), VPSS/ISP working memory, encoder buffers. The 64 MB is permanently subtracted from Linux/BEAM even when no model is loaded; conversely, a model bigger than what's left in the 64 MB can never load.

### How the size gets baked in (the chain we're modifying)

1. `nerves_defconfig:230` / `nerves_defconfig_emmc:228`: `BR2_PACKAGE_CVITEKCONFIG_ALLOCATE_ION_HEAP=64`
2. `package/cvitekconfig/cvitekconfig.mk:28-31` seds that value into `memmap.py` (`ION_SIZE = <N> * SIZE_1M`)
3. `mmap_conv.py` generates `cvi_board_memmap.h` (`#define CVIMMAP_ION_SIZE 0x4000000`)
4. The header is CPP-substituted into the DTS (`BR2_LINUX_KERNEL_CUSTOM_DTS_PATH` in `nerves_defconfig:44` copies it next to the DTS sources)
5. `board/sipeed/recamera/dts/cv181x_default_memmap.dtsi:21-24`:
   ```dts
   ion_reserved: ion {
       compatible = "ion-region";
       size = <0x0 CVIMMAP_ION_SIZE>;
   };
   ```
6. The DTB is packed into the FIT image (`boot.emmc` / `boot.sd`) on the FAT16 boot partition.

Two properties of *this specific system* make the change below much easier than on stock reCamera OS:

- **The ION node is size-only** (no `reg`), so the kernel places it dynamically — nothing else in the system depends on its physical address.
- **`fast_image` is disarmed**: `cv181x_default_memmap.dtsi:13` sets `ion-size = <0>`. This matters enormously (see §2.4).

---

## 2. The verified facts that dictate the design

All of this was read from the **exact revisions the firmware builds**:

- Kernel: `sophgo/linux_5.10` @ `085eec53fc4d1935e6736ddad1d6dce5f755dc20` (`nerves_defconfig:39`)
- Kernel modules: `sophgo/osdrv` @ `3639eb4` → `3639eb492944cff9c398afafa7b8446d377d7119` (`package/cvitek-modules/cvitek-modules.mk`)
- Middleware: `sophgo/middleware` @ `b70217f` (`package/cvitek-middleware/cvitek-middleware.mk`)
- TPU runtime: `sophgo/cviruntime` (the prebuilt `libcviruntime.so` shipped in sscmex `priv/lib/`)

### 2.1 The cvitek ION driver cannot create a CMA heap from its own DT binding

`drivers/staging/android/ion/cvitek/cvitek_ion.c` has a heap table that *mentions* a CMA type:

```c
PLATFORM_HEAP("cvitek,carveout", 0, ION_HEAP_TYPE_CARVEOUT, "carveout"),
PLATFORM_HEAP("civtek,cma",      0, ION_HEAP_TYPE_DMA,      "cma"),   /* "civtek" typo is in the source */
```

…but the heap-creation switch in `cvitek_ion_probe` only instantiates `CARVEOUT` and `CHUNK`; `ION_HEAP_TYPE_DMA` falls into `default: continue;` — **no heap is ever created**. The `civtek,cma` compatible is dead code. So "just flip the DT compatible" does **not** work.

### 2.2 But the stock `ion_cma_heap.c` is retained and self-registers

`drivers/staging/android/ion/ion_cma_heap.c` (present in the sophgo fork, built because `CONFIG_ION_CMA_HEAP=y` in `board/sipeed/recamera/linux_defconfig:429`) ends with:

```c
static int ion_add_cma_heaps(void)
{
	cma_for_each_area(__ion_add_cma_heaps, NULL);
	return 0;
}
device_initcall(ion_add_cma_heaps);
```

It automatically creates an ION heap for **every registered CMA area** — including any `reserved-memory` node with `compatible = "shared-dma-pool"; reusable;`. So if we declare the ION region as a reusable CMA pool, the kernel hands us a CMA-backed ION heap **for free**. The single problem: that heap reports `heap.type = ION_HEAP_TYPE_DMA`.

### 2.3 Every consumer selects the heap by `type == ION_HEAP_TYPE_CARVEOUT` — no names, no fallback

This is the crux. Three independent allocation paths, all type-matched:

**(a) Kernel: osdrv `sys.ko`** — `interdrv/v2/sys/common/sys.c`:
```c
/* _sys_ion_alloc_nofd(), line 57 */
ionbuf = cvi_ion_alloc_nofd(ION_HEAP_TYPE_CARVEOUT, u32Len, is_cached);
/* _sys_ion_alloc(), line 126 */
dmabuf_fd = cvi_ion_alloc(ION_HEAP_TYPE_CARVEOUT, u32Len, is_cached);
```
This backs the `SYS_ION_ALLOC` ioctl (= userspace `CVI_SYS_IonAlloc`), the VB pools (`interdrv/v2/base/vb.c` calls `sys_ion_alloc`), and `fast_image`. The kernel-side matcher (`cvitek_ion_alloc.c`, exported `cvi_ion_alloc`) walks the heap query and picks the **first heap whose reported type matches** — name is ignored.

**(b) Userspace: `libcviruntime.so`** (the TPU runtime that loads `.cvimodel` files) **bypasses `CVI_SYS_IonAlloc` entirely.** It opens `/dev/ion` itself. From `sophgo/cviruntime` `src/soc/common/cvi_device_mem.cpp:340-371` (`CviDeviceMem::ion_query_heap`):
```cpp
for (unsigned int i = 0; i < query.cnt; i++) {
    if (heap_data[i].type == ION_HEAP_TYPE_CARVEOUT) {   // type only, no strcmp
        heap_id = heap_data[i].heap_id;
        break;
    }
}
if (heap_id > MAX_HEAP_COUNT) {
    TPU_LOG_WARNING("no carveout heap found\n");          // hard fail, no fallback
    return BM_ERR_FAILURE;
}
```
Confirmed in the shipped binary: `strings sscmex/priv/lib/libcviruntime.so` contains `/dev/ion` and `"no carveout heap found"`. This lib is **closed/prebuilt in our pipeline** — we cannot patch consumers.

**(c) Userspace middleware** (`sophgo/middleware` `v2/modules/sys/src/cvi_sys.c`): `CVI_SYS_IonAlloc` sends only size+name+cached through the `SYS_ION_ALLOC` ioctl — **no heap selector at all**. Heap choice is 100% kernel-side, i.e. covered by (a).

**Conclusion:** if the one ION heap in the system *reports* `ION_HEAP_TYPE_CARVEOUT`, every consumer works unmodified — regardless of how the heap actually allocates. The `type` field is only used for this ioctl-level matching; allocation behavior comes from `heap->ops`, set independently.

### 2.4 The remaining hazards were checked and are clear

- **TPU driver** (`osdrv interdrv/v2/tpu/common/cvi_tpu_interface.c`): never allocates ION; imports a dma_buf fd from userspace, requires physical contiguity + page alignment (`paddr & 0xFFF` check), DMA mask 40-bit. CMA allocations are physically contiguous and page-aligned → satisfied.
- **`fast_image`** (`osdrv interdrv/v2/fast_image/fast_image.c`) is the only code demanding ION at a **fixed physical address** (RTOS handshake) — fatal for CMA, which can't guarantee placement. But every such allocation is guarded by nonzero sizes, and this system sets `ion-size = <0>` (`cv181x_default_memmap.dtsi:13`) → the entire path is skipped. **Do not re-enable fast_image ION while on CMA.**
- **VB pools** assume one contiguous physical base per buffer → CMA satisfies this.
- No code in the sys/VB/TPU allocation paths consumes the baked `CVIMMAP_ION_ADDR` — the kernel places the pool wherever it likes.

### 2.5 Why this beats the alternatives

| Approach | What you get | Why not |
|---|---|---|
| Bigger static carveout | bigger models | permanently steals RAM from BEAM; new rebuild for every size change |
| Multi-DTB FIT + `fw_setenv` selection | per-boot size choice | reboot per change; discrete sizes; you manage variants forever |
| U-Boot `fdt set` patching | arbitrary per-boot size | reboot per change; fragile bootm scripting |
| **CMA-backed ION (this guide)** | **one generous pool, unused part reclaimed by Linux automatically, no reboots, no variants** | needs one kernel patch + hardware validation |

---

## 3. The changes (all in `nerves_system_sg2002`)

Four changes. Each is small; together they are the complete implementation.

### 3.1 Kernel patch: `patches/linux/0007-ion-report-cma-backed-ion-pool-as-carveout-heap.patch`

**Why:** make the auto-registered CMA heap masquerade as the carveout heap so all type-matched consumers (§2.3) find it. Also sets `heap->total_size`, which the CMA creator never fills in, so the existing `cvi_ion_get_memory_state()` helper (added by our patch 0006, iterates `heap->total_size` / `heap->num_of_alloc_bytes`) keeps reporting real numbers.

**How:** Buildroot applies everything in `patches/linux/` (via `BR2_GLOBAL_PATCH_DIR`, `nerves_defconfig:126`) when it extracts the kernel. Create the file below. The diff was generated against the exact pinned kernel revision, so it applies cleanly. Match the header style of `0006-*.patch`.

```
From: Nerves Bot <bot@example.com>
Date: <today>
Subject: [PATCH] ion: report the CMA-backed "ion" pool as a carveout heap

The CVITEK/SOPHGO stack (osdrv sys.ko, libcviruntime) selects its ION
heap strictly by type == ION_HEAP_TYPE_CARVEOUT, with no name match and
no fallback. To make the ION pool reclaimable by Linux when unused, the
reserved-memory node becomes a reusable shared-dma-pool (CMA), and the
stock ion_cma_heap auto-registration is taught to present that heap as
a carveout heap. Allocations remain physically contiguous (cma_alloc),
which is all consumers require. Also fill in heap->total_size so
cvi_ion_get_memory_state() (patch 0006) stays accurate.
---
 drivers/staging/android/ion/ion_cma_heap.c | 23 +++++++++++++++++++++
 1 file changed, 23 insertions(+)

--- a/drivers/staging/android/ion/ion_cma_heap.c
+++ b/drivers/staging/android/ion/ion_cma_heap.c
@@ -125,6 +125,29 @@
 		return PTR_ERR(heap);
 
 	heap->name = cma_get_name(cma);
+	heap->total_size = cma_get_size(cma);
+
+	/*
+	 * The CVITEK/SOPHGO multimedia and TPU stack selects its ION heap
+	 * strictly by type == ION_HEAP_TYPE_CARVEOUT:
+	 *  - osdrv interdrv/v2/sys/common/sys.c calls
+	 *    cvi_ion_alloc(ION_HEAP_TYPE_CARVEOUT, ...), backing
+	 *    CVI_SYS_IonAlloc(), VB pools and fast_image, and
+	 *  - the closed-source TPU runtime (libcviruntime.so) queries
+	 *    /dev/ion directly and hard-fails with "no carveout heap found"
+	 *    (CviDeviceMem::ion_query_heap matches on type only).
+	 * Neither matches by heap name and neither has a fallback type.
+	 *
+	 * Report the CMA heap that backs the "ion" reserved-memory pool as
+	 * a carveout heap so the whole stack works unchanged, while the
+	 * "reusable" CMA region lets Linux reclaim unused pages.  Buffers
+	 * still come from cma_alloc() and are physically contiguous, which
+	 * is all the consumers actually require.
+	 */
+	if (!strcmp(heap->name, "ion")) {
+		heap->type = ION_HEAP_TYPE_CARVEOUT;
+		heap->name = "carveout";
+	}
 
 	ion_device_add_heap(heap);
 	return 0;
```

Notes:
- The `strcmp(heap->name, "ion")` filter keys on the **DT node name** (`ion_reserved: ion { … }` → `cma_get_name()` returns `"ion"`). Any *other* CMA area (e.g. a future `cma=` bootarg pool) keeps its honest DMA type. If you ever rename the DT node, rename it here too.
- `cma_get_size()` is declared in `<linux/cma.h>`, already included by this file. `heap->total_size` exists in the sophgo `ion.h` (patch 0006 already reads it).
- `device_initcall` runs **after** `subsys_initcall` (the cvitek probe), but that ordering stops mattering once §3.2 removes the cvitek heap — leaving exactly **one** carveout-typed heap in the system. This matters: both matchers pick the *first* type match, so two carveout-typed heaps would silently shadow each other.

### 3.2 DTS change 1: make the ION region a reusable CMA pool

**File:** `board/sipeed/recamera/dts/cv181x_default_memmap.dtsi` (shared by SD and eMMC DTS — one edit covers both; verified no board-level overrides).

**Why:** `compatible = "shared-dma-pool"` + `reusable` makes the early-boot reserved-memory code register the region as a **CMA area** instead of dead-reserving it. `reusable` is what lets the kernel use the unused portion for movable pages (page cache, anonymous memory → BEAM heap) until `cma_alloc()` migrates them out. Keeping `size`-only (no `reg`) preserves dynamic placement. `CVIMMAP_ION_SIZE` still flows from the defconfig, so the existing size knob keeps working.

```dts
	reserved-memory {
		#size-cells = <0x2>;
		#address-cells = <0x2>;
		ranges;

		ion_reserved: ion {
			compatible = "shared-dma-pool";   /* was: "ion-region" */
			reusable;                          /* new: Linux may reclaim unused pages */
			size = <0x0 CVIMMAP_ION_SIZE>;
		};
	};
```

Do **not** add `linux,cma-default` (we don't want generic `dma_alloc_coherent` traffic landing in this pool) and do **not** add `no-map`.

### 3.3 DTS change 2: remove the cvitek-ion driver node

**File:** `board/sipeed/recamera/dts/cv181x_base.dtsi:111-120`.

**Why:** with the region no longer `compatible = "ion-region"`, the driver's `RESERVEDMEM_OF_DECLARE(ion, "ion-region", rmem_ion_setup)` never claims it, so `cvitek_ion_probe` would try to build a carveout heap from an uninitialized region — at best probe-error noise, at worst a bogus zero-size heap with type CARVEOUT that **shadows the real heap** (first-match selection, §3.1 note). Our heap now comes from the `ion_cma_heap` initcall; the cvitek probe has nothing left to do.

Delete (or comment out) the whole guarded block:

```dts
#if (CVIMMAP_ION_SIZE > 0)
	cvitek-ion {
		compatible = "cvitek,cvitek-ion";

		heap_carveout@0 {
			compatible = "cvitek,carveout";
			memory-region = <&ion_reserved>;
		};
	};
#endif
```

Known cosmetic loss: the cvitek-specific debugfs entries (`cvi_carveout_heap_dump/summary`) disappear with the probe. Generic ION debugfs remains (`/sys/kernel/debug/ion/carveout/num_of_alloc_bytes` etc.), and `cvi_ion_get_memory_state()` keeps working thanks to the `total_size` line in the patch. No consumer of the cvi debugfs files was found in this system (grep'd packages, patches, sscmex).

### 3.4 Bump the pool size — elasticity makes big cheap

**Files:** `nerves_defconfig:230` and `nerves_defconfig_emmc:228`.

```
BR2_PACKAGE_CVITEKCONFIG_ALLOCATE_ION_HEAP=128
```

**Why 128:** with `reusable`, an idle pool costs ~nothing — Linux uses it for movable pages. 128 MB comfortably fits much larger models + VB pools while leaving 126 MB of never-reclaimable RAM, and movable pages can still spill into the unused pool. (The `cvitekconfig.mk` sed expects an integer; the `memmap.py` internal asserts hold trivially at 128, and the addresses it computes for ION are not consumed by the kernel anyway — only `KERNEL_MEMORY_*` and `FREERTOS_*` still matter.)

Leave `ALLOCATE_ISP_HEAP=8`, `ALLOCATE_H26X_BITSTREAM_HEAP=1`, `ALLOCATE_FREERTOS_HEAP=1` as-is; they only parameterize the (disabled) fast_image/FreeRTOS paths.

### 3.5 Kernel config: nothing to change (verify only)

`board/sipeed/recamera/linux_defconfig` already has everything required:
```
CONFIG_CMA=y            (line 41)
CONFIG_ION=y            (426)
CONFIG_ION_CARVEOUT_HEAP=y  (428, harmless to keep)
CONFIG_ION_CMA_HEAP=y   (429)  <- creates our heap
CONFIG_DMA_CMA=y        (466)
CONFIG_CMA_SIZE_MBYTES=0 (467, correct: no extra global pool)
```
Optional for debugging visibility: add `CONFIG_CMA_DEBUGFS=y` and/or `CONFIG_CMA_SYSFS=y` (5.10 has the former; sysfs counters may not exist in 5.10 — debugfs gives `cma/cma-ion/{count,used,bitmap}`).

---

## 4. Pre-build sanity checks (cheap insurance)

Before burning an hour of build time, confirm the two assumptions that everything rests on, inside the actual build tree. After the first build attempt (or via `mix nerves.system.shell`), in the Buildroot build dir:

```sh
# 1. No OTHER osdrv code allocates ION by a type we are not providing:
rg -n "cvi_ion_alloc|ION_HEAP_TYPE" build/cvitek-modules-*/interdrv/ | rg -v CARVEOUT
# Expect: no allocation call sites with a different heap type.
# (Matches for sys_ion_alloc wrappers are fine - they route through sys.c.)

# 2. The kernel patch applied:
rg -n "no carveout heap found|ION_HEAP_TYPE_CARVEOUT" build/linux-custom/drivers/staging/android/ion/ion_cma_heap.c
# Expect: the masquerade block is present.
```

---

## 5. Building

The system builds via the Docker build runner (`mix.exs`: `build_runner: Nerves.Artifact.BuildRunners.Docker`).

```sh
cd /home/fermuch/Documents/Dev/AYVU/nerves_system_sg2002

# SD variant
mix deps.get
mix compile            # or: mix firmware inside example/ per README

# eMMC variant
NERVES_STORAGE=emmc mix compile
```

**Important — Buildroot patch semantics:** patches in `patches/linux/` are applied **once, at kernel source extraction**. If a previous build exists, the kernel will NOT be re-extracted and the new 0007 patch will NOT apply. Force it:

- Clean route (slow, always correct): `mix clean && mix compile` (full rebuild).
- Targeted route: `mix nerves.system.shell`, then inside the Buildroot shell: `make linux-dirclean && make`. Also run `make cvitekconfig-rebuild` if you changed the ION size, since `cvi_board_memmap.h` must regenerate before the DTBs rebuild.

Sanity-check the built DTB before flashing (host side, in the images dir):

```sh
dtc -I dtb -O dts images/sg2002_recamera_emmc.dtb 2>/dev/null | grep -A6 'reserved-memory'
# Expect: ion { compatible = "shared-dma-pool"; reusable; size = <0x0 0x8000000>; }
# Expect: NO cvitek-ion node anywhere in the output.
```

---

## 6. Flashing — and why OTA is NOT enough

**Critical:** `fwup.conf` upgrade tasks (`upgrade.a` / `upgrade.b`) write **only `rootfs.img`**. The kernel+DTB FIT lives in `boot.vfat` on partition 0, which only the `complete` task writes. A normal Nerves OTA of an app built against the new system will boot the **old** kernel/DTB and the change silently won't exist.

For the test device, do a full burn:

```sh
# in the app (e.g. recamera-tracker) with the new system as dep:
MIX_TARGET=nerves_system_sg2002_emmc mix firmware
mix burn          # full 'complete' task -> writes boot partition too
```

For fleet rollout later, two options:
1. **Reflash** units with the factory image (simplest, needs physical access or your eMMC writer flow).
2. **Alternate-FIT mechanic** (no reflash): ship the new FIT as an extra file, have the app mount the FAT boot partition (`/dev/mmcblk0p1`), copy it as `boot-cma.emmc` (never overwrite `boot.emmc`), then `fw_setenv bootfile boot-cma.emmc` and reboot. Rollback per device = `fw_setenv bootfile boot.emmc`. For extra safety, also update the `fit_boot` env var to fall back to `boot.emmc` when loading/verifying `${bootfile}` fails (the FIT's SHA1 hashes make `bootm` verification meaningful). NOTE: the rootfs (with the patched system's modules) must match the kernel — ship FIT + matching app OTA together and only switch `bootfile` after the OTA validates.

---

## 7. Testing & validation plan

Run in order; each phase gates the next. Get a serial console on the first boot (UART) in case it doesn't come up.

### Phase 1 — Boot integrity

```sh
dmesg | grep -iE "cma|ion"
```
Expect:
- `cma: Reserved 128 MiB at 0x...` (early boot, from the reserved-memory scan)
- **No** `cvitek-ion` probe errors, no ION-related warnings.

```sh
grep -i cma /proc/meminfo
# CmaTotal:  131072 kB
# CmaFree:   ~131072 kB (nothing allocated yet, minus tiny bookkeeping)
free -m   # MemTotal ~ 250 MB: CMA pages COUNT as MemTotal now (carveout didn't!)
```
That last line is the first visible win: **MemTotal goes UP by ~64 MB** vs. the old image (old: 254-64≈190 MB; new: ~250 MB) because the pool is no longer dead-reserved.

```sh
mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /sys/kernel/debug/ion/heaps/* 2>/dev/null; ls /sys/kernel/debug/ion/
# Expect a heap named "carveout" (our masqueraded CMA heap).
```

### Phase 2 — Functional regression (the type-spoof works)

1. **Camera pipeline up** — start the app / sscmex video init. Success proves `sys.ko` → `cvi_ion_alloc(CARVEOUT)` found the heap and `CVI_VB_Init()` allocated pools. Watch `CmaFree` drop by the VB pool total.
2. **Model load** — load the usual `.cvimodel` via sscmex. Success proves `libcviruntime`'s `/dev/ion` heap query found a "carveout" heap. If it logs `no carveout heap found`, the spoof didn't take (check Phase 1 / patch application).
3. **Inference correctness** — run detections against a known input; results must match the old firmware (memory provenance must be invisible to the TPU).
4. **Cached + non-cached paths** — exercise both `CVI_SYS_IonAlloc` and `CVI_SYS_IonAlloc_Cached` users (normal camera+TPU flow covers both); look for image corruption/garbage frames which would indicate cache-attribute trouble on the CMA pages.

### Phase 3 — Elasticity (the actual point)

From IEx on the device, with **no model loaded**:

```elixir
# 1. Linux borrows the idle pool under memory pressure:
hog = for _ <- 1..30, do: :crypto.strong_rand_bytes(5_000_000)  # ~150MB
# in another shell: watch CmaFree shrink — movable pages now live inside the pool
```

```sh
grep -i cma /proc/meminfo   # CmaFree well below CmaTotal while hog is alive
```

```elixir
# 2. TPU reclaims it on demand — load a model WHILE the hog is alive:
{t_us, result} = :timer.tc(fn -> Sscmex.load_model(path) end)
# must succeed: cma_alloc migrates the hog's movable pages out of the pool
```

3. Release the hog (`hog = nil; :erlang.garbage_collect()`), unload/reload the model a few times, record `t_us` each time — this is your model-load latency under pressure vs. idle (expect idle ≈ old carveout speed; pressured = slower; quantify it).

4. **The headline test:** load a model **bigger than the old 64 MB era could hold**. This is the capability we built all this for.

### Phase 4 — Stress & soak

- Loop for hours: video streaming + model load/unload every N minutes + background BEAM memory churn.
- Watch for: `dmesg | grep -i "cma_alloc"` failures (`cma_alloc` warns on failure — the creator passes `no_warn=false`), VB alloc failures (`CVI_ERR_VB_NOMEM` 0xC0018009), TPU load failures, frame drops.
- **Fragmentation probe:** start video first (VB pools pin CMA ranges), then load the largest model, then stop/start video repeatedly. Long-lived pinned ION buffers fragment the pool; this sequence hunts the worst case. If large allocations start failing while `CmaFree` looks sufficient, that's fragmentation — see Risks.
- Reboot loop (20×) for boot reliability; one OTA cycle (A→B→A) to confirm the firmware lifecycle is untouched.

### Phase 5 — Monitoring hooks (recommended)

Expose in the app's telemetry: `CmaTotal/CmaFree` from `/proc/meminfo`, and (optionally, via a tiny NIF or the existing patched export) `cvi_ion_get_memory_state` totals. Alert on model-load failures and `cma_alloc` dmesg events.

---

## 8. Risks, caveats, and rollback

| Risk | Severity | Notes / Mitigation |
|---|---|---|
| Fragmentation: pinned ION buffers (VB pools, loaded models) scatter the pool; a huge contiguous alloc fails despite free CMA | Medium | Allocate big models early; keep pool generous (128 MB); the Phase-4 probe quantifies it. Worst-case mitigation: restart video pipeline around big loads (frees + re-pins compactly). |
| Model-load latency under memory pressure (page migration) | Low/Medium | Measure in Phase 3. Acceptable for load-at-startup/mode-switch; do not hot-swap models per frame. |
| Cache attribute issues on CMA pages (riscv non-coherent DMA) | Low | Same kernel paths as carveout (both regions are in the linear map; ion handles sync); Phase 2.4 covers it. |
| Type-spoof confuses future tooling reading heap types | Cosmetic | Documented in the patch comment; only the `"ion"`-named area is spoofed. |
| `fast_image` accidentally re-enabled with nonzero sizes | High if it happens | It demands fixed physical addresses — incompatible with CMA. Keep `ion-size = <0>`; add a comment in the dtsi. |
| OTA ships rootfs but not the new kernel/DTB | High (silent) | §6. Gate the app on the new system version, or verify `CmaTotal` at runtime and refuse/alert if 0. **A `CmaTotal == 0` check in the app is a cheap, perfect "is the new kernel actually running" probe.** |
| Some unexamined osdrv path allocates with a different heap type | Low | §4 grep before building. |

**Rollback:** the change is fully contained in the system repo — revert the two DTS edits, delete patch 0007, restore `ALLOCATE_ION_HEAP=64`, rebuild. Per-device rollback (if using the alternate-FIT mechanic): `fw_setenv bootfile boot.emmc`. Keep one device on the old firmware during the soak phase as a control.

---

## 9. Future work (optional)

- **Watermark guard:** refuse model load in sscmex when `CmaFree` (minus VB usage) < model size + margin, with a friendly error — better than a generic `load_failed` from `CVI_NN_RegisterModel`.
- **`cma_debugfs` bitmap dumps** in a debug build to visualize fragmentation if Phase 4 shows trouble.
- **Upstreamable variant:** make the spoofed node name a Kconfig string instead of hardcoded `"ion"`.
- Contribute findings back to the reCamera/Milk-V communities — "ION as reusable CMA" appears to be unexplored there (everyone rebuilds with a different `memmap.py`).

## 10. Reference index

**Local files to touch:**
- `patches/linux/0007-ion-report-cma-backed-ion-pool-as-carveout-heap.patch` (new)
- `board/sipeed/recamera/dts/cv181x_default_memmap.dtsi` (ION node → shared-dma-pool)
- `board/sipeed/recamera/dts/cv181x_base.dtsi:111-120` (delete cvitek-ion node)
- `nerves_defconfig:230`, `nerves_defconfig_emmc:228` (ION 64→128)

**Verified sources (pinned):**
- cvitek ion driver (dead `civtek,cma`, type-first matcher): https://github.com/sophgo/linux_5.10/blob/085eec53fc4d1935e6736ddad1d6dce5f755dc20/drivers/staging/android/ion/cvitek/cvitek_ion.c and `cvitek_ion_alloc.c`
- stock CMA heap auto-registration: same tree, `drivers/staging/android/ion/ion_cma_heap.c`
- osdrv hardcoded CARVEOUT: https://github.com/sophgo/osdrv/blob/3639eb492944cff9c398afafa7b8446d377d7119/interdrv/v2/sys/common/sys.c (lines 57, 126); VB: `interdrv/v2/base/vb.c` (221, 452); TPU: `interdrv/v2/tpu/common/cvi_tpu_interface.c`; fast_image: `interdrv/v2/fast_image/fast_image.c`
- middleware (no heap selector): https://github.com/sophgo/middleware — `v2/modules/sys/src/cvi_sys.c` (`ionMalloc`, line ~607)
- cviruntime heap query: https://github.com/sophgo/cviruntime — `src/soc/common/cvi_device_mem.cpp:340-371` (commit `ef80449`)
- Community confirmation that no boot/runtime knob exists on stock firmware: milkv-duo/duo-buildroot-sdk#78; https://community.milkv.io/t/enable-and-add-swap-partition-to-duo-buildroot/411
