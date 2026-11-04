# LCUExtract

A lightweight, standalone batch processing framework designed to reverse-engineer and unpack modern Windows 10 and Windows 11 Cumulative Updates (`.msu`). It programmatically bypasses the limits of native Windows utilities by extracting embedded delta payloads using isolated binary decoders.

## System Requirements

- **Windows x64 Systems:** Works natively on Windows 10 and later.
- **ARM64 Systems:** Requires Windows 11 at least. This is because Windows 10 on ARM lacks the x64 emulation layer required to run the 64-bit extraction tools included in this project.

## Features

- **Automated UAC Elevation:** Relaunches itself seamlessly with full administrative privileges.
- **Pre-execution Verification:** Validates environment files and ensures a target `.msu` file exists before runtime to avoid blank folder creation.
- **Delta Payloads Resolution:** Leverages `PSFExtractor` and `msdelta` APIs to parse `express.psf.cix.xml` files, eliminating `0x80070002 (File Not Found)` extraction errors.
- **Flexible Compression Deployment:** Offers an interactive choice at the finish line to clean up loose bytes and recompress raw structures directly into solid `LZX:100` ESD packages.

## Workspace Directory Structure

To use this tool, organize your local working directory exactly like this:

```text
📁 LCUEXTRACT/
│
├── Extract.cmd            <-- The main execution script
│
└── Files/                 <-- Native decoding binary core
    ├── 7z.dll
    ├── 7z.exe
    ├── dpx.dll
    ├── expand.exe
    ├── libwim-15.dll
    ├── msdelta.dll
    ├── PSFExtractor-x64.exe
    └── wimlib-imagex.exe
```

## How To Use

1. Download or clone this repository.
2. Drop your target Windows Update archive (e.g., `Windows11.0-KB5xxxxxx-x64.msu`) directly into the root `LCUEXTRACT` folder right next to `Extract.cmd`.
3. Right-click `Extract.cmd` and select **Run as Administrator** (or double-click and let the script handle the elevation prompt).
4. Follow the interactive prompts in the command window.

### Deployment Instructions

Once the process finishes, the script prints out your custom installation commands based on your compilation choice:

* **If you chose NOT to compress (Loose Files):**
  ```cmd
  Dism.exe /Online /add-package /packagepath:"C:\LCUEXTRACT\LCUEXT\[FolderName]\update.mum"
  ```

* **If you chose to compress (ESD Package):**
  ```cmd
  Dism.exe /Online /add-package /packagepath:"C:\LCUEXTRACT\LCURPK\[PackageName].esd"
  ```

## Credits & Tooling Dependencies

This wrapper leverages components from the following open-source deployment tools to handle extraction mechanics:
- **7-Zip** for initial container decomposition.
- **wimlib-imagex** for high-efficiency structural extraction and LZX capturing.
- **PSFExtractor** for translating internal Patch Storage File byte-differentials.
