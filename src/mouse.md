# Using the SNES mouse

Note: this needs work. The cursor tile data and palettes need loading, if this is to load immediately, but there should also be some kind of "mouse is connected" flag for the GB.

1. Send a `MLT_REQ` for 4 players.

2. Send the following DATA_SND packets:

```
	db ($0f<<3)|1, $00,$09,$00, $0b, $4b,$f4,$0a,$09,$f4,$f3,$d7,$5c,$fb,$d7,$01
	db ($0f<<3)|1, $0b,$09,$00, $0b, $20,$b0,$d1,$20,$d5,$cf,$ad,$21,$0c,$8f,$05
	db ($0f<<3)|1, $16,$09,$00, $0b, $60,$00,$ad,$22,$0c,$8f,$06,$60,$00,$ad,$3b
	db ($0f<<3)|1, $21,$09,$00, $0b, $0f,$8f,$07,$60,$00,$a2,$00,$af,$db,$ff,$00
	db ($0f<<3)|1, $2c,$09,$00, $0b, $f0,$08,$20,$a0,$bc,$68,$68,$4c,$aa,$ba,$20
	db ($0f<<3)|1, $37,$09,$00, $07, $a3,$bc,$68,$68,$4c,$ad,$ba, $00,$00,$00,$00
    db ($0f<<3)|1, $08,$08,$00, $03, $4c,$00,$09
```

3. If using a typical GB `PollInput` routine, `cpl` and `swap` P2 to P4's result
4. P2 will have the mouse X in the SNES screen, P3 will have the mouse Y, and P4 will have bit 0 = left button clicked, bit 1 = right button clicked
5. For GB screen offsets, subtract $30 from mouse X, and $28 from mouse Y
