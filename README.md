# redpitaya_ttl_to_nim

TTL2NIM converter for Red Pitaya (Zynq `xc7z010clg400-1`).\
Project created for Vivado 2025.2.

## How to use the project

### Layout

| Path                   | Contents                                              |
| ---------------------- | ----------------------------------------------------- |
| `src/`                 | Verilog sources                                       |
| `constraints/`         | XDC constraints                                       |
| `recreate_project.tcl` | Project settings + block design, exported from Vivado |
| `export_project.tcl`   | Regenerates `recreate_project.tcl`                    |

The Vivado project is generated into `build/`.

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
- Block-diagram layout (block positions) is not stored in the script; Vivado auto-arranges on restore.
- Don't use incremental synthesis with a reference checkpoint (`utils_1`): the `.dcp` is ignored, so the restore would fail on a missing file.
