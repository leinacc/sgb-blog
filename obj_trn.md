# OBJ_TRN

`OBJ_TRN` is one of the documented packet commands that can be sent to the SGB, but was not used in commercial games, and was even stubbed in the SGB BIOS (its handler just has `rts`).

It allowed you to display custom SNES-quality 4bpp sprites without writing SNES code. You would just write SNES OAM data to Gameboy VRAM (Nintendo describes writing it to the last tilemap row), and the SGB BIOS would pick it up and transform it into SNES sprites.

In order to not show artifacts due to non-graphical data appearing on the screen, OBJ_TRN would specifically hide the last tilemap row.

It had conflicts with some other SGB capability:

* Generic palette fading - usually when fading happens (borders/certain sub-menus/etc), all palettes are faded. `OBJ_TRN` lets you set OBJ palettes that were sent via PAL_TRN, but these are quickly overridden when a generic SGB fade in happens.

* OAM update code - when the SGB needs to display sprites (menu cursor/attract mode/etc), the SGB BIOS will run its update code in place of `OBJ_TRN`'s specific update code. These scenarios also override OAM tile data.

## Preventing conflicts

The above could be prevented by disallowing use of the SGB menu, and making sure not to send a border, though there was no official way to do this. The following relevant code, run in a loop, in the BIOS might shine a light on how we could do this:

```
    jsr CheckShouldOpenSGBMenu                   ; $cee0 : $20, $06, $cf
    jsr JmpDmaTransferNewGBScreenRows            ; $cee3 : $20, $90, $ff
    jsr TryCheckingUnlocksBtnsState.l            ; $cee6 : $22, $7d, $dd, $01
    lda #$03                                     ; $ceea : $a9, $03
    jsr wMiscSGBEventsHook                       ; $ceec : $20, $18, $08
    jsr JmpDmaTransferNewGBScreenRows            ; $ceef : $20, $90, $ff
    jsr UpdateFramesHeldRL.l                     ; $cef2 : $22, $b8, $d9, $01
    jsr JmpDmaTransferNewGBScreenRows            ; $cef6 : $20, $90, $ff

...

CheckShouldOpenSGBMenu:
; Jump away if we've held L and/or R too long
    lda wFramesHeldP1JoyRL.w                     ; $cf06 : $ad, $43, $0c
    cmp #$28                                     ; $cf09 : $c9, $28
    beq @checkP2                                 ; $cf0b : $f0, $20

; Jump away if a non-LR button is also held
    lda wJoy1High.w                              ; $cf0d : $ad, $12, $0f
    bne @checkP2                                 ; $cf10 : $d0, $1b

    lda wJoy1Low.w                               ; $cf12 : $ad, $11, $0f
    and #$f0                                     ; $cf15 : $29, $f0
    cmp #JOYF_L|JOYF_R                           ; $cf17 : $c9, $30
    bne @checkP2                                 ; $cf19 : $d0, $12

; Handle SGB menu
    stz wSGBMenuCursorController.w               ; $cf1b : $9c, $1f, $0c
    lda #$01                                     ; $cf1e : $a9, $01
    sta wInSGBMainMenuWithMainGamepad.w          ; $cf20 : $8d, $01, $0f
    jsr handleSGBMainMenu                        ; $cf23 : $20, $ee, $d0
...
@checkP2:

...

UpdateFramesHeldRL:
; If any of L and R are held, +1 to wFramesHeldP1JoyRL
; When both are released, clear it
    lda wJoy1Low.w                               ; $d9b8 : $ad, $11, $0f
    and #JOYF_L|JOYF_R                           ; $d9bb : $29, $30
    bne @incP1JoyheldFrames                      ; $d9bd : $d0, $05

    stz wFramesHeldP1JoyRL.w                     ; $d9bf : $9c, $43, $0c
    bra @afterP1Joy                              ; $d9c2 : $80, $0b

@incP1JoyheldFrames:
; wFramesHeldP1JoyRL maxes out at $28
    lda wFramesHeldP1JoyRL.w                     ; $d9c4 : $ad, $43, $0c
    ina                                          ; $d9c7 : $1a
    cmp #$29                                     ; $d9c8 : $c9, $29
    beq @afterP1Joy                              ; $d9ca : $f0, $03

    sta wFramesHeldP1JoyRL.w                     ; $d9cc : $8d, $43, $0c

@afterP1Joy:
```

