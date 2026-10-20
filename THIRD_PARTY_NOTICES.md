# Third-party notices

Glyphs for A-Z, 0-9, slash, period and semicolon derive from:
- Project: danchitnis/FPGA-text-overlay
- Source: ISE_project/char_ROM.v
- Commit: 69ed5178d917a5b1455389ce69386b20471f7294
- URL: https://github.com/danchitnis/FPGA-text-overlay/blob/69ed5178d917a5b1455389ce69386b20471f7294/ISE_project/char_ROM.v
- Copyright (c) 2007 Danial Chitnis
- License: MIT; full text in LICENSE.FPGA-text-overlay.

Changes: ASCII remapping; per-row query; 8x8 rows repeated vertically to
produce an 8x16 cell; high-active reset; request valid; deterministic blank
outputs; synchronous one-stage response. Colon, minus and plus bitmaps are
new additions. Space and unsupported encodings are blank.

The testbench contains whole-glyph fixtures derived from the same attributed
glyph artwork. It does not read DUT state. Its indexing calculation differs
from the RTL, and it tests request/response timing and reset behavior.

No Xilinx tile_ram, generated netlist, bitstream or vendor simulation library
is included. Root MIT licensing does not override the vendor restrictions in
those excluded files.
