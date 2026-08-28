# P4HIL: driving real hardware from an LLM

Notes from bringing up three Adafruit P4 Hardware-in-the-Loop boards with Claude
Code, 2026-08-15 to 2026-08-19. Written for Anthropic. The interesting part is
not that it worked, but which parts worked and which parts needed catching.

## Why

Embedded firmware has a class of bug that cannot be unit tested. USB enumeration,
bus timing, power sequencing and peripheral clocking only fail on real silicon,
under a real host, with a real cable. CircuitPython ships for hundreds of boards,
so "it built" is a long way from "it works".

The usual answer is a hardware-in-the-loop farm: real boards, permanently wired,
driven by CI. The usual problem is that the farm is a physical place. You debug
it by standing next to it.

## What

P4HIL is a test fixture built around an ESP32-P4. A development board drops into
a socket, and the fixture:

- powers it through a software controlled load switch, so it can be power cycled
- drives and reads all 39 of its header pins through three I2C expanders
- measures its current draw through an INA219
- captures its pins as a 16 channel logic analyzer via the PARLIO peripheral
- **re-exports its USB over Ethernet using USB/IP**

That last item is the one that matters here. The device under test does not
appear on the machine you are sitting at. It appears on the network.

## How an LLM interacts with it

Every capability is reachable as text over a socket. Nothing requires physical
presence, a GUI, or a vendor tool.

| Surface | Protocol | Used for |
|---|---|---|
| Discovery | mDNS `_usbip._tcp` | Find boards without knowing addresses |
| Fixture control | HTTP + JSON | Pin direction, level, power, config |
| Device under test | USB/IP, TCP 3240 | Its actual USB, from anywhere |
| Logic analyzer | SUMP over a virtual CDC | Captures, at 80 MHz |
| Pin harness | SCPI over a virtual CDC | Scripted stimulus |

So an agent discovers boards, reads their state, drives their pins, and talks
raw USB to whatever is plugged into them, using ordinary sockets. A worked
example, reading a file off a Raspberry Pi Pico's bootloader drive without
touching the Pico:

```python
be = get_backend(host="10.42.0.202", port=3240)
d  = usb.core.find(idVendor=0x2e8a, idProduct=0x000f, backend=be)
# then SCSI INQUIRY, READ CAPACITY, READ(10), walk the FAT
```

```
INQUIRY   vendor=RPI  product=RP2350  rev=1
INFO_UF2.TXT:
  UF2 Bootloader v1.0
  Model: Raspberry Pi RP2350
  Board-ID: RP2350
```

The fixture is 30 miles away. The transcript is identical either way.

## What that made possible

Over four days, working only over SSH and these sockets:

- Diagnosed an unpublished firmware component precisely enough that the author
  pushed it the same day
- Root caused a regression where virtual USB devices died on their first
  transfer, traced to `vTaskDelete(NULL)` deleting the calling task on an inline
  code path
- Found PSRAM silently disabled in every board profile, so the logic analyzer
  was running on a 16 KB buffer while reporting 33 MB
- Measured a live I2S bus on a device under test and identified it from first
  principles: 16.0 kHz frame clock, 512.8 kHz bit clock, ratio exactly 32, which
  is 16 bit stereo
- Commanded a device under test to emit 100 kHz, 250 kHz and 500 kHz, measured
  all three exactly, and used the result to derive the pin mapping empirically
- Wrote a fleet health check that immediately caught a board silently returning
  quarter length captures
- Filed 12 pull requests and 5 issues upstream, all verified on hardware

## Where it went wrong

Three claims did not survive checking. All three were mine, all three were
confidently stated, and all three were caught before or shortly after leaving
the building.

**A firmware bug that was not one.** A pin toggle endpoint looked like a no-op on
expander pins, and the mechanism seemed obvious. Reading the source before
filing showed the function handled those pins correctly. Retesting by measuring
the pin itself, rather than a line one hop downstream, showed it toggling
perfectly. The original evidence had been real, but it was evidence of something
else.

**A timing conclusion argued in both directions, twice.** Whether a sample rate
divider was honoured came down to timing an operation. Elapsed time cannot
distinguish a fast success from an early return, and a later attempt to settle
it mis-unpacked one channel of data using a four channel layout, producing a
number exactly four times off. It remains unresolved and deliberately unfiled.

**A health check that reported healthy hardware as down.** Run under an
interpreter missing a Python package, it marked three working boards `DOWN,
ATTENTION REQUIRED`. A missing host package had been rendered as a hardware
fault.

## What actually helped

The corrections above share a shape, and so do the fixes.

**Measure the thing, not a proxy for it.** The false bug came from reading a pin
downstream of the one under test. The health check now judges the logic analyzer
by returned byte count, never elapsed time, because that is precisely the
distinction that produced two wrong conclusions.

**Read the source before claiming a root cause.** A review gate that requires
naming the mechanism, not just the symptom, is what killed the false bug report
one step before it reached a maintainer. Symptom reports waste reviewer time,
and this project's maintainers say so explicitly.

**Controls, not single observations.** Every filed claim carries a before and
after on the same board, or the same test across three boards, or ten trials.
The reports also state what the cause is *not*: not I2C, not connection setup,
not the pin type.

**Test the test.** The health check was proven by injecting the exact fault it
was built to catch. That is how we discovered it had been hardened into
uselessness: a change that made it robust also made it silently repair the
condition instead of reporting it. A monitor that has only ever printed PASS has
not been tested.

**Say "unknown" out loud.** The clearest single improvement to the tooling was a
message reading *"The board state is unknown, not bad. Nothing was tested."* A
check that cannot reach its subject has to say so rather than guess.

## The shape of it

An LLM with a network socket and real hardware on the other end can do genuine
engineering work: reproduce faults, bisect them, measure with instruments,
verify fixes and submit them upstream. It can also produce a confident, wrong,
well formatted root cause, which is more expensive than saying nothing.

What separated the two here was not model capability. It was whether a claim had
a control, a source citation, and a measurement of the actual quantity rather
than something correlated with it. The fixture is what makes those checks cheap
enough to run every time, because the instruments are one socket away.
