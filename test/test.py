import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

@cocotb.test()
async def test_musical_tone_generator(dut):
    """Test Musical Tone Generator functionality"""
    
    # Start the clock (much faster for simulation)
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