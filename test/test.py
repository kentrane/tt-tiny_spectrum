import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_musical_tone_generator(dut):
    """Test Musical Tone Generator very basic functionality"""
    
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
    
    # Use simplified test to avoid timeouts
    # Just test a few basic configurations
    test_configs = [
        # (ui_in_value, description)
        (0x40, "Note C with enable"),
        (0x49, "Note A with enable"),
        (0xC0, "Note C with tremolo")
    ]
    
    # Test each configuration
    for ui_value, description in test_configs:
        dut._log.info(f"Testing: {description}")
        dut.ui_in.value = ui_value
        
        # Wait a few cycles for changes to take effect
        await ClockCycles(dut.clk, 20)
        
        # Check outputs - Audio output is on bit 7, not bit 0
        dut._log.info(f"Audio output: {(dut.uo_out.value.integer >> 7) & 0x01}")
        dut._log.info(f"LED pattern: 0b{dut.uo_out.value.integer & 0x7F:07b}")
        
        # Wait for a few more cycles
        await ClockCycles(dut.clk, 100)
    
    # Disable output
    dut.ui_in.value = 0x00
    await ClockCycles(dut.clk, 10)
    
    # Verify output is disabled - Audio output is on bit 7
    assert ((dut.uo_out.value.integer >> 7) & 0x01) == 0, "Audio should be silent when disabled"
    dut._log.info("Audio output is silent as expected")
    
    dut._log.info("Basic tests completed successfully!")

@cocotb.test()
async def test_all_notes(dut):
    """Test all 16 notes with basic enable"""
    
    # Start the clock
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())
    
    # Reset and initialize
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Test all notes
    for note in range(16):
        # Set note with enable bit
        dut.ui_in.value = (1 << 6) | note
        
        # Wait for a consistent state
        await ClockCycles(dut.clk, 1000)
        
        # Log results - LED pattern is in bits 6:0
        dut._log.info(f"Note {note}: LED pattern = 0b{dut.uo_out.value.integer & 0x7F:07b}")
        
        # For lower notes (0-7), sample for longer periods
        sample_interval = 500 if note < 8 else 100
        # Record some output samples for waveform analysis - Audio on bit 7
        samples = []
        for _ in range(200):
            samples.append((dut.uo_out.value.integer >> 7) & 0x1)
            await ClockCycles(dut.clk, sample_interval)
        
        # Check that the output is toggling (simple activity check)
        dut._log.info(f"Note {note}: Min={min(samples)}, Max={max(samples)}")
        assert min(samples) != max(samples), f"Note {note} should produce toggling output"

