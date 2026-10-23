## OndraSD File Manager
File manager used for loading programs into Ondra SPO 186 from SD card using Ondra-SD interface by Martin1 (more info: https://sites.google.com/site/ondraspo186/3-ondra-sd)

Based on Martin1's source codes, with some added functionalities:
- joystick support
- files and directories sorting  (using the "S" key)
- support for the 2/4 MHz CPU switch modification — see below

---

Compile from the repository root with *SjASMPlus*:

`sjasmplus --raw=dist/_ONDRAFM.BIN make.asm`

`make.asm` includes the shared files from `common/`, so it must be assembled with
the repository root as the working directory.

To compile with *TASM* (version 3.2 tested), edit *make.asm* first, as described
in the comment at its beginning (uncomment the `;#define` lines, change ` include`
back to `#include`), then:

`tasm -80 -b make.asm dist/_ONDRAFM.BIN`

The boot loader (`loader/`) and the preloader (`preloader/`) are assembled from
their own directories, see [preloader/README.md](preloader/README.md).

---

### Repository layout

| Path | What |
|---|---|
| `/` | File manager sources (`main.asm`, `mainprn.asm`, `txd.asm`, `loader.asm`, ...). `txd.asm` and `loader.asm` are the file manager's own serial driver. |
| `common/` | Sources shared by the file manager and the loader: `speed.asm` (CPU clock measurement), `beep.asm`. |
| `loader/` | The boot loader loaded by the preloader (`_LOADER2.BIN` on the card). |
| `loader/orig/` | Martin1's original boot loader sent by the interface after reset, kept for reference. |
| `preloader/` | A 122 B replacement for `__LOADER.BIN` that hands the transfer over to the system `LOADER` routine in ROM, so the interface spends far less time transmitting and the `#` + ENTER window becomes much easier to hit. See [preloader/README.md](preloader/README.md) (in Czech). |
| `dist/` | Assembled files to copy to the SD card: `__LOADER.BIN`, `_LOADER2.BIN`, `_ONDRAFM.BIN`. |

---

### 4 MHz CPU switch

Ondra can be modified with a mechanical 2/4 MHz CPU clock switch. Only the CPU
is doubled — the 8253 and the video keep running at the original rate — so every
software delay becomes half as long in real time and the serial link to the
Ondra-SD module falls apart.

A single binary handles both. `CPUDET` in `common/speed.asm` measures the clock against
the system frame counter `FRAMES` (`0D62Fh`), which the ROM interrupt handler
increments 50 times per second regardless of the CPU clock. The switch is
mechanical and can be flipped at any time, so the measurement is repeated before
every action that sends commands to the module (start, directory change, file
load, return to the ROM) — never between a command and its reply, as it takes
20–40 ms with interrupts enabled.

At 4 MHz one 57600 Bd bit cell is 69 T instead of 35 T, which leaves enough room
for a loop, so the 4 MHz send/receive routines are shorter than the unrolled
2 MHz ones. The matching changes in the boot loader are listed in
[changelog.txt](changelog.txt) (in Czech).

Verified in the JOndra emulator with the Ondra-SD module emulated, at both
clocks: the full `__LOADER.BIN` → `_LOADER2.BIN` → `_ONDRAFM.BIN` chain,
directory listing, changing directories and loading a file. Also tried on a
replica of Ondra running at 4 MHz.

Not tested on hardware: flipping the clock while the program is running (hot
switch). The replica has only a plain slide switch; to switch a running CPU
reliably it would need extra circuitry that prevents contact bounce (glitches on
the clock line). The software is written for it (the clock is measured again
before every action that sends commands to the module), but that part is only
verified in the emulator.
