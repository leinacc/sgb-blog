# SNES<->GB comms and hooks

## SGB to GB comms

* The SNES can only communicate to the GB by sending a byte to the `ICD2P_REGS` ($006004-$006007 for players 1-4)
* The GB will receive the data's high nybble when getting the face buttons (A/B/Start/Select), and the low nybble when getting the direction buttons.

Note that the common method of polling input will `cpl` these nybbles and reverse the nybbles they arrived in, ie the face buttons are saved in a ram var's low nybble.

## GB to SGB comms

* The main method is through SGB commands like `DATA_SND` and `JUMP`
* The other method is that GB's screen is read and displayed every frame by the SGB, by being copied through some ram buffers. You can put important info there if you have custom SNES code that can read what's in those buffers.

Note that you will need to send an appropriate `MASK_EN` SGB command if you don't want players to see your corrupted screen data, or if your custom data is to be read while the game is being displayed, you will need to run custom SNES code to alter SNES' BG3 tilemap to hide it.

## Hooks

Using `DATA_SND`, you can configure the following hooks

* `$000800` - This is run just before processing the bytes received for a 1+ packet command. The ram var $0002c2 contains the command ID. For example, $18 for `OBJ_TRN`
* `$000808` - This is run at the start of the SNES' inner GB main loop
* `$000810` - This is run at the end of the SNES' inner GB main loop
* `$000818` - This is run in misc scenarios, where `A` identifies the specific scenario
  * `A==0` - runs soon after BIOS starts. Potentially unusable as a hook?
  * `A==1` - runs when opening the controls submenu
  * `A==2` - runs when opening the SGB menu
  * `A==3` - runs sometime after the main GB loop. Might be skipped if keys were held, and it wasn't a button combo?
  * `A==4` - runs sometime before the main GB loop

Here is the GB main loop for reference. The addresses are for version 0 of the BIOS. For other versions, subtract 3 from the addresses.

```
DoMainGBLoop:
    jsr wPreGBMainLoopHook                       ; $baa7 : $20, $08, $08
    jsr SendInputsToGB                           ; $baaa : $20, $7f, $bc
    jsr UpdateAttractMode                        ; $baad : $20, $2c, $bd
    jsr WriteToSPCs4ports                        ; $bab0 : $20, $ba, $ba
    jsr TryHandlingAnSGBPacket                   ; $bab3 : $20, $d9, $bb
    jsr TryHandlingAnSGBPacket                   ; $bab6 : $20, $d9, $bb
    jsr wPostGBMainLoopHook                      ; $bab9 : $20, $10, $08
    rts                                          ; $babc : $60
```