What's happening here? `wFramesHeldP1JoyRL` will increment from $00 to $28 whenever either L or R is held. `CheckShouldOpenSGBMenu` will call `handleSGBMainMenu` (which handles the menu) when the counter hasn't yet reached $28, but both L and R is held.

What is the relevance of the counter? Well, to open the menu L and R must be held around the same time. In the case that someone holds L for a few seconds, then holds R, the counter will have already maxed out preventing opening the menu.

You might think the solution would be to just set the counter to $28 in `wMiscSGBEventsHook`, but if L and R are held on the same frame, `UpdateFramesHeldRL` would clear the counter, then in the next loop of the above code, `CheckShouldOpenSGBMenu` would see a counter of 0 with both buttons held, and open the menu.

Instead, we can both set the counter, and jump over `UpdateFramesHeldRL` as it is only used for the SGB menu, by `DATA_SND`ing the following:

```
.org $818

; A - misc event
.accu 8
.index 8
MiscSGBEventsHook:
    cmp #$03
    bne @done

    lda #$28
    sta wFramesHeldP1JoyRL.w
    pla
    pla
    jmp $cef6 ; address of the last `JmpDmaTransferNewGBScreenRows` in the loop code

@done:
    rts
```


## Patching OBJ_TRN

So now we have a borderless game, where the menu can't be opened to further screw things. We still can't use `OBJ_TRN` because it just runs `rts`:

```
; Byte  Content
; 0     Command*8+Length (fixed length=1)
; 1     Control Bits
;         Bit 0   - SNES OBJ Mode enable (0=Cancel, 1=Enable)
;         Bit 1   - Change OBJ Color     (0=No, 1=Use definitions below)
;         Bit 2-7 - Not used (zero)
; 2-3   System Color Palette Number for OBJ Palette 4 (0-511)
; 4-5   System Color Palette Number for OBJ Palette 5 (0-511)
; 6-7   System Color Palette Number for OBJ Palette 6 (0-511)
; 8-9   System Color Palette Number for OBJ Palette 7 (0-511)
;         These color entries are ignored if above Control Bit 1 is zero.
;         Because each OBJ palette consists of 16 colors, four system
;         palette entries (of 4 colors each) are transferred into each
;         OBJ palette. The system palette numbers are not required to be
;         aligned to a multiple of four, and will wrap to palette number
;         0 when exceeding 511. For example, a value of 511 would copy
;         system palettes 511, 0, 1, 2 to the SNES OBJ palette.
; A-F   Not used (zero)
CMD_OBJ_TRN:
    rts                                          ; $c927 : $60


; unused
_CMD_OBJ_TRN:
; If bit 0 clear, cancel OBJ mode, else enable it
    lda wSGBPacketsData.w+1                      ; $c928 : $ad, $01, $06
...
```

As you can see, there is actually code for this command 1 byte away. So the 1st `DATA_SND` patch we need to do is detect when `OBJ_TRN` is being sent, and jump to the correct handler. The addresses above are SGB BIOS version 0 addresses. The other versions use $c924/$c925.

The handler then sets a boolean flag to say it's in 'obj mode', changes BG3 to hide the last GB tilemap row, updates palettes as described in packet description, and some other minor flags to prevent corruption by attract mode/screen paint mode.

What's missing now is OBJ_TRN tile data. There is actually stubbed-out capability to send OBJ tile data near `CHR_TRN`:

