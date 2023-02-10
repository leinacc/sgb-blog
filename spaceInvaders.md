# Space Invaders

What people usually understand about how Space Invaders works is that a ton of data is sent to SNES RAM via `DATA_TRN`, then a `JUMP` command is issued to that area so that, essentially, you are playing a SNES game.

There are a couple other interesting details:

## DATA_TRN patch

`DATA_SND` packets are used to setup a hook that runs before SGB packets are handled, and that hook completely replaces `DATA_TRN` so that it can be faster.

* In the replacement `DATA_TRN`, $01 is sent to GB's player 1 input
* For the subroutine that loads in all of the GB screen data to a common `TRN` buffer, there is a small branch to call its correct address depending on if the SGB BIOS is version 0 or not
* After the GB's screen data is loaded in, $00 is sent to GB's player 1 input, which will signal it to load a new screen
* While GB is loading a new screen, SNES is memcopying from the `TRN` buffer to the actual desired `DATA_TRN` destination

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
