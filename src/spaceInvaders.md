# Space Invaders

What people usually understand about how Space Invaders works is that a ton of data is sent to SNES RAM via `DATA_TRN`, then a `JUMP` command is issued to that area so that, essentially, you are playing a SNES game.

There are a couple other interesting details:

## DATA_TRN patch

`DATA_SND` packets are used to setup a hook that runs before SGB packets are handled, and that hook completely replaces `DATA_TRN` so that it can be faster.

```
.org $a00

_PreExecPacketCmdHook:
; Only override DATA_TRN
	lda wCurrPacketCmd                           ; $0a00 : $ad, $c2, $02
	cmp #CMD_DATA_TRN                            ; $0a03 : $c9, $10
	bne @done                                    ; $0a05 : $d0, $4c

; Signal to GB that DATA_TRN is starting
	lda #$01                                     ; $0a07 : $a9, $01
	sta ICD2P_REGS.l                             ; $0a09 : $8f, $04, $60, $00

; Do normal DATA_TRN, starting with setting the dest addr of the vram data
	lda wSGBPacketsData+1                        ; $0a0d : $ad, $01, $06
	sta wDataSendDestAddr.b                      ; $0a10 : $85, $b0
	lda wSGBPacketsData+2                        ; $0a12 : $ad, $02, $06
	sta wDataSendDestAddr.b+1                    ; $0a15 : $85, $b1
	lda wSGBPacketsData+3                        ; $0a17 : $ad, $03, $06
	sta wDataSendDestAddr.b+2                    ; $0a1a : $85, $b2

; Replicate DMA transferring the GB screen, catering to SGB BIOS versions
	lda CART_VERSION.l                           ; $0a1c : $af, $db, $ff, $00
	beq @ver0                                    ; $0a20 : $f0, $05

	jsr DmaTransferAGBScreen_nonVer0             ; $0a22 : $20, $8d, $c5
	bra +                                        ; $0a25 : $80, $03

@ver0:
	jsr DmaTransferAGBScreen_ver0                ; $0a27 : $20, $90, $c5

; Signal to GB that we've loaded the screen, so it can load new data, while
; we're doing the mem copy below
+	lda #$00                                     ; $0a2a : $a9, $00
	sta ICD2P_REGS.l                             ; $0a2c : $8f, $04, $60, $00

; Set the GB screen's ram buffer as the src pointer
	lda wCurrPtrGBTileDataBuffer                 ; $0a30 : $ad, $84, $02
	sta wGBTileDataRamSrc.b                      ; $0a33 : $85, $98
	lda wCurrPtrGBTileDataBuffer+1               ; $0a35 : $ad, $85, $02
	sta wGBTileDataRamSrc.b+1                    ; $0a38 : $85, $99
	lda #:wGBTileData0.b                         ; $0a3a : $a9, $7e
	sta wGBTileDataRamSrc.b+2                    ; $0a3c : $85, $9a

; Copy over the $1000 screen bytes
	setaxy16                                     ; $0a3e : $c2, $30
	ldx #$0800                                   ; $0a40 : $a2, $00, $08
	ldy #$0000                                   ; $0a43 : $a0, $00, $00

@nextWord:
	lda [wGBTileDataRamSrc], Y                   ; $0a46 : $b7, $98
	sta [wDataSendDestAddr], Y                   ; $0a48 : $97, $b0
	iny                                          ; $0a4a : $c8
	iny                                          ; $0a4b : $c8
	dex                                          ; $0a4c : $ca
	bne @nextWord                                ; $0a4d : $d0, $f7

; Skip doing the original DATA_TRN
	setaxy8                                      ; $0a4f : $e2, $30
	pla                                          ; $0a51 : $68
	pla                                          ; $0a52 : $68

@done:
	rts                                          ; $0a53 : $60
```

In short:
* In the replacement `DATA_TRN`, $01 is sent to GB's player 1 input
* The GB screen's data is copied to a generic ram buffer, due to using the generic routine `DmaTransferAGBScreen`
* After the GB's screen data is loaded in, $00 is sent to GB's player 1 input, which will signal it to do whatever it wants, for example, load a new screen for the next `DATA_TRN`
* While GB is loading a new screen, SNES is memcopying from the generic screen data buffer to the actual desired `DATA_TRN` destination

