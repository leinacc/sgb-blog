# LLE Detection

Some quality GB emulators implement SGB HLE (High Level Emulation), mostly for fancy borders. In the event you want to have SGB-specific capability (for example, `OBJ_TRN`), you may want a fallback for emulators that do SGB HLE that won't be able to run custom SNES code.

The packets we can rely on for LLE detection include `DATA_SND`, `DATA_TRN` and `JUMP`. The GB can only receive data from the SNES via `rP1`, and even `MLT_REQ` can be HLE'd, so we'll send custom SNES code over and potentially jump to it.

## Sending custom Player 2 inputs

1. Send a `MLT_REQ` packet for 2 players
2. Send the following patch:

```
.org $808

.accu 8
.index 8

PreGBMainLoopHook:
    lda #$12
    sta $006005.l
    rts
```

As a `DATA_SND` packet:

```
    db ($0f<<3)|1, $08,$08,$00, $07, $a9,$12,$8f,$05,$60,$00,$60
```

3. A typical `PollInput` routine will `cpl` and `swap` the value to be $de. Or if you don't want it manipulated, don't `cpl` Player 2's input, put the dpad in the 'buttons held' low nybble and face buttons in the high nybble
