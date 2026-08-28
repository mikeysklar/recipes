# ETM instruction tracing on a Metro RP2350 with a Pi Debug Probe

Full instruction trace of a Cortex-M33 core on an Adafruit Metro RP2350, using
nothing but a Raspberry Pi Debug Probe over SWD. No J-Trace, no parallel trace
port, no code instrumentation.

The trace is captured by the chip itself (ETM -> DMA -> on-chip SRAM) and dumped
over SWD afterwards. That makes it good for bounded, post-mortem snapshots
(what ran just before this breakpoint / hardfault) and not suitable for
continuous real-time trace.

Everything below was run end to end on an x86_64 Linux host. Version numbers in
the last section are the exact ones known to work.

---

## 1. What you need

**Hardware**

| Item | Notes |
|---|---|
| Adafruit Metro RP2350 | Any RP2350 board works. RP2040 has no ETM. |
| Raspberry Pi Debug Probe | Firmware 2.2.0 or newer, see section 3. |
| 3-pin JST-SH to 3-pin JST-SH cable | Ships with the Debug Probe. |
| USB cables | One for the probe, one for the Metro (power). |

**Host software** (all built from source, see section 4)

| Item | Why |
|---|---|
| `raspberrypi/openocd` | Stock distro OpenOCD 0.12.0 has no `target/rp2350.cfg` and will not work. |
| `arm-none-eabi-gdb` | Distro `gdb` is host-arch only. `gdb-multiarch` also works. |
| `czietz/etm-trace-rp2350` | Provides `trace.gdb` with the `trc_*` commands. |
| `czietz/ptm2human` | Trace decoder. Must be this fork, it is the one adapted to Cortex-M33. |
| `pico-sdk` + CMake | Only needed to build the test program in section 7. |

---

## 2. Wiring

The Metro RP2350 has a 3-pin JST-SH **DEBUG** connector. Verified against the
board schematic:

| DEBUG pin | Signal |
|---|---|
| 1 | SWCLK |
| 2 | GND |
| 3 | SWDIO |

That is the same pinout and connector as the Pico 2 debug port and the Debug
Probe's **D** jack, so the JST-SH to JST-SH cable in the Debug Probe box is a
straight plug-in. No adapter, no fly wires.

Power the Metro over its own USB port. The probe does not power the target.

---

## 3. Debug Probe firmware update

OpenOCD detects Debug Probe firmware older than 2.2.0 and silently drops into a
one-packet-at-a-time "low-performance workaround" (it does not pipeline
packets). Trace dumps are large, so this matters. You will see:

```
Warning: *** Old Raspberry Pi Debugprobe firmware detected (1.0.1)
Warning: *** Using low-performance workaround
```

**Check the version without flashing anything.** The firmware version is the USB
`bcdDevice` field.

Linux:
```bash
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  [ "$(cat $d/idVendor)" = "2e8a" ] || continue
  [ "$(cat $d/idProduct)" = "000c" ] || continue
  echo "$(cat $d/serial)  fw=$(cat $d/bcdDevice)"
done
```
Output is packed BCD: `0101` means 1.0.1 (too old), `0231` means 2.3.1 (fine).

macOS:
```bash
system_profiler SPUSBDataType | grep -A6 "Debug Probe"
```
Read the `Version:` line.

**Update procedure**

1. Download `debugprobe.uf2` from
   <https://github.com/raspberrypi/debugprobe/releases/latest>.
   Use `debugprobe.uf2` for the real Debug Probe hardware. `debugprobe_on_pico.uf2`
   is for a bare Pico pressed into service as a probe.
2. Unplug the probe. Hold the **BOOTSEL** button on the probe, plug USB in, release.
3. It mounts as `RPI-RP2`.
4. Copy `debugprobe.uf2` onto it. It reboots itself.
5. Re-run the version check above and confirm 2.2.0 or newer.

---

## 4. Host toolchain build

### OpenOCD with RP2350 support

