# Simple tests for an adder module
import os
import sys
import cocotb
import logging
from cocotb.result import TestFailure
from nysa.host.sim.sim_host import NysaSim
from cocotb.clock import Clock
import time
from array import array as Array
from dut_driver import DDR3Driver

from nysa.host.driver.dma import DMA
from nysa.host.driver.memory import Memory

import random


SIM_CONFIG = "sim_config.json"


CLK_PERIOD = 20
UI_CLK_PERIOD = 2

MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "rtl")
MODULE_PATH = os.path.abspath(MODULE_PATH)


def setup_dut(dut):
    cocotb.fork(Clock(dut.in_clk, CLK_PERIOD).start())
    cocotb.fork(Clock(dut.m1.ddr3_if.sim_ui_clk, UI_CLK_PERIOD).start())

@cocotb.test(skip = True)
def single_block_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 1

    Expected Results:
        Write to all registers
    """


    dut.test_id = 1
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    #driver = DDR3Driver(nysa, nysa.find_device(DDR3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 0x80
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % (len(write_data) / 4))
    #yield cocotb.external(driver.write)(0x00000000, write_data)
    yield cocotb.external(nysa.write_memory)(0x00000000, write_data)
    yield (nysa.wait_clocks(100))
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    #read_data = yield cocotb.external(driver.read)(0x00, DATA_DWORD_COUNT)
    read_data = yield cocotb.external(nysa.read_memory)(0x00000000, DATA_DWORD_COUNT)
    yield (nysa.wait_clocks(400))

    '''
    dut.log.info("Comparing Lengths of Transactions...")
    if len(write_data) != len(read_data):
        dut.log.error("Write Data Length [0x%08X] != Read Data Length [0x%08X]" % (len(write_data), len(read_data)))
    else:
        dut.log.info("Lengths match!")

    dut.log.info("Comparing All individual Values...")
    fail = False
    for i in range(len(write_data)):
        if (write_data[i] != read_data[i]):
            fail = True
            dut.log.error("Error at: 0x%04X: %08X != %08X" % (i, write_data[i], read_data[i]))

    if not fail:
        dut.log.info("All values are equal!")
    '''

@cocotb.test(skip = True)
def single_block_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 2

    Expected Results:
        Write to all registers
    """


    dut.test_id = 2
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    #driver = DDR3Driver(nysa, nysa.find_device(DDR3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 0x80
    #Write a longer packet
    dma_urn = nysa.find_device(DMA)[0]
    memory_urn = nysa.find_device(Memory)[0]
    dut.log.info("Instantiated a DMA Device: %s" % dma_urn)
    dma = yield cocotb.external(DMA)(nysa, dma_urn)
    yield cocotb.external(dma.setup)()

    ccount = dma.get_channel_count()
    scount = dma.get_sink_count()
    icount = dma.get_instruction_count()

    dut.log.debug("")
    dut.log.debug("DMA:")
    dut.log.debug("DMA Channel count:\t\t%d" % ccount)
    dut.log.debug("DMA Sink count:\t\t%d" % scount)
    dut.log.debug("DMA Instruction count:\t%d" % icount)


    INGRESS_SOURCE_PORT = 2
    #Where we will write the data to
    INGRESS_SINK_PORT = 1
    #The instruction address we will use to control the transfer
    INGRESS_INST_ADDR = 0
    #The srouce of address that the source port will read data from (used mostly for memory)
    #The destination address of the sink we will write data to
    INGRESS_SOURCE_ADDRESS = 0x00000000
    INGRESS_SINK_ADDRESS = 0x00000000

    INGRESS_DATA_COUNT = 0x100

    #Which source device we will read from (This is also the channel)
    EGRESS_SOURCE_PORT = 0
    #Where we will write the data to
    EGRESS_SINK_PORT = 2
    #The instruction address we will use to control the transfer
    EGRESS_INST_ADDR = 2
    #The srouce of address that the source port will read data from (used mostly for memory)
    EGRESS_SOURCE_ADDRESS = 0x00000000
    EGRESS_SINK_ADDRESS = INGRESS_SOURCE_ADDRESS + INGRESS_DATA_COUNT
    #The destination address of the sink we will write data to
    #The number of data words to transfer
    EGRESS_DATA_COUNT = 0x100

 
    ###########################################################################
    #DMA Core Configuration
    #SOURCE
    #associate source port to sink port
    yield cocotb.external(dma.set_channel_sink_addr)            (INGRESS_SOURCE_PORT,  INGRESS_SINK_PORT     )
    #associate source port with instruction address
    yield cocotb.external(dma.set_channel_instruction_pointer)  (INGRESS_SOURCE_PORT,  INGRESS_INST_ADDR     )
    #source will increment address
    yield cocotb.external(dma.enable_source_address_increment)  (INGRESS_SOURCE_PORT,  True          )

    #SINK
    #sink will increment address
    yield cocotb.external(dma.enable_dest_address_increment)    (INGRESS_SINK_PORT,    True          )
    #the sink port must sink in the exact amount of data specified , it cannot end a transaction early
    yield cocotb.external(dma.enable_dest_respect_quantum)      (INGRESS_SINK_PORT,    False         )

    #INSTRUCTION
    #When finished with the instruction the DMA can continue to the 'next' instruction
    yield cocotb.external(dma.enable_instruction_continue)      (INGRESS_INST_ADDR,    False          )
    #Set the source address
    yield cocotb.external(dma.set_instruction_source_address)   (INGRESS_INST_ADDR,    INGRESS_SOURCE_ADDRESS)
    #set the destination address
    yield cocotb.external(dma.set_instruction_dest_address)     (INGRESS_INST_ADDR,    INGRESS_SINK_ADDRESS  )
    #Set the number of words to transfer
    yield cocotb.external(dma.set_instruction_data_count)       (INGRESS_INST_ADDR,    INGRESS_DATA_COUNT    )
    #If continue is set go to where the 'next' instruction is pointing to
    yield cocotb.external(dma.set_instruction_next_instruction) (INGRESS_INST_ADDR,    INGRESS_INST_ADDR     )
    ###########################################################################

    ###########################################################################
    #Configure DMA to read data from core

    #DMA CONFIGURATION
    #SOURCE
    #associate source port to sink port
    yield cocotb.external(dma.set_channel_sink_addr)            (EGRESS_SOURCE_PORT,  EGRESS_SINK_PORT     )
    #associate source port with instruction address
    yield cocotb.external(dma.set_channel_instruction_pointer)  (EGRESS_SOURCE_PORT,  EGRESS_INST_ADDR     )
    #source will increment address
    yield cocotb.external(dma.enable_source_address_increment)  (EGRESS_SOURCE_PORT,  True          )

    #SINK
    #sink will increment address
    yield cocotb.external(dma.enable_dest_address_increment)    (EGRESS_SINK_PORT,    True          )
    #the sink port must sink in the exact amount of data specified , it cannot end a transaction early
    yield cocotb.external(dma.enable_dest_respect_quantum)      (EGRESS_SINK_PORT,    False         )

    #INSTRUCTION
    #When finished with the instruction the DMA can continue to the 'next' instruction
    yield cocotb.external(dma.enable_instruction_continue)      (EGRESS_INST_ADDR,    False          )
    #Set the source address
    yield cocotb.external(dma.set_instruction_source_address)   (EGRESS_INST_ADDR,    EGRESS_SOURCE_ADDRESS)
    #set the destination address
    yield cocotb.external(dma.set_instruction_dest_address)     (EGRESS_INST_ADDR,    EGRESS_SINK_ADDRESS  )
    #Set the number of words to transfer
    yield cocotb.external(dma.set_instruction_data_count)       (EGRESS_INST_ADDR,    EGRESS_DATA_COUNT    )

    #If continue is set go to where the 'next' instruction is pointing to
    yield cocotb.external(dma.set_instruction_next_instruction) (EGRESS_INST_ADDR,    EGRESS_INST_ADDR     )
    ###########################################################################

    ###########################################################################
    #Enable DMA Transfers
    #Start transfer
    yield cocotb.external(dma.set_channel_instruction_pointer)  (INGRESS_SOURCE_PORT,  INGRESS_INST_ADDR)
    yield cocotb.external(dma.set_channel_instruction_pointer)  (EGRESS_SOURCE_PORT,  EGRESS_INST_ADDR  )
    #Enable the channel to start transacting
    yield cocotb.external(dma.enable_channel)                   (INGRESS_SOURCE_PORT,  True             )
    yield cocotb.external(dma.enable_channel)                   (EGRESS_SOURCE_PORT,  True              )

    ###########################################################################



    DATA_DWORD_COUNT = 0x200
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % (len(write_data) / 4))
    #yield cocotb.external(driver.write)(0x00000000, write_data)
    yield cocotb.external(nysa.write_memory)(0x00000000, write_data)
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(nysa.read_memory)(0x00000000, DATA_DWORD_COUNT)



    yield (nysa.wait_clocks(10000))


    #Disable the channel
    yield cocotb.external(dma.enable_channel)                   (INGRESS_SOURCE_PORT,  False            )
    yield cocotb.external(dma.enable_channel)                   (EGRESS_SOURCE_PORT,  False             )
    #Disable the entire DMA
    yield cocotb.external(dma.enable_dma)(False)
    dut.log.info("Done")
 
@cocotb.test(skip = False)
def single_wbs_read_write_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 3

    Expected Results:
        Write to all registers
    """


    dut.test_id = 3
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    #driver = DDR3Driver(nysa, nysa.find_device(DDR3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 0x80
    #Write a longer packet
    dma_urn = nysa.find_device(DMA)[0]
    memory_urn = nysa.find_device(Memory)[0]
    dut.log.info("Instantiated a DMA Device: %s" % dma_urn)
    dma = yield cocotb.external(DMA)(nysa, dma_urn)
    yield cocotb.external(dma.setup)()

    '''
    ccount = dma.get_channel_count()
    scount = dma.get_sink_count()
    icount = dma.get_instruction_count()

    dut.log.debug("")
    dut.log.debug("DMA:")
    dut.log.debug("DMA Channel count:\t\t%d" % ccount)
    dut.log.debug("DMA Sink count:\t\t%d" % scount)
    dut.log.debug("DMA Instruction count:\t%d" % icount)


    INGRESS_SOURCE_PORT = 2
    #Where we will write the data to
    INGRESS_SINK_PORT = 1
    #The instruction address we will use to control the transfer
    INGRESS_INST_ADDR = 0
    #The srouce of address that the source port will read data from (used mostly for memory)
    #The destination address of the sink we will write data to
    INGRESS_SOURCE_ADDRESS = 0x00000000
    INGRESS_SINK_ADDRESS = 0x00000000

    INGRESS_DATA_COUNT = 0x100

    #Which source device we will read from (This is also the channel)
    EGRESS_SOURCE_PORT = 0
    #Where we will write the data to
    EGRESS_SINK_PORT = 2
    #The instruction address we will use to control the transfer
    EGRESS_INST_ADDR = 2
    #The srouce of address that the source port will read data from (used mostly for memory)
    EGRESS_SOURCE_ADDRESS = 0x00000000
    EGRESS_SINK_ADDRESS = INGRESS_SOURCE_ADDRESS + INGRESS_DATA_COUNT
    #The destination address of the sink we will write data to
    #The number of data words to transfer
    EGRESS_DATA_COUNT = 0x100

 
    ###########################################################################
    #DMA Core Configuration
    #SOURCE
    #associate source port to sink port
    yield cocotb.external(dma.set_channel_sink_addr)            (INGRESS_SOURCE_PORT,  INGRESS_SINK_PORT     )
    #associate source port with instruction address
    yield cocotb.external(dma.set_channel_instruction_pointer)  (INGRESS_SOURCE_PORT,  INGRESS_INST_ADDR     )
    #source will increment address
    yield cocotb.external(dma.enable_source_address_increment)  (INGRESS_SOURCE_PORT,  True          )

    #SINK
    #sink will increment address
    yield cocotb.external(dma.enable_dest_address_increment)    (INGRESS_SINK_PORT,    True          )
    #the sink port must sink in the exact amount of data specified , it cannot end a transaction early
    yield cocotb.external(dma.enable_dest_respect_quantum)      (INGRESS_SINK_PORT,    False         )

    #INSTRUCTION
    #When finished with the instruction the DMA can continue to the 'next' instruction
    yield cocotb.external(dma.enable_instruction_continue)      (INGRESS_INST_ADDR,    False          )
    #Set the source address
    yield cocotb.external(dma.set_instruction_source_address)   (INGRESS_INST_ADDR,    INGRESS_SOURCE_ADDRESS)
    #set the destination address
    yield cocotb.external(dma.set_instruction_dest_address)     (INGRESS_INST_ADDR,    INGRESS_SINK_ADDRESS  )
    #Set the number of words to transfer
    yield cocotb.external(dma.set_instruction_data_count)       (INGRESS_INST_ADDR,    INGRESS_DATA_COUNT    )
    #If continue is set go to where the 'next' instruction is pointing to
    yield cocotb.external(dma.set_instruction_next_instruction) (INGRESS_INST_ADDR,    INGRESS_INST_ADDR     )
    ###########################################################################

    ###########################################################################
    #Configure DMA to read data from core

    #DMA CONFIGURATION
    #SOURCE
    #associate source port to sink port
    yield cocotb.external(dma.set_channel_sink_addr)            (EGRESS_SOURCE_PORT,  EGRESS_SINK_PORT     )
    #associate source port with instruction address
    yield cocotb.external(dma.set_channel_instruction_pointer)  (EGRESS_SOURCE_PORT,  EGRESS_INST_ADDR     )
    #source will increment address
    yield cocotb.external(dma.enable_source_address_increment)  (EGRESS_SOURCE_PORT,  True          )

    #SINK
    #sink will increment address
    yield cocotb.external(dma.enable_dest_address_increment)    (EGRESS_SINK_PORT,    True          )
    #the sink port must sink in the exact amount of data specified , it cannot end a transaction early
    yield cocotb.external(dma.enable_dest_respect_quantum)      (EGRESS_SINK_PORT,    False         )

    #INSTRUCTION
    #When finished with the instruction the DMA can continue to the 'next' instruction
    yield cocotb.external(dma.enable_instruction_continue)      (EGRESS_INST_ADDR,    False          )
    #Set the source address
    yield cocotb.external(dma.set_instruction_source_address)   (EGRESS_INST_ADDR,    EGRESS_SOURCE_ADDRESS)
    #set the destination address
    yield cocotb.external(dma.set_instruction_dest_address)     (EGRESS_INST_ADDR,    EGRESS_SINK_ADDRESS  )
    #Set the number of words to transfer
    yield cocotb.external(dma.set_instruction_data_count)       (EGRESS_INST_ADDR,    EGRESS_DATA_COUNT    )

    #If continue is set go to where the 'next' instruction is pointing to
    yield cocotb.external(dma.set_instruction_next_instruction) (EGRESS_INST_ADDR,    EGRESS_INST_ADDR     )
    ###########################################################################

    ###########################################################################
    #Enable DMA Transfers
    #Start transfer
    yield cocotb.external(dma.set_channel_instruction_pointer)  (INGRESS_SOURCE_PORT,  INGRESS_INST_ADDR)
    yield cocotb.external(dma.set_channel_instruction_pointer)  (EGRESS_SOURCE_PORT,  EGRESS_INST_ADDR  )
    #Enable the channel to start transacting
    yield cocotb.external(dma.enable_channel)                   (INGRESS_SOURCE_PORT,  True             )
    yield cocotb.external(dma.enable_channel)                   (EGRESS_SOURCE_PORT,  True              )

    ###########################################################################
    '''



    DATA_DWORD_COUNT = 0x100
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(random.randint(0, 0xFF))
        write_data.append(random.randint(0, 0xFF))
        write_data.append(random.randint(0, 0xFF))
        write_data.append(random.randint(0, 0xFF))
        #write_data.append(d)
        #write_data.append(d + 1)
        #write_data.append(d + 2)
        #write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % (len(write_data) / 4))
    #yield cocotb.external(driver.write)(0x00000000, write_data)
    yield cocotb.external(nysa.write_memory)(0x00000000, write_data)
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(nysa.read_memory)(0x00000000, DATA_DWORD_COUNT)
    #read_data = yield cocotb.external(nysa.read_memory)(0x00000000, 0x10)



    yield (nysa.wait_clocks(200))

    fail_count = 0
    pass_count = 0
    for i in range(len(write_data)):
        if write_data[i] != read_data[i]:
            fail_count += 1
            if fail_count < 16:
                print "[0x%04X] 0x%02X != 0x%02X" % (i, write_data[i], read_data[i])
                
            

    '''

    #Disable the channel
    yield cocotb.external(dma.enable_channel)                   (INGRESS_SOURCE_PORT,  False            )
    yield cocotb.external(dma.enable_channel)                   (EGRESS_SOURCE_PORT,  False             )
    #Disable the entire DMA
    yield cocotb.external(dma.enable_dma)(False)
    dut.log.info("Done")
    '''
 
