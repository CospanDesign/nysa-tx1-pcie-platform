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
from dut_driver import wb_tx1_ddr3Driver

SIM_CONFIG = "sim_config.json"


CLK_PERIOD = 10

MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "rtl")
MODULE_PATH = os.path.abspath(MODULE_PATH)


def setup_dut(dut):
    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())

@cocotb.coroutine
def wait_ready(nysa, dut):

    #while not dut.hd_ready.value.get_value():
    #    yield(nysa.wait_clocks(1))

    #yield(nysa.wait_clocks(100))
    pass

@cocotb.test(skip = True)
def single_dword_write_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 0

    Expected Results:
        Write to all registers
    """


    dut.test_id = 0
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))
    #yield cocotb.external(driver.write(0x00, [0x00, 0x01, 0x02, 0x03]))
    yield cocotb.external(driver.set_control)(0x01234567)
    yield (nysa.wait_clocks(100))
    #v = yield cocotb.external(driver.get_control)()
    #dut.log.info("V: %d" % v)
    dut.log.info("DUT Opened!")
    dut.log.info("Ready")

@cocotb.test(skip = True)
def small_dword_stream_write_test(dut):
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
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))

    DATA_DWORD_COUNT = 4
    #Write a longer packet
    data_out = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        data_out.append(d)
        data_out.append(d + 1)
        data_out.append(d + 2)
        data_out.append(d + 3)

    yield cocotb.external(driver.write)(0x00000000, data_out)
    yield (nysa.wait_clocks(100))
    #v = yield cocotb.external(driver.get_control)()
    #dut.log.info("V: %d" % v)
    dut.log.info("DUT Opened!")
    dut.log.info("Ready")

@cocotb.test(skip = True)
def full_packet_stream_write_test(dut):
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
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))

    DATA_DWORD_COUNT = 1024
    #Write a longer packet
    data_out = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        data_out.append(d)
        data_out.append(d + 1)
        data_out.append(d + 2)
        data_out.append(d + 3)

    yield cocotb.external(driver.write)(0x00000000, data_out)
    yield (nysa.wait_clocks(100))
    #v = yield cocotb.external(driver.get_control)()
    #dut.log.info("V: %d" % v)
    dut.log.info("DUT Opened!")
    dut.log.info("Ready")

@cocotb.test(skip = True)
def two_packet_stream_write_test(dut):
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
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))

    DATA_DWORD_COUNT = 2048
    #Write a longer packet
    data_out = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        data_out.append(d)
        data_out.append(d + 1)
        data_out.append(d + 2)
        data_out.append(d + 3)

    yield cocotb.external(driver.write)(0x00000000, data_out)
    yield (nysa.wait_clocks(100))
    #v = yield cocotb.external(driver.get_control)()
    #dut.log.info("V: %d" % v)
    dut.log.info("DUT Opened!")
    dut.log.info("Ready")

@cocotb.test(skip = False)
def single_block_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 4

    Expected Results:
        Write to all registers
    """


    dut.test_id = 4
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 1024
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % len(write_data))
    yield cocotb.external(driver.write)(0x00000000, write_data)
    yield (nysa.wait_clocks(100))
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(driver.read)(0x00, DATA_DWORD_COUNT)
    yield (nysa.wait_clocks(100))

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

@cocotb.test(skip = False)
def double_block_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 5

    Expected Results:
        Write to all registers
    """


    dut.test_id = 5
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 2048
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % len(write_data))
    yield cocotb.external(driver.write)(0x00000000, write_data)
    yield (nysa.wait_clocks(100))
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(driver.read)(0x00, DATA_DWORD_COUNT)
    yield (nysa.wait_clocks(100))

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


@cocotb.test(skip = False)
def single_dword_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 6

    Expected Results:
        Write to all registers
    """


    dut.test_id = 6
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 1
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % len(write_data))
    yield cocotb.external(driver.write)(0x00000000, write_data)
    yield (nysa.wait_clocks(100))
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(driver.read)(0x00, DATA_DWORD_COUNT)
    yield (nysa.wait_clocks(100))

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



@cocotb.test(skip = False)
def small_dword_write_read_test(dut):
    """
    Description:
        Very Basic Functionality
            Startup Nysa

    Test ID: 7

    Expected Results:
        Write to all registers
    """


    dut.test_id = 7
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = wb_tx1_ddr3Driver(nysa, nysa.find_device(wb_tx1_ddr3Driver)[0])
    yield (nysa.wait_clocks(100))
    DATA_DWORD_COUNT = 3
    #Write a longer packet
    write_data = Array('B')
    for i in range (DATA_DWORD_COUNT):
        d = (i * 4) % 256
        write_data.append(d)
        write_data.append(d + 1)
        write_data.append(d + 2)
        write_data.append(d + 3)

    dut.log.info("\tWriting: 0x%08X DWORDS" % len(write_data))
    yield cocotb.external(driver.write)(0x00000000, write_data)
    yield (nysa.wait_clocks(100))
    dut.log.info("\tReading: 0x%08X DWORDS" % DATA_DWORD_COUNT)
    read_data = yield cocotb.external(driver.read)(0x00, DATA_DWORD_COUNT)
    yield (nysa.wait_clocks(100))

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


