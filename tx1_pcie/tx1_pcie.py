""" tx1_pcie

Concrete interface for Nysa on the tx1_pcie board
"""

__author__ = 'you@example.com'

import sys
import os
import time
from collections import OrderedDict
from array import array as Array

from nysa.cbuilder.sdb import SDBError
from nysa.host.nysa import Nysa
from nysa.host.nysa import NysaError
from nysa.host.nysa import NysaCommError
from nysa.host.driver.utils import dword_to_array
from nysa.host.driver.utils import array_to_dword
from nysa.common.print_utils import print_32bit_hex_array

IDWORD                      = 0xCD15DBE5

CMD_COMMAND_RESET           = 0x0080
CMD_PERIPHERAL_WRITE        = 0x0081
CMD_PERIPHERAL_WRITE_FIFO   = 0x0082
CMD_PERIPHERAL_READ         = 0x0083
CMD_PERIPHERAL_READ_FIFO    = 0x0084
CMD_MEMORY_WRITE            = 0x0085
CMD_MEMORY_READ             = 0x0086
CMD_DMA_WRITE               = 0x0087
CMD_DMA_READ                = 0x0088
CMD_PING                    = 0x0089
CMD_READ_CONFIG             = 0x008A

BAR0_ADDR                   = 0x00000000
STATUS_BUFFER_ADDRESS       = 0x01000000
WRITE_BUFFER_A_ADDRESS      = 0x02000000
WRITE_BUFFER_B_ADDRESS      = 0x03000000
READ_BUFFER_A_ADDRESS       = 0x04000000
READ_BUFFER_B_ADDRESS       = 0x05000000
BUFFER_SIZE                 = 0x00000400

MAX_PACKET_SIZE             = 0x40

#Register Values
HDR_STATUS_BUF_ADDR       = "status_buf"
HDR_BUFFER_READY          = "hst_buffer_rdy"
HDR_WRITE_BUF_A_ADDR      = "write_buffer_a"
HDR_WRITE_BUF_B_ADDR      = "write_buffer_b"
HDR_READ_BUF_A_ADDR       = "read_buffer_a"
HDR_READ_BUF_B_ADDR       = "read_buffer_b"
HDR_BUFFER_SIZE           = "dword_buffer_size"
HDR_INDEX_VALUEA          = "index value a"
HDR_INDEX_VALUEB          = "index value b"
HDR_DEV_ADDR              = "device_addr"
STS_DEV_STATUS            = "device_status"
STS_BUF_RDY               = "dev_buffer_rdy"
STS_BUF_POS               = "hst_buf_addr"
STS_INTERRUPT             = "interrupt"
HDR_AUX_BUFFER_READY      = "hst_buffer_rdy"

REGISTERS = OrderedDict([
    (HDR_STATUS_BUF_ADDR  , "Address of the Status Buffer on host computer" ),
    (HDR_BUFFER_READY     , "Buffer Ready (Controlled by host)"             ),
    (HDR_WRITE_BUF_A_ADDR , "Address of Write Buffer 0 on host computer"    ),
    (HDR_WRITE_BUF_B_ADDR , "Address of Write Buffer 1 on host computer"    ),
    (HDR_READ_BUF_A_ADDR  , "Address of Read Buffer 0 on host computer"     ),
    (HDR_READ_BUF_B_ADDR  , "Address of Read Buffer 1 on host computer"     ),
    (HDR_BUFFER_SIZE      , "Size of the buffer on host computer"           ),
    (HDR_INDEX_VALUEA     , "Value of Index A"                              ),
    (HDR_INDEX_VALUEB     , "Value of Index B"                              ),
    (HDR_DEV_ADDR         , "Address to read from or write to on device"    ),
    (STS_DEV_STATUS       , "Device Status"                                 ),
    (STS_BUF_RDY          , "Buffer Ready Status (Controller from device)"  ),
    (STS_BUF_POS          , "Address on Host"                               ),
    (STS_INTERRUPT        , "Interrupt Status"                              ),
    (HDR_AUX_BUFFER_READY , "Buffer Ready (Controlled by host)"             )
])

SB_READY          = "ready"
SB_WRITE          = "write"
SB_READ           = "read"
SB_FIFO           = "flag_fifo"
SB_PING           = "ping"
SB_READ_CFG       = "read_cfg"
SB_UNKNOWN_CMD    = "unknown_cmd"
SB_PPFIFO_STALL   = "ppfifo_stall"
SB_HOST_BUF_STALL = "host_buf_stall"
SB_PERIPH         = "flag_peripheral"
SB_MEM            = "flag_mem"
SB_DMA            = "flag_dma"
SB_INTERRUPT      = "interrupt"
SB_RESET          = "reset"
SB_DONE           = "done"
SB_CMD_ERR        = "error"

