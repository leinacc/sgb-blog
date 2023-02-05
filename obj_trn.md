# OBJ_TRN

`OBJ_TRN` is one of the documented packet commands that can be sent to the SGB, that was never used in commercial games.

It allowed you to display custom SNES-quality 4bpp sprites without writing SNES code. You would just write SNES OAM data to Gameboy VRAM (Nintendo describes writing it to the last tilemap row), and the SGB BIOS would pick it up and transform it into SNES sprites.

In order to not show artifacts due to non-graphical data appearing on the screen, OBJ_TRN would specifically hide the last tilemap row.

It had conflicts with some other SGB capability:

* Generic palette fading - usually when fading happens (borders/certain sub-menus/etc), all palettes are faded. `OBJ_TRN` lets you set OBJ palettes that were sent via PAL_TRN, but these are quickly overridden when a generic SGB fade in happens.

* OAM update code - when the SGB needs to display sprites (menu cursor/attract mode/etc), the SGB BIOS will run its update code in place of `OBJ_TRN`'s specific update code. These scenarios also override OAM tile data.

## Preventing conflicts

The above could be prevented by disallowing use of the SGB menu, and making sure not to send a border, though there was no official way to do this. The following relevant code, run in a loop, in the BIOS might shine a light on how we could do this:

```
    jsr CheckShouldOpenSGBMenu                                ; $cee0 : $20, $06, $cf
    jsr JmpDmaTransferNewGBScreenRows                         ; $cee3 : $20, $90, $ff
    jsr TryCheckingUnlocksBtnsState.l                         ; $cee6 : $22, $7d, $dd, $01
    lda #$03                                                  ; $ceea : $a9, $03
    jsr wMiscSGBEventsHook                                    ; $ceec : $20, $18, $08
    jsr JmpDmaTransferNewGBScreenRows                         ; $ceef : $20, $90, $ff
    jsr UpdateFramesHeldRL.l                                  ; $cef2 : $22, $b8, $d9, $01
    jsr JmpDmaTransferNewGBScreenRows                         ; $cef6 : $20, $90, $ff

...

CheckShouldOpenSGBMenu:
; Jump away if we've held L and/or R too long
    lda wFramesHeldP1JoyRL.w                                  ; $cf06 : $ad, $43, $0c
    cmp #$28                                                  ; $cf09 : $c9, $28
    beq @checkP2                                              ; $cf0b : $f0, $20

; Jump away if a non-LR button is also held
    lda wJoy1High.w                                           ; $cf0d : $ad, $12, $0f
    bne @checkP2                                              ; $cf10 : $d0, $1b

    lda wJoy1Low.w                                            ; $cf12 : $ad, $11, $0f
    and #$f0                                                  ; $cf15 : $29, $f0
    cmp #JOYF_L|JOYF_R                                        ; $cf17 : $c9, $30
    bne @checkP2                                              ; $cf19 : $d0, $12

; Handle SGB menu
    stz wSGBMenuCursorController.w                            ; $cf1b : $9c, $1f, $0c
    lda #$01                                                  ; $cf1e : $a9, $01
    sta wInSGBMainMenuWithMainGamepad.w                       ; $cf20 : $8d, $01, $0f
    jsr handleSGBMainMenu                                     ; $cf23 : $20, $ee, $d0
...
@checkP2:

...

UpdateFramesHeldRL:
; If any of L and R are held, +1 to wFramesHeldP1JoyRL
; When both are released, clear it
    lda wJoy1Low.w                                            ; $d9b8 : $ad, $11, $0f
    and #JOYF_L|JOYF_R                                        ; $d9bb : $29, $30
    bne @incP1JoyheldFrames                                   ; $d9bd : $d0, $05

    stz wFramesHeldP1JoyRL.w                                  ; $d9bf : $9c, $43, $0c
    bra @afterP1Joy                                           ; $d9c2 : $80, $0b

@incP1JoyheldFrames:
; wFramesHeldP1JoyRL maxes out at $28
    lda wFramesHeldP1JoyRL.w                                  ; $d9c4 : $ad, $43, $0c
    ina                                                       ; $d9c7 : $1a
    cmp #$29                                                  ; $d9c8 : $c9, $29
    beq @afterP1Joy                                           ; $d9ca : $f0, $03

    sta wFramesHeldP1JoyRL.w                                  ; $d9cc : $8d, $43, $0c

@afterP1Joy:
```

What's happening here? `wFramesHeldP1JoyRL` will increment from $00 to $28 whenever either L or R is held. `CheckShouldOpenSGBMenu` will call `handleSGBMainMenu` (which handles the menu) when the counter hasn't yet reached $28, but both L and R is held.

What is the relevance of the counter? Well, to open the menu L and R must be held around the same time. In the case that someone holds L for a few seconds, then holds R, the counter will have already maxed out preventing opening the menu.

You might think the solution would be to set the counter to $28 in `wMiscSGBEventsHook`, but if L and R are held on the same frame, `UpdateFramesHeldRL` would clear the counter, then in the next loop of the above code, `CheckShouldOpenSGBMenu` would see a counter of 0 with both buttons held, and open the menu.

Instead, we can jump over `UpdateFramesHeldRL` as it is only used for the SGB menu, but `DATA_SND`ing the following:

```
.org $818

; A - misc event
.accu 8
.index 8
MiscSGBEventsHook:
    cmp #$03
    bne @done

    pla
    pla
    jmp $cef6 ; address of the last `JmpDmaTransferNewGBScreenRows` in the loop code

@done:
    rts
```


## Patching OBJ_TRN

TODO:

## OBJ_TRN with border

TODO:
