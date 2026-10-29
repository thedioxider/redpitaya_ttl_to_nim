# redpitaya_ttl_to_nim

TTL2NIM converter for Red Pitaya (Zynq `xc7z010clg400-1`).\
Project created for Vivado 2025.2.

## How to use the project

### Layout

| Path                   | Contents                                                                                             |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `src/`                 | Verilog sources                                                                                      |
| `constraints/`         | XDC constraints                                                                                      |
| `recreate_project.tcl` | Project settings + block design, exported from Vivado                                                |
| `export_project.tcl`   | Regenerates `recreate_project.tcl`                                                                   |
| `redpitaya_genbin.sh`  | Converts Vivado's `.bit` into Red Pitaya's `.bit.bin`                                                |
| `design.info`          | Facts about the FPGA design (name, delay widths, GPIO address); change only together with the design |

The Vivado project is generated into `build/`. Generated bitstreams go to `out/`.

### Restore the project

From the repo root:

```bash
vivado -mode batch -notrace -source recreate_project.tcl
```

This creates the project in `./build/`. Open `build/redpitaya_ttl_to_nim.xpr` in Vivado.

- Must be run from the repo root — source paths in the script are relative to it.
- Requires the same Vivado version (2025.2). The embedded block design refuses to build on other versions.

### Save changes

**Verilog / XDC edits:** nothing to export, just commit `src/` and `constraints/`.

**Block design, project settings, or added/removed files:** re-export the script, then commit it. In the Vivado Tcl console:

```tcl
source -notrace [get_property DIRECTORY [current_project]]/../export_project.tcl
```

### Tips

- Keep new sources in `src/` / `constraints/`. Add them via _Add Sources_ **without** "Copy sources into project", otherwise they get copied into the ignored `build/` and the script won't find them on restore.
- Restoring fails if `build/` already exists: remove `build/` first.
- Don't use incremental synthesis with a reference checkpoint (`utils_1`): the `.dcp` is ignored, so the restore would fail on a missing file.

### How to run on Red Pitaya

1. In Vivado, run implementation, then generate bitstream.
2. Convert the `.bit` implementation file to the `.bit.bin` bitstream format with `./redpitaya_genbin.sh`:
   - Without arguments, it finds the bitstream in `./build/redpitaya_ttl_to_nim.runs/impl_*/` and writes `./out/<name>.bit.bin`, with `<name>` from `design.info`.
   - With a path, e.g. `./redpitaya_genbin.sh ./build/path/to/<top_module_name>`, it writes `<top_module_name>.bit.bin` next to the `.bit`.
   - Ensure that `bootgen` is in the PATH. It ships with Vivado/Vitis.
3. Copy the bitstream file to Red Pitaya. For example:
   ```sh
   scp ./out/ttl2nim.bit.bin root@rp-xxxxxx.local:/tmp/ttl2nim.bit.bin
   ```
4. On Red Pitaya, run:
   ```sh
   fpgautil -b /tmp/ttl2nim.bit.bin
   ```
