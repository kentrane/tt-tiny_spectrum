<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
This project implements a digital musical tone generator using frequency division techniques common in FPGA/ASIC design. The implementation:

- Utilizes a 20-bit counter-based frequency divider to generate precise musical frequencies
- Supports 16 predefined musical notes via 4-bit selection input
- Provides 4 octave ranges controlled by a 2-bit selector
- Implements basic amplitude modulation (tremolo effect)
- Includes visual feedback via 7 LED outputs showing current note selection

The core functionality is implemented as a synchronous state machine that toggles the output when a frequency-specific counter reaches its terminal count value.

## How to test
1. **Note selection**: Configure ui_in[3:0] to select from 16 predefined notes (0=C, 9=A/440Hz, etc.)

2. **Octave selection**: Set ui_in[5:4] to select the octave range:
   - 00: Base frequencies
   - 01: One octave higher (2x frequency)
   - 10: Two octaves higher (4x frequency) 
   - 11: One octave lower (0.5x frequency)

3. **Enable control**: Set ui_in[6] to 1 to enable tone generation

4. **Modulation control**: Set ui_in[7] to 1 to enable tremolo effect

The primary output appears on uo_out[0] as a square wave at the selected frequency, while uo_out[7:1] provides visual indication of the current note.

## External hardware

- RC low-pass filter (1kΩ resistor + 0.1µF capacitor) for audio to not be square
- DC blocking capacitor for speaker protection
- Speaker/headphones
- Speaker or headphone driver circuit if you want
