# Space Invaders

What people usually understand about how Space Invaders works is that a ton of data is sent to SNES RAM via `DATA_TRN`, then a `JUMP` command is issued to that area so that, essentially, you are playing a SNES game.

There are a couple other interesting details:

## DATA_TRN patch

`DATA_SND` packets are used to setup a hook that runs before SGB packets are handled, and that hook completely replaces `DATA_TRN` so that it can be faster.

* In the replacement `DATA_TRN`, $01 is sent to GB's player 1 input
* For the subroutine that loads in all of the GB screen data to a common `TRN` buffer, there is a small branch to call its correct address depending on if the SGB BIOS is version 0 or not
* After the GB's screen data is loaded in, $00 is sent to GB's player 1 input, which will signal it to load a new screen
* While GB is loading a new screen, SNES is memcopying from the `TRN` buffer to the actual desired `DATA_TRN` destination

From the GB side, those values go through a `PollInput` routine, whose normal function `cpl` and `swap` the values to be $ef and $ff respectively.

## GB is still active

The GB is still running even after a `JUMP` packet is issued. The data needed for the SNES game to fully function is larger than the free ram areas of bank $7e and $7f. The new sound engine, for example, and all of its data, take up around $cb00 bytes in total. So the GB will `DATA_TRN` in the background as needed by the SNES game, dependent on special values that are sent to player 1's input.
