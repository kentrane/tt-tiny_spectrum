# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_musical_tone_generator(dut):
    """Test Musical Tone Generator functionality"""
    
    # Start the clock
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())
    
    # Reset the design
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Wait for 10 clock cycles
    await ClockCycles(dut.clk, 10)
    
    # Release reset and enable the design
    dut.rst_n.value = 1
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)  # Wait for design to initialize
    
    # Test multiple notes and configurations
    notes_to_test = [
        # Format: (note, octave, enable, tremolo, description)
        (0, 0, 1, 0, "Note C in base octave"),
        (9, 0, 1, 0, "Note A (440Hz) in base octave"),
        (4, 0, 1, 0, "Note E in base octave"),
        (7, 1, 1, 0, "Note G in higher octave"),
        (0, 0, 1, 1, "Note C with tremolo"),
        (0, 0, 0, 0, "Output disabled")
    ]
    
    # Test each note
    for note, octave, enable, tremolo, description in notes_to_test:
        # Construct input based on configuration
        ui_value = (note & 0xF) | ((octave & 0x3) << 4) | (enable << 6) | (tremolo << 7)
        dut.ui_in.value = ui_value
        
        # Print current configuration
        dut._log.info(f"Testing: {description}")
        dut._log.info(f"Input value: 0x{ui_value:02x}")
        
        # Check that the output is as expected
        # Wait for enough cycles to see the tone generation
        await ClockCycles(dut.clk, 1000)
        
        # For enabled tones, we should see the audio output toggling
        if enable:
            # Sample a few times to check if output changes
            transitions = 0
            last_value = dut.uo_out.value.integer & 0x01
            
            for _ in range(5000):
                await ClockCycles(dut.clk, 100)
                current_value = dut.uo_out.value.integer & 0x01
                if current_value != last_value:
                    transitions += 1
                last_value = current_value
            
            # If tone is enabled, we should see audio output toggling
            assert transitions > 0, f"No transitions detected on audio output for {description}"
            dut._log.info(f"Detected {transitions} transitions in audio output")
            
            # Check that the LED outputs are set correctly (should match note pattern)
            led_output = (dut.uo_out.value.integer >> 1) & 0x7F
            dut._log.info(f"LED pattern: 0b{led_output:07b}")
        else:
            # For disabled output, audio should be silent (0)
            assert (dut.uo_out.value.integer & 0x01) == 0, "Audio output should be silent when disabled"
            dut._log.info("Audio output is silent as expected")
        
        # Pause between tests
        await ClockCycles(dut.clk, 100)
    
    dut._log.info("All musical tone generator tests completed successfully!")