```bash
git clone https://github.com/raspberrypi/openocd.git ~/openocd-rp2350-build
cd ~/openocd-rp2350-build
./bootstrap
./configure --enable-cmsis-dap --prefix=$HOME/.local/openocd-rp2350
make -j$(nproc)
```

You do not have to `make install`. OpenOCD run in-tree as
`~/openocd-rp2350-build/src/openocd` finds its own `tcl/` scripts. Confirm:

```bash
~/openocd-rp2350-build/src/openocd --version
ls ~/openocd-rp2350-build/tcl/target/rp2350.cfg
```

If `rp2350.cfg` is missing you are looking at the wrong OpenOCD.

Set a shell variable for the rest of this doc:
```bash
OPENOCD=~/openocd-rp2350-build/src/openocd
```

### ARM GDB

Either your distro's `gdb-multiarch`, or the ARM GNU toolchain tarball from
<https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads>, unpacked
somewhere like `~/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/`.

```bash
GDB=~/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gdb
```

### trace.gdb

```bash
git clone https://github.com/czietz/etm-trace-rp2350.git ~/etm-trace-rp2350
```

### ptm2human decoder

Must be the czietz fork. Upstream ptm2human does not decode Cortex-M33 ETMv4
and lacks the `-n` unformatted option.

```bash
git clone https://github.com/czietz/ptm2human.git ~/ptm2human
cd ~/ptm2human
./autogen.sh && ./configure && make
```
Binary lands at `~/ptm2human/ptm2human`.

---

## 5. Find the right probe

If more than one Debug Probe is plugged into the host you must pick the one
actually wired to the Metro, by USB serial.

List serials:
```bash
lsusb -d 2e8a:000c
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  [ "$(cat $d/idVendor)" = "2e8a" ] || continue
  [ "$(cat $d/idProduct)" = "000c" ] || continue
  echo "$(cat $d/serial)"
done
```

Then try each serial. The one connected to the Metro reports both cores
examined. Wrong probes fail with `ADIv6 requires DPv3`.

```bash
$OPENOCD -c "adapter driver cmsis-dap" \
         -c "adapter serial <SERIAL>" \
         -c "adapter speed 4000" \
         -c "transport select swd" \
         -c "source [find target/rp2350.cfg]"
```

A good connection looks like:
```
Info : SWD DPIDR 0x4c013477 DPv3
Info : [rp2350.cm0] Cortex-M33 r1p0 processor detected
Info : [rp2350.cm0] Examination succeed
Info : [rp2350.cm1] Cortex-M33 r1p0 processor detected
Info : [rp2350.cm1] Examination succeed
Info : RP2350 rev 2, QSPI Flash win w25q128fv/jv id = 0x1840ef size = 16384 KiB
Info : [rp2350.cm0] starting gdb server on 3333
```

**Set `adapter speed 4000` explicitly.** The 100 kHz default makes `trc_start`'s
register setup sequence slow enough to trip GDB keepalive warnings.

---

## 6. The one real gotcha: do not halt the core while tracing

This is the thing that will waste your afternoon if nobody tells you.

On `raspberrypi/openocd` commit `098b86f`, **any external debug-halt request
issued while ETM+DMA trace is actively running times out and forces an external
reset of both cores**, which wipes the trace buffer. Reproduced four independent
ways, all failing identically:

| Method | Result |
|---|---|
| GDB Ctrl-C (real pty) | timeout, then external reset |
| OpenOCD telnet `halt` | `timed out while waiting for target halted`, then external reset |
| OpenOCD telnet `mdw` (a plain memory read, no halt requested) | `Failed to read memory`, then external reset |
| A second GDB connecting to the running traced target | the `gdb-attach` auto-halt fails, external reset |

```
Error: timed out while waiting for target halted
Info : [rp2350.cm0] external reset detected
Info : [rp2350.cm1] external reset detected
```

**The workaround: never ask for an external halt.** Put a deliberate
`asm volatile ("bkpt #0")` in the target program after the code you care about.
A `bkpt` is a real CPU exception. If the debugger is already attached
(`C_DEBUGEN` set) before the core reaches it, the core halts cleanly in hardware
with `SIGTRAP`, with no async halt request involved. This works every time, no
timeout, no reset.

