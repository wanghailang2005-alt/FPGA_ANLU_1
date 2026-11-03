from pathlib import Path
import importlib.util,json
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('font_verify',root/'tools/verify_font_rom.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
mod.NETLIST=root/'caption_scroll_evidence/font_gate_probe.v'
mod.EVIDENCE=root/'caption_scroll_evidence/font_rom_init.json'
raise SystemExit(mod.main())