@cocotb.test()
async def test_octave_scaling(dut):
    """Test that octaves properly scale the frequency"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    
    note = 0  # Test with C note
    periods = []
    
    # Test all octaves with the same note
    for octave in range(4):
        # Set note, octave, and enable
        dut.ui_in.value = (1 << 6) | (octave << 4) | note
        
        # Wait to stabilize
        await ClockCycles(dut.clk, 500)
        
        # Measure the period by counting clocks between transitions - Audio on bit 7
        last_value = (dut.uo_out.value.integer >> 7) & 0x1
        transition_count = 0
        clock_count = 0
        max_count = 100000  # Safety limit
        
        while transition_count < 2 and clock_count < max_count:
            await ClockCycles(dut.clk, 1)
            clock_count += 1
            current_value = (dut.uo_out.value.integer >> 7) & 0x1
            if current_value != last_value:
                transition_count += 1
                if transition_count == 1:
                    # Start counting from first transition
                    period_start = clock_count
                elif transition_count == 2:
                    # Complete period at second transition
                    periods.append(clock_count - period_start)
            last_value = current_value
        
        dut._log.info(f"Octave {octave}: Period measured = {periods[-1]} clocks")
    
    # Check that each higher octave has approximately half the period
    # (allowing for small variations due to measurement technique)
    for i in range(1, len(periods)):
        ratio = periods[i-1] / periods[i] if periods[i] != 0 else float('inf')
        dut._log.info(f"Period ratio octave {i-1} to {i}: {ratio:.2f}")
        # Check ratio with some tolerance
        assert 1.8 < ratio < 2.2 or 0.45 < ratio < 0.55, f"Octave scaling incorrect: {ratio}"

@cocotb.test()
async def test_tremolo_effect(dut):
    """Test that tremolo effect modulates the output"""
    
    # Setup
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    
    # Enable note C with tremolo
    dut.ui_in.value = 0xC0  # Enable + tremolo + note C
    
    # Sample output over time to observe tremolo effect - Audio on bit 7
    samples = []
    for _ in range(1000):
        samples.append((dut.uo_out.value.integer >> 7) & 0x1)
        await ClockCycles(dut.clk, 100)
    
    # Check for periods of silence (tremolo causing output to go low)
    has_low = 0 in samples
    has_high = 1 in samples
    
    assert has_low and has_high, "Tremolo effect should modulate between high and low"
    
    # Calculate number of transitions as a basic check for modulation
    transitions = sum(1 for i in range(1, len(samples)) if samples[i] != samples[i-1])
    dut._log.info(f"Detected {transitions} transitions in tremolo output")
    
    assert transitions > 10, "Tremolo should cause multiple output transitions"

@cocotb.test()
async def test_reset_behavior(dut):
    """Test that reset properly initializes the module"""
    
    # Setup
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    
    # Start with design enabled and playing a note
    dut.rst_n.value = 1
    dut.ena.value = 1
    dut.ui_in.value = 0x40  # Enable + note C
    
    # Let it run for a while
    await ClockCycles(dut.clk, 1000)
    
    # Assert reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 50)
    
    # Check outputs are properly reset - Audio on bit 7
    assert ((dut.uo_out.value.integer >> 7) & 0x01) == 0, "Audio output should be 0 after reset"
    
    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 50)
    
    # Check that module recovers and starts generating tone - Audio on bit 7
    samples = []
    for _ in range(200):
        samples.append((dut.uo_out.value.integer >> 7) & 0x1)
        await ClockCycles(dut.clk, 100)
    
    has_transition = False
    for i in range(1, len(samples)):
        if samples[i] != samples[i-1]:
            has_transition = True
            break
    
    assert has_transition, "Module should resume tone generation after reset is released"
@cocotb.test()
async def test_note_frequency(dut):
    """Measure tone frequency for each note"""
    
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.ena.value = 1
    
    # Test a few notes
    for note in [0, 4, 9, 15]:  # C, E, A, D#5
        # Enable note
        dut.ui_in.value = (1 << 6) | note
        await ClockCycles(dut.clk, 1000)  # Let it stabilize
        
        # Measure pulse width - Audio on bit 7
        last_value = (dut.uo_out.value.integer >> 7) & 0x1
        transitions = 0
        cycles = 0
        period_cycles = 0
        
        # Run until we detect 4 transitions or timeout
        while transitions < 4 and cycles < 100000:
            await ClockCycles(dut.clk, 1)
            cycles += 1
            current_value = (dut.uo_out.value.integer >> 7) & 0x1
            
            if current_value != last_value:
                transitions += 1
                if transitions == 2:  # Start counting at second transition
                    period_cycles = 0
                if transitions == 4:  # End at fourth transition (full period)
                    break
            
            if transitions >= 2:  # Count cycles during one full period
                period_cycles += 1
                
            last_value = current_value
            
        freq_hz = 10000000 / period_cycles if period_cycles > 0 else 0
        dut._log.info(f"Note {note}: Period = {period_cycles} cycles, Freq ≈ {freq_hz:.2f} Hz")
@cocotb.test()
async def test_frequency_accuracy(dut):
    """Verify that measured frequencies match expected values"""
    
    # Setup
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    
    # Expected frequencies (Hz) based on base_dividers in project.v
    expected_freqs = {
        0: 261.63,  # C
        1: 277.18,  # C#
        2: 293.66,  # D
        3: 311.13,  # D#
        4: 329.63,  # E
        5: 349.23,  # F
        6: 369.99,  # F#
        7: 392.00,  # G
        8: 415.30,  # G#
        9: 440.00,  # A
        10: 466.16, # A#
        11: 493.88, # B
        12: 523.25, # C5
        13: 554.37, # C#5
        14: 587.33, # D5
        15: 622.25  # D#5
    }
    
    # Test all notes in the lowest octave
    for note in range(16):
        # Set note with enable bit
        dut.ui_in.value = (1 << 6) | note
        
        # Wait to stabilize
        await ClockCycles(dut.clk, 1000)
        
        # Measure frequency - Audio on bit 7
        last_value = (dut.uo_out.value.integer >> 7) & 0x1
        transitions = 0
        cycles = 0
        period_cycles = 0
        
        # Run until we detect 4 transitions or timeout
        while transitions < 4 and cycles < 100000:
            await ClockCycles(dut.clk, 1)
            cycles += 1
            current_value = (dut.uo_out.value.integer >> 7) & 0x1
            
            if current_value != last_value:
                transitions += 1
                if transitions == 2:  # Start counting at second transition
                    period_cycles = 0
                if transitions == 4:  # End at fourth transition (full period)
                    break
            
            if transitions >= 2:  # Count cycles during one full period
                period_cycles += 1
                
            last_value = current_value
            
        measured_freq_hz = 10000000 / period_cycles if period_cycles > 0 else 0
        expected_freq = expected_freqs[note]
        
        # Allow for 5% tolerance in frequency accuracy
        tolerance = 0.05
        dut._log.info(f"Note {note}: Expected {expected_freq:.2f} Hz, Measured {measured_freq_hz:.2f} Hz")
        
        # Calculate difference percentage
        diff_percent = abs(measured_freq_hz - expected_freq) / expected_freq * 100
        dut._log.info(f"Difference: {diff_percent:.2f}%")
        
        assert diff_percent < 5.0, f"Frequency for note {note} is off by {diff_percent:.2f}%, expected {expected_freq} Hz, measured {measured_freq_hz} Hz"

@cocotb.test()
async def test_comprehensive_octave_scaling(dut):
    """Test octave scaling across multiple notes"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    
    # Test notes from different parts of the scale
    test_notes = [0, 4, 9, 14]  # C, E, A, D5
    
    for note in test_notes:
        periods = []
        dut._log.info(f"Testing octave scaling for note {note}")
        
        # Test all octaves for this note
        for octave in range(4):
            # Set note, octave, and enable
            dut.ui_in.value = (1 << 6) | (octave << 4) | note
            
            # Wait to stabilize
            await ClockCycles(dut.clk, 1000)
            
            # Measure period - Audio on bit 7
            last_value = (dut.uo_out.value.integer >> 7) & 0x1
            transitions = 0
            cycles = 0
            period_cycles = 0
            
            # Run until we detect 4 transitions or timeout
            while transitions < 4 and cycles < 100000:
                await ClockCycles(dut.clk, 1)
                cycles += 1
                current_value = (dut.uo_out.value.integer >> 7) & 0x1
                
                if current_value != last_value:
                    transitions += 1
                    if transitions == 2:  # Start counting at second transition
                        period_cycles = 0
                    if transitions == 4:  # End at fourth transition (full period)
                        break
                
                if transitions >= 2:  # Count cycles during one full period
                    period_cycles += 1
                    
                last_value = current_value
                
            periods.append(period_cycles)
            
            freq_hz = 10000000 / period_cycles if period_cycles > 0 else 0
            dut._log.info(f"Note {note} Octave {octave}: Period = {period_cycles} cycles, Freq ≈ {freq_hz:.2f} Hz")
        
        # Check scaling between octaves
        for i in range(1, len(periods)):
            ratio = periods[i-1] / periods[i] if periods[i] != 0 else float('inf')
            dut._log.info(f"Note {note}: Period ratio octave {i-1} to {i}: {ratio:.2f}")
            assert 1.9 < ratio < 2.1, f"Octave scaling for note {note} incorrect: {ratio}"

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_visualize_segments(dut):
    """Visualize all 7-segment display patterns for each note"""
    
    # Start the clock
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())
    
    # Reset the design
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Wait for the reset to take effect
    await ClockCycles(dut.clk, 10)
    
    # Release reset
    dut.rst_n.value = 1
    
    # Wait for the design to initialize
    await ClockCycles(dut.clk, 10)
    
    # Dictionary to map note numbers to names
    note_names = {
        0: "C",  1: "C#", 2: "D",  3: "D#",
        4: "E",  5: "F",  6: "F#", 7: "G",
        8: "G#", 9: "A", 10: "A#", 11: "B",
        12: "C5", 13: "C#5", 14: "D5", 15: "D#5"
    }
    
    # ASCII art templates for 7-segment display visualization
    # Segments are arranged as:
    #    AAA
    #   F   B
    #   F   B
    #    GGG
    #   E   C
    #   E   C
    #    DDD
    
    segment_patterns = {
        # For each bit pattern, we show the corresponding segment layout
        # Format: [top, middle, bottom]
        0b0000001: [" ", " ", "."   ],  # Segment A
        0b0000010: [" |", " |", " "  ],  # Segment B
        0b0000100: [" ", " |", " |"  ],  # Segment C
        0b0001000: [" ", " ", "___" ],  # Segment D
        0b0010000: [" ", "|", "|"   ],  # Segment E
        0b0100000: ["|", "|", " "   ],  # Segment F
        0b1000000: [" ", "_", " "   ],  # Segment G
    }
    
    # Test all 16 notes
    dut._log.info("\n===== 7-SEGMENT DISPLAY VISUALIZATION =====")
    
    for note in range(16):
        # Set note with enable bit
        dut.ui_in.value = (1 << 6) | note
        
        # Wait for a consistent state
        await ClockCycles(dut.clk, 20)
        
        # Get the current 7-segment display pattern (bits 6:0)
        pattern = dut.uo_out.value.integer & 0x7F
        
        # Create a visual representation
        top_row = "  "
        mid_row = "  "
        bot_row = "  "
        
        # Check each segment bit and build the visual display
        if pattern & 0x01:  # Segment A (bit 0)
            top_row += "___"
        else:
            top_row += "   "
        
        if pattern & 0x20:  # Segment F (bit 5)
            mid_row = "|" + mid_row[1:]
        else:
            mid_row = " " + mid_row[1:]
            
        if pattern & 0x02:  # Segment B (bit 1)
            mid_row = mid_row[0:2] + "|"
        else:
            mid_row = mid_row[0:2] + " "
            
        if pattern & 0x40:  # Segment G (bit 6)
            mid_row = mid_row[0:1] + "_" + mid_row[2:]
        else:
            mid_row = mid_row[0:1] + " " + mid_row[2:]
            
        if pattern & 0x10:  # Segment E (bit 4)
            bot_row = "|" + bot_row[1:]
        else:
            bot_row = " " + bot_row[1:]
            
        if pattern & 0x04:  # Segment C (bit 2)
            bot_row = bot_row[0:2] + "|"
        else:
            bot_row = bot_row[0:2] + " "
            
        if pattern & 0x08:  # Segment D (bit 3)
            bot_row = bot_row[0:1] + "_" + bot_row[2:]
        else:
            bot_row = bot_row[0:1] + " " + bot_row[2:]
        
        # Display the pattern
        dut._log.info(f"\nNote {note} ({note_names[note]}) - Pattern: 0b{pattern:07b}")
        dut._log.info(f"{top_row}")
        dut._log.info(f"{mid_row}")
        dut._log.info(f"{bot_row}")
    
    dut._log.info("\n===== SEGMENT BIT MAPPING =====")
    dut._log.info("Bit 0 (0x01): Segment A (top horizontal)")
    dut._log.info("Bit 1 (0x02): Segment B (top right vertical)")
    dut._log.info("Bit 2 (0x04): Segment C (bottom right vertical)")
    dut._log.info("Bit 3 (0x08): Segment D (bottom horizontal)")
    dut._log.info("Bit 4 (0x10): Segment E (bottom left vertical)")
    dut._log.info("Bit 5 (0x20): Segment F (top left vertical)")
    dut._log.info("Bit 6 (0x40): Segment G (middle horizontal)")