From the GB side, those values go through a `PollInput` routine, whose normal function `cpl` and `swap` the values to be $ef and $ff respectively:

```
DataTrn1000hBankBytes:

...

; The DATA_TRN patch will send 1 when DATA_TRN will load the VRAM tile data...
:   call PollInput                               ; $32f4 : $cd, $6c, $10
    ld a, [wBtnsHeld]                            ; $32f7 : $fa, $51, $d7
    cp $ef                                       ; $32fa : $fe, $ef
    jr nz, :-                                    ; $32fc : $20, $f6

; Then 0 once that vram tile data has all been read
:   call PollInput                               ; $32fe : $cd, $6c, $10
    ld a, [wBtnsHeld]                            ; $3301 : $fa, $51, $d7
    cp $ff                                       ; $3304 : $fe, $ff
    jr nz, :-                                    ; $3306 : $20, $f6
```

## GB is still active

The GB is still running even after a `JUMP` packet is issued. The data needed for the SNES game to fully function is larger than the free ram areas of bank $7e and $7f. The new sound engine, for example, and all of its data, take up around $cb00 bytes in total. So the GB will `DATA_TRN` in the background as needed by the SNES game, dependent on special values that are sent to player 1's input.

```
HandleArcadeMode:

...

.mainLoop:
; Get buttons sent by SNES
    call PollInput                               ; $320c : $cd, $6c, $10
    ld a, [wLastSnesBtnsHeld]                    ; $320f : $fa, $67, $d7
    ld b, a                                      ; $3212 : $47
    ld a, [wBtnsHeld]                            ; $3213 : $fa, $51, $d7

; Wait until a new code has been sent
    cp b                                         ; $3216 : $b8
    jr z, .mainLoop                              ; $3217 : $28, $f3

; Check if SNES sends $3f
    cp $0c                                       ; $3219 : $fe, $0c
    jr z, .code3Fh                               ; $321b : $28, $1c

; Check if SNES sends $2f
    ld hl, DataTrnBanks_3                        ; $321d : $21, $4e, $33
    cp $0d                                       ; $3220 : $fe, $0d
    jr z, .code1FhOr2Fh                          ; $3222 : $28, $07

; Check if SNES sends $1f
    ld hl, DataTrnBanks_2                        ; $3224 : $21, $4a, $33
    cp $0e                                       ; $3227 : $fe, $0e
    jr nz, .mainLoop                             ; $3229 : $20, $e1

.code1FhOr2Fh:
    ld [wLastSnesBtnsHeld], a                    ; $322b : $ea, $67, $d7

; DATA_TRN banks in HL, based on if $1f or $2f sent
    call DataTrnSomeBanks                        ; $322e : $cd, $4a, $32

; 7f:2006 jumps to the main handler for the SNES game, past some init code
    ld hl, Packet_JUMP_7f2006h                   ; $3231 : $21, $c0, $41
    call SendSGBPacketBank3                      ; $3234 : $cd, $a8, $0e
    jr .mainLoop                                 ; $3237 : $18, $d3

.code3Fh:
    ld [wLastSnesBtnsHeld], a                    ; $3239 : $ea, $67, $d7

; DATA_TRN banks in DataTrnBanks_1
    ld hl, DataTrnBanks_1                        ; $323c : $21, $43, $33
    call DataTrnSomeBanks                        ; $323f : $cd, $4a, $32

; 7f:2000 jumps to the main handler for the SNES game
    ld hl, Packet_JUMP_7f2000h                   ; $3242 : $21, $b0, $41
    call SendSGBPacketBank3                      ; $3245 : $cd, $a8, $0e
    jr .mainLoop                                 ; $3248 : $18, $c2
```

There is a DataTrnBanks_0 sent before this main loop. This loads in Space Invaders' sound engine and data, then sends the code $3f so that DataTrnBanks_1 can be loaded in.
