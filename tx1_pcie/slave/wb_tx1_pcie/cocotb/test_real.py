#!/usr/bin/env python

import unittest
import json
import sys
import os
import time
from array import array as Array
from dut_driver import wb_tx1_pcieDriver

sys.path.append(os.path.join(os.path.dirname(__file__),
                             os.pardir,
                             os.pardir))

from nysa.common.status import Status
from nysa.host.nysa import NysaCommError

from nysa.host.platform_scanner import PlatformScanner

DRIVER = wb_tx1_pcieDriver

def create_inc_buf(count):
    buf = Array('B')
    for i in range(count):
        buf.append(i % 256)
    return buf

def create_empty_buf(count):
    buf = Array('B')
    for i in range(count):
        buf.append(0x00)
    return buf


class Test (unittest.TestCase):

    def setUp(self):
        self.s = Status()
        plat = ["", None, None]
        pscanner = PlatformScanner()
        platform_dict = pscanner.get_platforms()
        platform_names = platform_dict.keys()

        if "sim" in platform_names:
            #If sim is in the platforms, move it to the end
            platform_names.remove("sim")
            platform_names.append("sim")
        urn = None
        for platform_name in platform_names:
            if plat[1] is not None:
                break

            self.s.Debug("Platform: %s" % str(platform_name))

            platform_instance = platform_dict[platform_name](self.s)
            #self.s.Verbose("Platform Instance: %s" % str(platform_instance))

            instances_dict = platform_instance.scan()

            for name in instances_dict:

                try:
                    #s.Verbose("Found Platform Item: %s" % str(platform_item))
                    n = instances_dict[name]
                    plat = ["", None, None]
                    
                    if n is not None:
                        self.s.Important("Found a nysa instance: %s" % name)
                        try:
                            n.read_sdb()
                        except IndexError:
                            self.s.Warning("%s is not responding..." % name)
                            continue
                        #import pdb; pdb.set_trace()
                        if n.is_device_in_platform(DRIVER):
                            plat = [platform_name, name, n]
                            break
                        continue
                    
                    #self.s.Verbose("\t%s" % psi)
                except NysaCommError:
                    continue

        if plat[1] is None:
            self.driver = None
            return
        n = plat[2]
        self.n = n
        pcie_urn = n.find_device(DRIVER)[0]
        self.driver = DRIVER(n, pcie_urn)
        self.s.set_level("verbose")

        self.s.Info("Using Platform: %s" % plat[0])
        self.s.Info("Instantiated a PCIE Device Device: %s" % pcie_urn)

    def test_device(self):
        self.s.Info("Getting clock rate")
        self.driver.set_tx_diff(0x0C)
        print ""
        self.s.Info("TX Diff Control:        0x%04X" % self.driver.get_tx_diff())
        self.s.Info("Link Up:                %s" % self.driver.is_linkup())
        self.s.Info("PCIE USR Reset:         %s" % self.driver.is_pcie_usr_rst())
        self.s.Info("PCIE PHY Reset:         %s" % self.driver.is_pcie_phy_rst())
        self.s.Info("PCIE PHY Ready          %s" % self.driver.is_pcie_phy_ready())
        self.s.Info("PCIE Elect Idle:        0x%02X" % self.driver.get_elec_idle())
        self.s.Info("LTSSM:                  %s" % self.driver.get_ltssm_state())
        self.s.Info("Input Clocked Stopped:  %s" % self.driver.is_clk_in_stopped())
        self.s.Info("PLL Locked:             %s" % self.driver.is_pll_locked())
        print ""
        self.s.Info("Config Command:         0x%04X" % self.driver.get_cfg_command())
        self.s.Info("Config Status:          0x%04X" % self.driver.get_cfg_status())
        self.s.Info("Config DCommand:        0x%04X" % self.driver.get_cfg_dcommand())
        self.s.Info("Config DCommand2:       0x%04X" % self.driver.get_cfg_dcommand2())
        self.s.Info("Config DStatus:         0x%04X" % self.driver.get_cfg_dstatus())
        self.s.Info("Config LCommand:        0x%04X" % self.driver.get_cfg_lcommand())
        self.s.Info("Config LStatus:         0x%04X" % self.driver.get_cfg_lstatus())
        self.s.Info("State:                  0x%04X" % self.driver.get_link_state())
        self.s.Info("GTX PLL Locked:         0x%04X" % self.driver.get_gtx_pll_lock_reg())
        print ""


if __name__ == "__main__":
    unittest.main()

