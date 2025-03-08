import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_musical_tone_generator(dut):
    """Test Musical Tone Generator functionality"""
    
    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz for faster simulation
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
        
        # Check outputs
        dut._log.info(f"Audio output: {dut.uo_out.value.integer & 0x01}")
        dut._log.info(f"LED pattern: 0b{(dut.uo_out.value.integer >> 1) & 0x7F:07b}")
        
        # Wait for a few more cycles
        await ClockCycles(dut.clk, 100)
    
    # Disable output
    dut.ui_in.value = 0x00
    await ClockCycles(dut.clk, 10)
    
    # Verify output is disabled
    assert (dut.uo_out.value.integer & 0x01) == 0, "Audio should be silent when disabled"
    dut._log.info("Audio output is silent as expected")
    
    dut._log.info("Basic tests completed successfully!")

@cocotb.test()
async def test_all_notes(dut):
    """Test all 16 notes with basic enable"""
    
    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
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
        await ClockCycles(dut.clk, 20)
        
        # Log results
        dut._log.info(f"Note {note}: LED pattern = 0b{(dut.uo_out.value.integer >> 1) & 0x7F:07b}")
        
        # Record some output samples for waveform analysis
        samples = []
        for _ in range(100):
            samples.append(dut.uo_out.value.integer & 0x1)
            await ClockCycles(dut.clk, 10)
        
        # Check that the output is toggling (simple activity check)
        assert min(samples) != max(samples), f"Note {note} should produce toggling output"

@cocotb.test()
async def test_octave_scaling(dut):
    """Test that octaves properly scale the frequency"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    note = 0  # Test with C note
    periods = []
    
    # Test all octaves with the same note
    for octave in range(4):
        # Set note, octave, and enable
        dut.ui_in.value = (1 << 6) | (octave << 4) | note
        
        # Wait to stabilize
        await ClockCycles(dut.clk, 50)
        
        # Measure the period by counting clocks between transitions
        last_value = dut.uo_out.value.integer & 0x1
        transition_count = 0
        clock_count = 0
        max_count = 100000  # Safety limit
        
        while transition_count < 2 and clock_count < max_count:
            await ClockCycles(dut.clk, 1)
            clock_count += 1
            current_value = dut.uo_out.value.integer & 0x1
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
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Enable note C with tremolo
    dut.ui_in.value = 0xC0  # Enable + tremolo + note C
    
    # Sample output over time to observe tremolo effect
    samples = []
    for _ in range(1000):
        samples.append(dut.uo_out.value.integer & 0x1)
        await ClockCycles(dut.clk, 10)
    
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
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Start with design enabled and playing a note
    dut.rst_n.value = 1
    dut.ena.value = 1
    dut.ui_in.value = 0x40  # Enable + note C
    
    # Let it run for a while
    await ClockCycles(dut.clk, 100)
    
    # Assert reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    
    # Check outputs are properly reset
    assert (dut.uo_out.value.integer & 0x1) == 0, "Audio output should be 0 after reset"
    
    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Check that module recovers and starts generating tone
    samples = []
    for _ in range(200):
        samples.append(dut.uo_out.value.integer & 0x1)
        await ClockCycles(dut.clk, 10)
    
    has_transition = False
    for i in range(1, len(samples)):
        if samples[i] != samples[i-1]:
            has_transition = True
            break
    
    assert has_transition, "Module should resume tone generation after reset is released"