**Order matters.** Flash the program, then `monitor reset init` (which halts the
core right at reset) *before* `trc_start`, so the debugger is already attached
when the core reaches the `bkpt`. If you reset-and-run with no debugger attached,
the `bkpt` becomes a HardFault instead.

Nothing upstream documents this. Searched the czietz repo issues and PRs (empty
tracker), the `trace.gdb`/README source, ptm2human, raspberrypi/openocd, and the
open web. One related clue in `trace.gdb`: `trc_start` explicitly aborts the DMA
channel and stops the ETM before configuring anything, but `trc_save` has no
matching teardown on the way out. It only flushes the TPIU formatter and dumps
memory, assuming the core is already halted.

---

## 7. Test program

`main.c`, a bounded amount of work followed by a `bkpt`:

```c
#include "pico/stdlib.h"

static volatile uint32_t counter = 0;

static void __attribute__((noinline)) do_work(void) {
    for (int i = 0; i < 20; i++) {
        counter += i;
        if (counter & 1) {
            counter *= 3;
        } else {
            counter /= 2;
        }
    }
}

int main(void) {
    for (int loop = 0; loop < 5; loop++) {
        do_work();
    }

    asm volatile ("bkpt #0");

    while (1) {
        tight_loop_contents();
    }
}
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH $ENV{HOME}/builds/pico-sdk)
set(PICO_BOARD pico2)

include(${PICO_SDK_PATH}/pico_sdk_init.cmake)

project(etm_test C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(etm_test main.c)
target_link_libraries(etm_test pico_stdlib)
pico_add_extra_outputs(etm_test)
```

`PICO_BOARD=pico2` is fine on a Metro RP2350 for trace purposes. It selects the
right chip and RAM map. Switch it if you need Metro-specific pin definitions.

Build:
```bash
mkdir -p ~/etm_test/build && cd ~/etm_test/build
cmake .. && make -j$(nproc)
```

You get `etm_test.elf`, `etm_test.uf2`, and `etm_test.dis`. Keep the `.dis`
around, it is what you read the decoded trace against.

---

## 8. Flash over SWD

No BOOTSEL button press needed. The core is halted at flash time (it is not
tracing yet), so OpenOCD can just program it:

```bash
$OPENOCD -c "adapter driver cmsis-dap" \
         -c "adapter serial <SERIAL>" \
         -c "adapter speed 4000" \
         -c "transport select swd" \
         -c "source [find target/rp2350.cfg]" \
         -c "program ~/etm_test/build/etm_test.elf verify reset exit"
```

---

## 9. Capture

**Terminal 1**, leave OpenOCD running as a GDB server:

```bash
$OPENOCD -c "adapter driver cmsis-dap" \
         -c "adapter serial <SERIAL>" \
         -c "adapter speed 4000" \
         -c "transport select swd" \
         -c "source [find target/rp2350.cfg]"
```

**Terminal 2**, GDB. The command order below is the part that matters:

```bash
cd ~/etm-trace-rp2350
$GDB -q -nx \
  -ex "set pagination off" \
  -ex "set remotetimeout 15" \
  -ex "target extended-remote localhost:3333" \
  -ex "monitor reset init" \
  -ex "source trace.gdb" \
  -ex "trc_setup" \
  -ex "trc_start" \
  -ex "trc_save trace.bin"
```

What each step does:

| Step | Why |
|---|---|
| `set remotetimeout 15` | The trace setup sequence is slow enough to trip the default. |
| `monitor reset init` | Halts at reset, so the debugger is attached before the `bkpt`. Non-negotiable, see section 6. |
| `source trace.gdb` | Adds `trc_setup` / `trc_start` / `trc_save`. |
| `trc_setup` | Prints and applies config. No args means defaults. |
| `trc_start` | Configures ETM/TPIU/DMA and continues. Returns on the `bkpt` with `SIGTRAP`. |
| `trc_save trace.bin` | Dumps the buffer. |

A good run:
```
(gdb) monitor reset init
[rp2350.cm0] halted due to debug-request, current mode: Thread
(gdb) trc_setup
Trace buffer address: 0x20040000
Trace buffer size: 8192 bytes
DMA channel: 12
Cycle counting: 0
Branch broadcasting: 1
Formatter: 1
Timestamping: 0
(gdb) trc_start

Thread 1 "rp2350.cm0" received signal SIGTRAP, Trace/breakpoint trap.
0x10000272 in ?? ()
(gdb) trc_save trace.bin
```

`SIGTRAP` is the success signal. If you see a timeout or `external reset
detected`, something asked for an external halt. Go back to section 6.

### If GDB needs to be driven programmatically

`trc_start` blocks until the target stops, so a naive pipe into GDB does not
work reliably. Drive it through a pty:

```python
#!/usr/bin/env python3
import os, pty, select, subprocess, time, sys

GDB = os.path.expanduser("~/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin/arm-none-eabi-gdb")
WORKDIR = os.path.expanduser("~/etm-trace-rp2350")
LOG = os.path.expanduser("~/gdb-capture.log")

master, slave = pty.openpty()
proc = subprocess.Popen([GDB, "-q", "-nx"], stdin=slave, stdout=slave,
                        stderr=slave, cwd=WORKDIR, start_new_session=True)
os.close(slave)
logf = open(LOG, "wb")

def drain(timeout):
    end, buf = time.time() + timeout, b""
    while time.time() < end:
        r, _, _ = select.select([master], [], [], max(0, end - time.time()))
        if master in r:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            logf.write(chunk); logf.flush()
    return buf

def send(line, wait=0.5):
    os.write(master, (line + "\n").encode())
    return drain(wait)

send("set pagination off", 0.3)
send("set remotetimeout 15", 0.3)
send("target extended-remote localhost:3333", 2)
send("monitor reset init", 2)
send("source trace.gdb", 0.5)
send("trc_setup", 0.5)
print(send("trc_start", 8).decode(errors="replace"), file=sys.stderr)
send("trc_save trace.bin", 3)
```

---

## 10. Decode

```bash
~/ptm2human/ptm2human -e -i trace.bin > trace_decoded.txt
```

`-e` / `--decode-etmv4` is mandatory for Cortex-M33. Add `-n` / `--unformatted`
if you disabled the TPIU formatter (which you do for endless mode, section 11).

An 8 KiB buffer decodes to roughly 30k lines and around 126 branch records. In
non-endless mode the tail of the buffer runs out mid-packet and the decoder
complains at the end. That is expected, not a failure.

Read the output against `etm_test.dis` to map addresses back to source.

---

## 11. Configuration reference

```
trc_setup [addr] [size] [dmachan] [ccount] [bbroadc] [formatter] [tstamp]
trc_start [endless]
trc_save FILENAME
```

Defaults, which are what the bare `trc_setup` above uses:

| Option | Default | Notes |
|---|---|---|
| Buffer address | `0x2004_0000` | Start of SRAM4. |
| Buffer size | 8192 bytes | |
| DMA channel | 12 | Must be unused by your app. |
| Cycle counting | off | |
| Branch broadcasting | on | Keep it on. Gives an address at every flow change. |
| TPIU formatter | on | Turn off for endless mode. |
| Timestamping | off | |

The buffer and DMA channel must not be touched by your application. If you would
rather the buffer live inside your program, declare
`uint32_t tracebuffer[2048];` and use `trc_setup tracebuffer sizeof(tracebuffer)`.
To find a free DMA channel from inside GDB: `call dma_claim_unused_channel(0)`.

**Endless / circular mode** (`trc_start 1`) keeps the last N kB up to a
breakpoint or exception, which is the mode you want for crash post-mortems. It
requires an 8/16/32 KiB buffer aligned to its own size, and you should disable
the TPIU formatter:

```
trc_setup 0x20040000 8192 12 0 1 0 0
trc_start 1
```
then decode with `ptm2human -e -n -i trace.bin`.

Note that in endless mode `trc_save` passes the filename to a shell. Do not feed
it untrusted input.

---

## 12. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Can't find target/rp2350.cfg` | Distro OpenOCD | Build `raspberrypi/openocd`, section 4. |
| `ADIv6 requires DPv3` | Wrong Debug Probe selected | Try the other serials, section 5. |
| `Old Raspberry Pi Debugprobe firmware detected` | Probe firmware < 2.2.0 | Update firmware, section 3. |
| GDB keepalive warnings during `trc_start` | Adapter at the 100 kHz default | Add `adapter speed 4000`. |
| `timed out while waiting for target halted` + `external reset detected`, trace lost | Something requested an external halt while tracing | Use the `bkpt` method, section 6. Never Ctrl-C, never `halt`, never read memory mid-trace. |
| `bkpt` causes a HardFault instead of `SIGTRAP` | Core resumed with no debugger attached | Do `monitor reset init` before `trc_start`. |
| Decoded output is garbage | Wrong decoder or wrong flags | Use the czietz ptm2human fork, with `-e`, plus `-n` if the formatter was off. |
| Decode ends mid-packet | Non-endless buffer ran out | Expected. Use endless mode if you need a clean tail. |
| No ETM at all | RP2040, not RP2350 | RP2040 has no ETM hardware. |

---

## 13. Known-good versions

| Component | Version |
|---|---|
| OpenOCD | `raspberrypi/openocd` `0.12.0+dev-g098b86f` (2026-07-15), configured `--enable-cmsis-dap` |
| GDB | ARM GNU toolchain 14.2.rel1, `arm-none-eabi-gdb` |
| Debug Probe firmware | 2.3.1 (`bcdDevice` = `0231`) |
| Probe link | CMSIS-DAPv2, SWD, 4000 kHz |
| Target | RP2350 rev 2, Cortex-M33 r1p0, Adafruit Metro RP2350 |
| Flash | Winbond w25q128fv/jv, 16384 KiB |
| pico-sdk | v2.2.0, `PICO_BOARD=pico2` |
| ptm2human | `czietz/ptm2human` at `3d0792f` |
| trace.gdb | `czietz/etm-trace-rp2350` at `15a1e86` |

---

## 14. What this approach is and is not good for

Good for: post-mortem crash snapshots (circular buffer up to a breakpoint or
hardfault), confirming a specific branch or code path actually executed, and
doing it with zero hardware beyond a Debug Probe you already own.

Not good for: continuous or long-duration real-time trace. The capture depth is
bounded by whatever SRAM you dedicate (8 KiB here), and the readout is an SWD
dump afterwards at roughly 300-400 KB/s effective.

For the continuous case you need the real 4-bit parallel trace port
(TRACECLK + TRACEDATA0-3) wired to a MIPI-20 connector and a SEGGER J-Trace,
which is ~600 Mbit/s straight into the probe's own trace memory, independent of
halt state. See <https://github.com/hathach/pcb/tree/main/pico2_trace_motherboard>.
Signal integrity is real there: fly wires corrupted at 80 MHz core / 40 MHz trace
clock, and a proper board with source termination, short length-matched traces
and ground guards runs clean at 150 MHz.

---

## 15. Upstream links

* Trace scripts: <https://github.com/czietz/etm-trace-rp2350>
* Decoder: <https://github.com/czietz/ptm2human>
* OpenOCD: <https://github.com/raspberrypi/openocd>
* Debug Probe firmware: <https://github.com/raspberrypi/debugprobe/releases/latest>
* RP2350 datasheet (debug infrastructure, DMA of trace data): <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>
* ARM ETMv4 architecture spec: <https://developer.arm.com/documentation/ihi0064/latest/>
* CoreSight ETM-M33 TRM: <https://developer.arm.com/documentation/100232/latest/>
* CoreSight SoC-600M TRM (funnel, TPIU): <https://developer.arm.com/documentation/100806/latest/>