```
.index 16
CopyGBscreenDataToObjTrnTileData:
@next8bytes:
; Copy 4 words over
; Bug: X is reset everytime, so only the 1st 8 bytes of OBJ tile data are ever set
    ldx #$0000                                   ; $c777 : $a2, $00, $00
    lda [wGBTileDataRamSrc], Y                   ; $c77a : $b7, $98
    sta wObjTrnOamTileData.l, X                  ; $c77c : $9f, $00, $b0, $7e
    iny                                          ; $c780 : $c8
    iny                                          ; $c781 : $c8
...
; Set that chr trn needs updating, as part of some heavy IRQ updates
.accu 8
.index 8
    sep #ACCU_8|IDX_8                            ; $c7a5 : $e2, $30
    lda #$01                                     ; $c7a7 : $a9, $01
    sta wPendingChrTrnTileDataUpdate.w           ; $c7a9 : $8d, $11, $02
    sta wHeavyIrqUpdatesPending.w                ; $c7ac : $8d, $17, $02
    rts                                          ; $c7af : $60

```

As you can see, it's unusable, but we know which ram buffer we need to populate, and some other flags we need to set:

* `wPendingChrTrnTileDataUpdate` ($0211) - a boolean flag, this must be set to 1, and before:
* `wHeavyIrqUpdatesPending` ($0217) - in the NMI vector code, this will update from either a number of large buffers, OR from `CHR_TRN` tile data

There is another flag we need to set that controls `CHR_TRN` update's source and dest:

* `wCurrChrTrnTransferDest` ($0212) - copied from `CHR_TRN`'s 'Tile Transfer Destination':

```
; 1     Tile Transfer Destination
;         Bit 0   - Tile Numbers   (0=Tiles 00h-7Fh, 1=Tiles 80h-FFh)
;         Bit 1   - Tile Type      (0=BG Tiles, 1=OBJ Tiles)
;         Bit 2-7 - Not used (zero)
```

To be specific, it pulls the source and destination like so:

```
ChrTrnWordIdxedVramDests:
    .dw $0000/2
    .dw $1000/2
    .dw $a000/2
    .dw $b000/2


ChrTrnBufferSrces:
    .table long, byte
    .row wSGBBorderTileData, $00 ; $7e8000
    .row wSGBBorderTileData+$1000, $00 ; $7e9000
    .row wObjTrnOamTileData, $00 ; $7eb000
    .row wObjTrnOamTileData, $00 ; $7eb000
```

Where vram dest $0000/$1000 is used for BG2 (the border), and $a000/$b000 is used for OAM2 (normally attract mode border objs).

The source is always $7eb000, so if we want $2000 bytes worth of tiles, that's what we need to fill.

So to recap, we need 1 patch, 1 `DATA_TRN` to send the tile data to $7eb000, and we need to set 3 flags.

The patch will look like:

```
.org $800

.accu 8
.index 8
PreExecPacketCmdHook:
    jmp _PreExecPacketCmdHook


.org $900

_PreExecPacketCmdHook:
    lda wCurrPacketCmd.w ; $02c2
    cmp #$18 ; OBJ_TRN's code
    bne @done

; No need for pulling the return address, we can execute the `rts` of the stubbed-out `OBJ_TRN`

    lda $ffdb.l ; cart version
    cmp #$00
    beq @ver0

    jmp $c925

@ver0:
    jmp $c928

@done:
    rts

```

After filling the GB tilemap with our OBJ tile data, we can then send:
```
    DATA_TRN|1, $00,$b0,$7e ; send to $7eb000 (OBJ tile data buffer)
; send 2 bytes to $0211, to update vram $a000-$afff (replace last byte with 3 to update vram $b000-$bfff)
    DATA_SND|1, $11,$02,$00, $02, $01,$02
    DATA_SND|1, $17,$02,$00, $01, $01
```

## OBJ_TRN with border

TODO:
