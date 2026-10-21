# rutrapc

**rutrapc** is a custom FPGA-based computer architecture targeting the **Sipeed Tang Nano 9K**. It features a custom CPU core (`rutracpu`), an onboard GPU (`rutragpu`) with DVI/HDMI output, and UART interfaces for serial communication and code loading.

---

## Hardware Setup (Tang Nano 9K)

### Prerequisites
- [Gowin EDA](https://www.gowinsemi.com/en/support/download_eda/) 
- Sipeed Tang Nano 9K board connected via USB-C

### Building & Flashing the Bitstream

1. **Open Project:**
   Launch Gowin EDA and open `rutrapc.gprj`.

2. **Synthesize & Place & Route:**
   - Double-click **Synthesize** under the Process panel.
   - Double-click **Place & Route** to generate the bitstream (`impl/pnr/rutrapc.fs`).

3. **Program the FPGA:**
   - Connect your Tang Nano 9K board via USB.
   - Open **Gowin Programmer** inside Gowin EDA.
   - Select device `GW1NR-9C` and load `impl/pnr/rutrapc.fs`.
   - Program to **SRAM or Embedded Flash** (SRAM for temporary, Flash for persistent).

---

## Python Assembler & Utilities

The project includes Python utilities for assembling machine code and transmitting binary programs to `rutrapc` over UART.

### Prerequisites & Installation

Requires Python and `pyserial`.

Using [`uv`](https://github.com/astral-sh/uv):
```
uv sync
```

### Assembling & Loading Code

1. **Assemble Source File:**
   Run your assembly script on your target assembly program:
   ```
   python assembler.py program.asm
   ```

2. **Send Binary via UART:**
   Use the serial transmission tool to load the binary file into the board:
   ```
   python upload.py program.bin COM5
   ```

