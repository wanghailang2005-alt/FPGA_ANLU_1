"""Verify initialized font bits in a read-only TD gate-netlist export.

Run verify_font_rom.tcl with td_commands_prompt.exe first, then this script
with Python. Only the explicit temporary font_gate_probe.v is removed after
successful comparison. Vendor netlist content is never copied into evidence.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]
NETLIST = ROOT / "spectrum_sim/rom_init_probe/font_gate_probe.v"
FONT_RTL = ROOT / "src/user_source/hdl_source/OSD/osd_overlay.v"
GATE_DB = ROOT / (
    "src/td_project/HDMI1.4b_Transmitter_v1.0_Runs/syn_1/"
    "HDMI1.4b_Transmitter_v1.0_gate.db"
)
EVIDENCE = ROOT / "spectrum_evidence/font_rom_init.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def words_digest(rows: list[int]) -> str:
    packed = b"".join(struct.pack("<H", word) for word in rows)
    return hashlib.sha256(packed).hexdigest()


def verify() -> dict:
    require(NETLIST.is_file(), "Run tools/verify_font_rom.tcl before this verifier")
    require(GATE_DB.is_file(), "Missing completed synthesis gate database")
    require(
        NETLIST.stat().st_mtime_ns >= GATE_DB.stat().st_mtime_ns,
        "Temporary netlist predates the gate database; export it again",
    )
    gate_hash_before = digest(GATE_DB)
    rtl_hash_before = digest(FONT_RTL)
    netlist_hash = digest(NETLIST)
    netlist_size = NETLIST.stat().st_size
    text = NETLIST.read_text(encoding="utf-8")
    rtl = FONT_RTL.read_text(encoding="utf-8")
    function = re.search(
        r"function\s*\[15:0\]\s*zh_glyph_row\s*;(.*?)endfunction", rtl, re.S
    )
    require(function is not None, "Cannot find the source 16-bit font-row function")
    glyph_entries = re.findall(
        r"7'd(\d+)\s*:\s*bmp\s*=\s*256'h([0-9a-fA-F]+)", function[1]
    )
    glyphs = {int(index): int(bitmap, 16) for index, bitmap in glyph_entries}
    require(bool(glyphs), "Source font table is empty")
    require(len(glyphs) == len(glyph_entries), "Duplicate source glyph IDs")
    require(all(0 <= index < 128 for index in glyphs), "Source glyph ID exceeds 7 bits")
    require(
        re.search(r"default\s*:\s*bmp\s*=\s*256'h0\s*;", function[1]) is not None,
        "Unused source glyph IDs no longer default to zero",
    )
    expected = [
        (glyphs.get(address // 16, 0) >> (16 * (15 - address % 16))) & 0xFFFF
        for address in range(2048)
    ]
    actual = [0] * 2048
    instances = []
    used_bits = 0
    primitive = re.compile(
        r"EG_PHY_BRAM\s*#\((.*?)\)\s*(\\[^\s]+)\s*\((.*?)\);", re.S
    )
    for match in primitive.finditer(text):
        parameters, name, ports = match.groups()
        if "u_osd_overlay/zh_row" not in ports:
            continue
        output_slice = re.search(
            r"\\u_osd_overlay/zh_row\s*\[(\d+):(\d+)\]", ports
        )
        require(output_slice is not None, f"Unexpected font output mapping: {name}")
        high_bit, low_bit = map(int, output_slice.groups())
        require(
            high_bit - low_bit == 3 and low_bit in (0, 4, 8, 12),
            f"Unexpected font BRAM slice: {name}",
        )
        require('.WEAMUX("0")' in parameters, f"Font primitive is writable: {name}")
        require('.MODE("SP8K")' in parameters, f"Unexpected font BRAM mode: {name}")
        require(
            '.DATA_WIDTH_A("4")' in parameters,
            f"Unexpected font BRAM width: {name}",
        )
        require("2'b11" in ports, f"Unexpected font address alignment: {name}")
        init_pairs = re.findall(
            r"\.INIT_([0-9a-fA-F]{2})\(256'h([0-9a-fA-F]+)\)", parameters
        )
        init = {int(index, 16): int(value, 16) for index, value in init_pairs}
        require(
            len(init_pairs) == 32 and set(init) == set(range(32)),
            f"Incomplete font INIT_00..INIT_1F parameters: {name}",
        )
        image = sum(value << (index * 256) for index, value in init.items())
        values = [(image >> (address * 4)) & 0xF for address in range(2048)]
        mismatches = [
            address
            for address, (value, row) in enumerate(zip(values, expected))
            if value != ((row >> low_bit) & 0xF)
        ]
        require(
            not mismatches,
            f"Font INIT mismatch in {name}; first addresses: {mismatches[:8]}",
        )
        require(not used_bits & (0xF << low_bit), f"Duplicate font slice: {name}")
        used_bits |= 0xF << low_bit
        for address, value in enumerate(values):
            actual[address] |= value << low_bit
        instances.append(
            {
                "instance": name.lstrip("\\"),
                "primitive": "EG_PHY_BRAM",
                "mode": "SP8K",
                "data_width": 4,
                "output_bits": [high_bit, low_bit],
                "init_parameters": len(init),
                "nonzero_init_parameters": sum(value != 0 for value in init.values()),
                "matched_rows": 2048,
            }
        )
    require(len(instances) == 4, f"Expected four font BRAMs, found {len(instances)}")
    require(used_bits == 0xFFFF, "Font BRAMs do not cover all 16 output bits")
    require(actual == expected, "Reconstructed font words differ from the source")
    require(digest(GATE_DB) == gate_hash_before, "Gate database changed during verification")
    require(digest(FONT_RTL) == rtl_hash_before, "Font source changed during verification")
    evidence = {
        "status": "PASS",
        "device": "EG4S20BG256",
        "tool": "Tang Dynasty 6.2.168116",
        "verification": (
            "Read-only import of the completed synthesis gate database; export "
            "Verilog; decode each INIT_00..INIT_1F as consecutive low-nibble-first "
            "words, reconstruct 16-bit rows from all four BRAM output slices, "
            "compare all 2048 rows against the source glyph function."
        ),
        "font_bram_instances": len(instances),
        "glyphs": len(glyphs),
        "matched_rows": len(expected),
        "matched_bits": len(expected) * 16,
        "unused_glyph_rows_zero": (128 - len(glyphs)) * 16,
        "word_hash_format": "2048 unsigned 16-bit words in little-endian address order",
        "expected_rows_sha256": words_digest(expected),
        "netlist_rows_sha256": words_digest(actual),
        "font_rtl_path": FONT_RTL.relative_to(ROOT).as_posix(),
        "font_rtl_sha256": rtl_hash_before,
        "netlist_source": GATE_DB.relative_to(ROOT).as_posix(),
        "netlist_source_sha256": gate_hash_before,
        "export_command": (
            "import_device eagle_s20.db -package EG4S20BG256; "
            "import_db <gate.db>; write_verilog font_gate_probe.v -nolf -constnet"
        ),
        "exported_netlist_sha256": netlist_hash,
        "exported_netlist_bytes": netlist_size,
        "exported_netlist_retained": False,
        "instances": instances,
        "scope": (
            "Confirms initialized font data in synthesized EG_PHY_BRAM "
            "primitives. Does not claim a new board test."
        ),
    }
    # This is one fixed file under this project, never a recursive cleanup.
    NETLIST.unlink()
    return evidence


def main() -> int:
    try:
        evidence = verify()
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(
            json.dumps(evidence, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(
            f"FONT ROM PASS: {evidence['font_bram_instances']} BRAMs, "
            f"{evidence['matched_rows']} rows, {evidence['matched_bits']} bits; "
            "temporary full netlist removed"
        )
        return 0
    except (OSError, ValueError) as error:
        EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
        EVIDENCE.write_text(
            json.dumps({"status": "FAIL", "error": str(error)}, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"FONT ROM FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