STATUS_BITS = OrderedDict([
    (SB_READY          , "Ready for new commands"      ),
    (SB_WRITE          , "Write Command Enabled"       ),
    (SB_READ           , "Read Command Enabled"        ),
    (SB_FIFO           , "Flag: Read/Write FIFO"       ),
    (SB_PING           , "Ping Command"                ),
    (SB_READ_CFG       , "Read Config Request"         ),
    (SB_UNKNOWN_CMD    , "Unknown Command"             ),
    (SB_PPFIFO_STALL   , "Stall Due to Ping Pong FIFO" ),
    (SB_HOST_BUF_STALL , "Stall Due to Host Buffer"    ),
    (SB_PERIPH         , "Flag: Peripheral Bus"        ),
    (SB_MEM            , "Flag: Memory"                ),
    (SB_DMA            , "Flag: DMA"                   ),
    (SB_INTERRUPT      , "Device Initiated Interrupt"  ),
    (SB_RESET          , "Reset Command"               ),
    (SB_DONE           , "Command Done"                ),
    (SB_CMD_ERR        , "Error executing command"     )
])


ARTEMIS_MEMORY_OFFSET = 0x0100000000

class Tx1Pcie(Nysa):

    def __init__(self, path, status = None):
        Nysa.__init__(self, status)
        self.path = path
        self.dev = None
        self.dev = os.open(path, os.O_RDWR)

    def set_command_mode(self):
        #XXX: Change this to a seperate file
        os.lseek(self.dev, 0, os.SEEK_END)

    def set_data_mode(self):
        #XXX: Change this to a seperate file
        os.lseek(self.dev, 0, os.SEEK_SET)

    def set_dev_addr(self, address):
        self.dev_addr = address
        reg = NysaPCIEConfig.get_config_reg(HDR_DEV_ADDR)
        self.write_pcie_reg(reg, address)

    def write_pcie_reg(self, address, data):
        d = Array('B')
        d.extend(dword_to_array(address))
        d.extend(dword_to_array(data))
        self.set_command_mode()
        #self.dev.write(d)
        os.write(self.dev, d)
        self.set_data_mode()

    def write_pcie_command(self, command, count, address):
        d = Array('B')
        d.extend(dword_to_array(command))
        d.extend(dword_to_array(count))
        d.extend(dword_to_array(address))
        self.set_command_mode()
        #self.dev.write(d)
        os.write(self.dev, d)
        self.set_data_mode()

    def read(self, address, length = 1, disable_auto_inc = False):
        """read

        Generic read command used to read data from a Nysa image
        
        Args:
            length (int): Number of 32 bit words to read from the FPGA
            address (int):  Address of the register/memory to read
            disable_auto_inc (bool): if true, auto increment feature will be disabled

        Returns:
            (Array of unsigned bytes): A byte array containtin the raw data
                                     returned from Nysa

        Raises:
            NysaCommError: When a failure of communication is detected
        """
        #print "Read"
        d = Array('B')
        if length == 0:
            length = 1

        command = 0x00000002
        d.extend(dword_to_array(IDWORD))
        if address >= ARTEMIS_MEMORY_OFFSET:
            address -= ARTEMIS_MEMORY_OFFSET
            command |= 0x10000
        if disable_auto_inc:
            command |= 0x20000

        d.extend(dword_to_array(command))
        d.extend(dword_to_array(length))
        d.extend(dword_to_array(address))

        hdr_byte_len = len(d)
        hdr_dword_len = hdr_byte_len / 4


        self.write_pcie_command(CMD_PERIPHERAL_WRITE, hdr_dword_len, 0x00)
        os.write(self.dev, d)
        self.write_pcie_command(CMD_PERIPHERAL_READ, length + hdr_dword_len, 0x00)
        #print "Read Command"
        #print_32bit_hex_array(d)
        data = Array('B', os.read(self.dev, ((length * 4) + hdr_byte_len)))
        #print "Data:"
        #print_32bit_hex_array(data)
        return data[hdr_byte_len:]

    def write(self, address, data, disable_auto_inc = False):
        """write

        Generic write command usd to write data to a Nysa image
        
        Args:
            address (int): Address of the register/memory to read
            data (array of unsigned bytes): Array of raw bytes to send to the
                                           device
            disable_auto_inc (bool): if true, auto increment feature will be disabled
        Returns:
            Nothing

        Raises:
            AssertionError: This function must be overriden by a board specific
                implementation
        """
        while (len(data) % 4) != 0:
            data.append(0x00)

        length = len(data) / 4
        d = Array('B')

        command = 0x00000001
        d.extend(dword_to_array(IDWORD))
        if address >= ARTEMIS_MEMORY_OFFSET:
            address -= ARTEMIS_MEMORY_OFFSET
            command |= 0x10000
        if disable_auto_inc:
            command |= 0x20000

        d.extend(dword_to_array(command))
        d.extend(dword_to_array(length))
        d.extend(dword_to_array(address))
        d.extend(data)
        #print "Write Command"
        self.write_pcie_command(CMD_PERIPHERAL_WRITE, (len(d) / 4), 0x00)
        #print "Data:"
        #print_32bit_hex_array(d)
        os.write(self.dev, d)

    def ping(self):
        """ping

        Pings the Nysa image

        Args:
          Nothing

        Returns:
          Nothing

        Raises:
          NysaCommError: When a failure of communication is detected
        """
        return
        #raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def reset(self):
        """reset

        Software reset the Nysa FPGA Master, this may not actually reset the
        entire FPGA image

        Args:
          Nothing

        Returns:
          Nothing

        Raises:
          NysaCommError: A failure of communication is detected
        """
        self.write_pcie_command(CMD_COMMAND_RESET, 0, 0)
        #raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def is_programmed(self):
        """
        Returns True if the FPGA is programmed

        Args:
            Nothing

        Returns (Boolean):
            True: FPGA is programmed
            False: FPGA is not programmed

        Raises:
            NysaCommError: A failure of communication is detected
        """
        return True
        #raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def get_sdb_base_address(self):
        """
        Return the base address of the SDB (This is platform specific)

        Args:
            Nothing

        Returns:
            32-bit unsigned integer of the address where the SDB can be read

        Raises:
            Nothing
        """
        return 0x00000000

    def wait_for_interrupts(self, wait_time = 1):
        """wait_for_interrupts

        listen for interrupts for the specified amount of time

        Args:
          wait_time (int): the amount of time in seconds to wait for an
                           interrupt

        Returns:
          (boolean):
            True: Interrupts were detected
            False: No interrupts detected

        Raises:
            NysaCommError: A failure of communication is detected
        """
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def register_interrupt_callback(self, index, callback):
        """ register_interrupt

        Setup the thread to call the callback when an interrupt is detected

        Args:
            index (Integer): bit position of the device
                if the device is 1, then set index = 1
            callback: a function to call when an interrupt is detected

        Returns:
            Nothing

        Raises:
            Nothing
        """
        #raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)
        return

    def unregister_interrupt_callback(self, index, callback = None):
        """ unregister_interrupt_callback

        Removes an interrupt callback from the reader thread list

        Args:
            index (Integer): bit position of the associated device
                EX: if the device that will receive callbacks is 1, index = 1
            callback: a function to remove from the callback list

        Returns:
            Nothing

        Raises:
            Nothing (This function fails quietly if ther callback is not found)
        """
        #raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)
        return

    def get_board_name(self):
        return "artemis_pcie"

    def upload(self, filepath):
        """
        Uploads an image to a board

        Args:
            filepath (String): path to the file to upload

        Returns:
            Nothing

        Raises:
            NysaError:
                Failed to upload data
            AssertionError:
                Not Implemented
        """

        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def program (self):
        """
        Initiate an FPGA program sequence, THIS DOES NOT UPLOAD AN IMAGE, use
        upload to upload an FPGA image

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            AssertionError:
                Not Implemented
        """
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def ioctl(self, name, arg = None):
        """
        Platform specific functions to execute on a Nysa device implementation.

        For example a board may be capable of setting an external voltage or
        reading configuration data from an EEPROM. All these extra functions
        cannot be encompused in a generic driver

        Args:
            name (String): Name of the function to execute
            args (object): A generic object that can be used to pass an
                arbitrary or multiple arbitrary variables to the device

        Returns:
            (object) an object from the underlying function

        Raises:
            NysaError:
                An implementation specific error
        """

        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def list_ioctl(self):
        """
        Return a tuple of ioctl functions and argument types and descriptions
        in the following format:
            {
                [name, description, args_type_object],
                [name, description, args_type_object]
                ...
            }

        Args:
            Nothing

        Raises:
            AssertionError:
                Not Implemented

        """
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)


