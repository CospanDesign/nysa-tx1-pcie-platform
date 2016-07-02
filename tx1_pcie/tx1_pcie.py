""" tx1_pcie

Concrete interface for Nysa on the tx1_pcie board
"""

__author__ = 'you@example.com'

import sys
import os
import time
import serial
import string
from array import array as Array

from nysa.cbuilder.sdb import SDBError
from nysa.host.nysa import Nysa
from nysa.host.nysa import NysaError
from nysa.host.nysa import NysaCommError

BAUDRATE = 115200

class Tx1Pcie(Nysa):

    def __init__(self, path, status = None):
        Nysa.__init__(self, status)
        ser_path = path
        self.ser = serial.Serial(path, BAUDRATE)
        self.ser.timeout = 2
        self.ser.flushInput()
        if self.ser == None:
            print "Error openning Serial Port"

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
        read_cmd = "L%07X%08X%08X00000000"
        command = 0x00000002
        if disable_auto_inc:
            command |= 0x00020000

        read_cmd = read_cmd % (command, length, address)
        #print "Read Command: %s" % read_cmd
        self.ser.write(read_cmd)
        read_resp = self.ser.read(24 + ((length) * 8))
        a = Array('B', read_resp)
        #print "Length of response: %d: %s" % (len(read_resp), str(a))
        #print "Response: %s" % read_resp
        response = Array('B')
        d = read_resp[24:]

        for i in range (0, len(d), 2):
            v = int(d[i], 16) << 4
            v |= int(d[i + 1], 16)
            response.append(v)

        return response

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
        length = (len(data) / 4)
        write_cmd = "L%0.7X00000001%0.8X"
        write_cmd = write_cmd % (length, address)
        for d in data:
            write_cmd += "%X" % ((d >> 4) & 0xF)
            write_cmd += "%X" % (d & 0xF)
        self.ser.write(write_cmd)
        #self.ser.flushInput()
        write_rsp = self.ser.read(32)

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
        #self.ser.flushInput() 
        self.ser.write("L0000000000000000000000000000000")
        ping_string = self.ser.read(32)
        #print "print string: %s" % str(Array('B', ping_string))

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
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

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
        #self.s.Warning("UART Interface does not report %s" % sys._getframe().f_code.co_name)
        return True

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
        return 0x00

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
        temp_timeout = self.ser.timeout
        self.ser.timeout = wait_time
        temp_string = self.ser.read(32)
        self.ser.timeout = temp_timeout
        if len(temp_string) == 0:
            return False
        self.interrupt_address = string.atoi(temp_string[16:24], 16)
        self.interrupts = string.atoi(temp_string[24:32], 16)
        return True

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
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def get_board_name(self):
        return "uart"

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
        self.s.Warning("UART Interface does not report %s" % sys._getframe().f_code.co_name)

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
        self.s.Warning("UART Interface does not report %s" % sys._getframe().f_code.co_name)

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


