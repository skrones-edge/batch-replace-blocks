# BLOCKSYNC AutoLISP Routine

This repository contains a small AutoLISP routine for exporting selected block definitions from an AutoCAD drawing to .dwg files and later importing them back into another drawing.

## What it does

The routine adds a command named BLOCKSYNC with two subcommands:

- Export: select block references in the current drawing and export each unique block as a .dwg file into a chosen folder.
- Import: import the .dwg files from a chosen folder back into the current drawing.

### How the workflow works

The export side uses AutoCAD's WBLOCK command to save each selected block definition as an independent DWG file. This makes the output portable and easy to reuse later.

The import side is a bit more deliberate. It first splits the discovered files into two groups:

- blocks that already exist in the current drawing, and
- blocks that do not yet exist.

Existing blocks are handled first so they can be redefined before any new blocks are introduced. For each imported file, the routine uses the INSERT command with a special name-and-path form such as Name=path, which tells AutoCAD to pull the block definition from the DWG file on disk. The insert is performed at 0,0 and the temporary object is removed immediately afterward, so the drawing stays clean and the block definition is updated without leaving behind stray geometry.

The script also temporarily suppresses some prompt-heavy AutoCAD behavior by changing system variables such as CMDECHO, FILEDIA, and REGENMODE. That keeps the batch operation quieter and reduces unnecessary command-line interruptions while many blocks are being processed.

## Installation

1. Open AutoCAD.
2. Load the file [block-sync.lsp](block-sync.lsp) using APPLOAD or drag it into the AutoCAD window.
3. Type BLOCKSYNC at the command line to run it.

## Usage

### Export blocks

1. Run BLOCKSYNC.
2. Choose Export.
3. Select the block references you want to export.
4. Choose an output folder.
5. The script writes one .dwg file per selected block into that folder.

### Import blocks

1. Run BLOCKSYNC.
2. Choose Import.
3. Choose the folder that contains the .dwg files.
4. The routine will:
   - redefine existing block definitions first,
   - import new block definitions afterward,
   - insert each block at 0,0 as a temporary insert,
   - erase the temporary inserted entity immediately.

## Notes for maintainers

- The import logic intentionally uses a temporary INSERT/erase cycle so the drawing does not accumulate temporary geometry.
- The script temporarily suppresses some prompt-heavy AutoCAD behaviors with system variables such as CMDECHO, FILEDIA, and REGENMODE during batch processing.
- If you modify the import logic, preserve the temporary insert-and-erase pattern unless you have a specific reason to change it.

## Files

- [block-sync.lsp](block-sync.lsp): main AutoLISP implementation.
