# OBJ_TRN

Considerations:

* Firstly, you need to send the patch to allow use of `OBJ_TRN` as it is stubbed out in the SGB BIOS
* Make sure to send `OBJ_TRN` before `PCT_TRN`. This will ensure the border fading in does not clear `OBJ_TRN`s palettes
* You may want to prevent use of the SGB menu which will overwrite OAM tile data, and set OBJ palettes

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
