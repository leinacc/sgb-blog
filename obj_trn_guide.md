# OBJ_TRN

Considerations:

* Firstly, you need to send the patch to allow use of `OBJ_TRN` as it is stubbed out in the SGB BIOS
* Make sure to send `OBJ_TRN` before `PCT_TRN`. This will ensure the border fading in does not clear `OBJ_TRN`s palettes
* You may want to prevent use of the SGB menu which will overwrite OAM tile data, and set OBJ palettes
* The last row of tilemap will be whited out. If you have a border, cover that last row. If not, make sure your game melds well with the white (make most of your backgrounds white/have a bottom status bar/etc)
* Use this [guide](https://gbdev.io/pandocs/SGB_Command_Border.html#sgb-command-18--obj_trn) to see how setting up GB tile data and tilemap for the last GB row affects your custom SNES objects

## Patch: allowing use of OBJ_TRN

Uses SNES RAM from $800 to $802, and $900 to $915

```
    db $79, $00, $09, $00, $0b, $ad, $c2, $02, $c9, $18, $d0, $0e, $af, $db, $ff, $00
    db $79, $0b, $09, $00, $0b, $c9, $00, $f0, $03, $4c, $25, $c9, $4c, $28, $c9, $60
    db $79, $00, $08, $00, $03, $4c, $00, $09
```

## Patch: disabling the SGB menu

Uses SNES RAM from $818 to $826

```
    db $79, $18, $08, $00, $0b, $c9, $03, $d0, $0a, $a9, $28, $8d, $43, $0c, $68, $68
    db $79, $23, $08, $00, $04, $4c, $f6, $ce, $60
```

## Sending tile data for OBJ_TRN

```
; `DATA_TRN` to $7eb000 (OBJ tile data buffer)
    db ($10<<3)|1, $00,$b0,$7e

; `DATA_SND` 2 bytes to $0211, to update vram $a000-$afff (replace last byte with 3 to update vram $b000-$bfff)
    db ($0f<<3)|1, $11,$02,$00, $02, $01,$02

; `DATA_SND` a byte for the NMI vector to DMA the data
    db ($0f<<3)|1, $17,$02,$00, $01, $01
```
