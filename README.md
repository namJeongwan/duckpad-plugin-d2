# Duckpad D2

Optional native D2 preview plugin for Duckpad. **Version 0.1.0.**

Install **D2** from **Plugins Admin → Available Plugins**, or download the
[release ZIP](https://github.com/namJeongwan/duckpad-plugin-d2/releases/tag/v0.1.0),
extract it and select the `.duckpad-plugin` folder using **Install Plugin**.

Preview the active document or a chosen file, zoom/fit, open a larger preview
window and export PNG or SVG. Eight UI locales match Duckpad. Ctrl+W closes the
dock. Source is rendered locally and does not modify editor text or Undo.

Requires macOS 13+, native ABI v1 and host API **1.6.0** (Duckpad **0.18.0**).
Duckpad 0.17.0 (API 1.5.0) cannot load this plugin. Use Settings to explicitly
download and verify D2 0.9.0, or choose a compatible local executable. Rendering
runs in the authenticated host helper with network and private-file reads denied.
The first version supports the root board and Dagre layout; external imports,
images and alternate layout engines are unsupported.

## Build

Build against the Duckpad **v0.18.0** checkout containing `SDK/DiagramPreview`.

```sh
bash scripts/build.sh native /path/to/duckpad
# Both Apple Silicon and Intel:
bash scripts/build.sh universal /path/to/duckpad
```

The output is `dist/com.duckpad.d2.duckpad-plugin`. Build output uses ad-hoc
Mach-O signing. Publisher signing requires an existing private key kept outside
the repository; scripts never generate or rotate it:

```sh
swift scripts/sign.swift dist/com.duckpad.d2.duckpad-plugin
swift scripts/verify.swift dist/com.duckpad.d2.duckpad-plugin
```

Install the signed folder using Plugins Admin → Install Plugin in a compatible
host. Distribution and local builds use ad-hoc Mach-O signing and publisher package
signatures, without Apple notarization.

## Verification and shared source

From the matching Duckpad checkout:

```sh
bash SDK/DiagramPreview/test.sh /path/to/duckpad-plugin-d2 /path/to/duckpad-plugin-mermaid
```

The shared UI/controller/WebKit sources compile into each plugin module and are
maintained in Duckpad's `SDK/DiagramPreview`; the host C ABI wrapper is compiled
from `SDK/DuckpadNative`. UI/lifecycle conventions derive from Duckpad PlantUML.
Native plugin installation is a code-trust boundary; it does not sandbox arbitrary
plugin code. Source is bounded to 512 KiB, SVG/PNG output to 32 MiB; PNG snapshots
are bounded to 8192 pixels per axis and 16 million pixels. Closing cancels work
and rejects late results.