@cocotb.test()
async def test_segment_patterns_for_notes(dut):
    """Test that each note produces the expected segment pattern"""
    
    # Start the clock and reset
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Expected patterns for each note (based on project.v definitions)
    expected_patterns = {
        0: 0b0111111,  # C - '0'
        1: 0b0000110,  # C# - '1'
        2: 0b1011011,  # D - '2'
        3: 0b1001111,  # D# - '3'
        4: 0b1100110,  # E - '4'
        5: 0b1101101,  # F - '5'
        6: 0b1111101,  # F# - '6'
        7: 0b0000111,  # G - '7'
        8: 0b1111111,  # G# - '8'
        9: 0b1101111,  # A - '9'
        10: 0b1110111,  # A# - 'A'
        11: 0b1111100,  # B - 'b'
        12: 0b0111001,  # C5 - 'C'
        13: 0b1011110,  # C#5 - 'd'
        14: 0b1111001,  # D5 - 'E'
        15: 0b1110001,  # D#5 - 'F'
    }
    
    dut._log.info("\n===== SEGMENT PATTERN VERIFICATION =====")
    
    # Test all 16 notes
    for note in range(16):
        # Set note with enable bit
        dut.ui_in.value = (1 << 6) | note
        
        # Wait for changes to take effect
        await ClockCycles(dut.clk, 20)
        
        # Get the current pattern
        actual_pattern = dut.uo_out.value.integer & 0x7F
        expected = expected_patterns[note]
        
        # Check pattern matches what we expect
        matches = actual_pattern == expected
        status = "it match bruh" if matches else "bit shit innit"
        
        dut._log.info(f"Note {note}: Expected 0b{expected:07b}, Got 0b{actual_pattern:07b} {status}")
        
        # Formal assertion
        assert matches, f"Pattern mismatch for note {note}"
    
    dut._log.info("All segment patterns verified successfully!")
