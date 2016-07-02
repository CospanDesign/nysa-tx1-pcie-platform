#PUT LICENCE HERE!

"""
wb_tx1_pcie Driver

"""

import sys
import os
import time
from array import array as Array

sys.path.append(os.path.join(os.path.dirname(__file__),
                             os.pardir))
from nysa.host.driver import driver

#Sub Module ID
#Use 'nysa devices' to get a list of different available devices
DEVICE_TYPE             = "Experiment"
SDB_ABI_VERSION_MINOR   = 0
SDB_VENDOR_ID           = 0

try:
    SDB_ABI_VERSION_MINOR   = 0
    SDB_VENDOR_ID           = 0x800000000000C594
except SyntaxError:
    pass

#Register Constants
CONTROL_ADDR            = 0x00000000
STATUS_ADDR             = 0x00000001
CONFIG_COMMAND          = 0x00000002
CONFIG_STATUS           = 0x00000003
CONFIG_DCOMMAND         = 0x00000004
CONFIG_DCOMMAND2        = 0x00000005
CONFIG_DSTATUS          = 0x00000006
CONFIG_LCOMMAND         = 0x00000007
CONFIG_LSTATUS          = 0x00000008
CONFIG_LINK_STATE       = 0x00000009
RX_ELEC_IDLE            = 0x0000000A
LTSSM_STATE             = 0x0000000B
GTX_PLL_LOCK            = 0x0000000C
TX_DIFF_CTR             = 0x0000000D

STS_BIT_LINKUP          = 0
STS_BIT_USR_RST         = 1
STS_BIT_PCIE_RST_N      = 2
STS_BIT_PHY_RDY_N       = 3
STS_PLL_LOCKED          = 4
STS_CLK_IN_STOPPED      = 5

class wb_tx1_pcieDriver(driver.Driver):

    """ wb_tx1_pcie

        Communication with a DutDriver wb_tx1_pcie Core
    """
    @staticmethod
    def get_abi_class():
        return 0

    @staticmethod
    def get_abi_major():
        return driver.get_device_id_from_name(DEVICE_TYPE)

    @staticmethod
    def get_abi_minor():
        return SDB_ABI_VERSION_MINOR

    @staticmethod
    def get_vendor_id():
        return SDB_VENDOR_ID

    def __init__(self, nysa, urn, debug = False):
        super(wb_tx1_pcieDriver, self).__init__(nysa, urn, debug)

    def set_control(self, control):
        self.write_register(CONTROL_ADDR, control)

    def get_control(self):
        return self.read_register(CONTROL_ADDR)

    def set_tx_diff(self, value):
        self.write_register(TX_DIFF_CTR, value)

    def get_tx_diff(self):
        return self.read_register(TX_DIFF_CTR)

    def is_linkup(self):
        return self.is_register_bit_set(STATUS_ADDR, STS_BIT_LINKUP)

    def is_pcie_usr_rst(self):
        return self.is_register_bit_set(STATUS_ADDR, STS_BIT_USR_RST)

    def is_pcie_phy_rst(self):
        return self.is_register_bit_set(STATUS_ADDR, STS_BIT_PCIE_RST_N)

    def is_pll_locked(self):
        return self.is_register_bit_set(STATUS_ADDR, STS_PLL_LOCKED)

    def is_clk_in_stopped(self):
        return self.is_register_bit_set(STATUS_ADDR, STS_CLK_IN_STOPPED)

    def is_pcie_phy_ready(self):
        return not self.is_register_bit_set(STATUS_ADDR, STS_BIT_PHY_RDY_N)

    def get_ltssm_state(self):
        state = self.read_register(LTSSM_STATE)
        if   state == 0x000  : return "Detect.Quiet"
        elif state == 0x001  : return "Detect.Quiet.Gen2"
        elif state == 0x002  : return "Detect.Active"
        elif state == 0x003  : return "Detect.ActiveSecond"
        elif state == 0x004  : return "Polling.Active"
        elif state == 0x005  : return "Polling.Config"
        elif state == 0x006  : return "Polling.Comp.Pre.Send.Eios"
        elif state == 0x007  : return "Polling.Comp.Pre.Timeout"
        elif state == 0x008  : return "Polling.Comp.Send.Pattern"
        elif state == 0x009  : return "Polling.Comp.Post.Send.Eior"
        elif state == 0x00A  : return "Polling.Comp.Post.Timeout"
        elif state == 0x00B  : return "Cfg.Lwidth.St0"
        elif state == 0x00C  : return "Cfg.Lwidth.St1"
        elif state == 0x00D  : return "Cfg.LWidth.Ac0"
        elif state == 0x00E  : return "Cfg.Lwidth.Ac1"
        elif state == 0x00F  : return "Cfg.Lnum.Wait"
        elif state == 0x0010 : return "Cfg.Lnum.Acpt"
        elif state == 0x0011 : return "Cfg.Complete.1"
        elif state == 0x0012 : return "Cfg.Complete.2"
        elif state == 0x0013 : return "Cfg.Complete.4"
        elif state == 0x0014 : return "Cfg.Complete.8"
        elif state == 0x0015 : return "Cfg.Idle"
        elif state == 0x0016 : return "L0"
        elif state == 0x0017 : return "L1.Entry.0"
        elif state == 0x0018 : return "L1.Entry.1"
        elif state == 0x0019 : return "L1.Entry.2"
        elif state == 0x001A : return "L1.Idle"
        elif state == 0x001B : return "L1.Exit"
        elif state == 0x001C : return "Rec.RcvLock"
        elif state == 0x001D : return "Rec.RcvCfg"
        elif state == 0x001E : return "Rec.Speed.0"
        elif state == 0x001F : return "Rec.Speed.1"
        elif state == 0x0020 : return "Rec.Idle"
        elif state == 0x0021 : return "Hot.Rst"
        elif state == 0x0022 : return "Disabled.Entry.0"
        elif state == 0x0023 : return "Disabled.Entry.1"
        elif state == 0x0024 : return "Disabled.Entry.2"
        elif state == 0x0025 : return "Disabled.Idle"
        elif state == 0x0026 : return "Dp.Cfg.Lwidth.St0"
        elif state == 0x0027 : return "Dp.Cfg.Lwidth.St1"
        elif state == 0x0028 : return "Dp.Cfg.Lwidth.St2"
        elif state == 0x0029 : return "Dp.Cfg.Lwidth.Ac0"
        elif state == 0x002A : return "Dp.Cfg.Lwidth.Ac1"
        elif state == 0x002B : return "Dp.Cfg.Lwidth.Wait"
        elif state == 0x002C : return "Dp.Cfg.Lwidth.Acpt"
        elif state == 0x002D : return "To.2.Detect"
        elif state == 0x002E : return "Lpbk.Entry.0"
        elif state == 0x002F : return "Lpbk.Entry.1"
        elif state == 0x0030 : return "Lpbk.Active.0"
        elif state == 0x0031 : return "Lpbk.Exit0"
        elif state == 0x0032 : return "Lpbk.Exit1"
        elif state == 0x0033 : return "Lpbkm.Entry0"
        else:
            return "Unknown State: 0x%02X" % state

    def get_gtx_pll_lock_reg(self):
        return self.read_register(GTX_PLL_LOCK)


    def enable_control_0_bit(self, enable):
        self.enable_register_bit(CONTROL_ADDR, ZERO_BIT, enable)

    def is_control_0_bit_set(self):
        return self.is_register_bit_set(CONTROL_ADDR, ZERO_BIT)

    def get_cfg_command(self):
        return self.read_register(CONFIG_COMMAND)

    def get_cfg_status(self):
        return self.read_register(CONFIG_STATUS)

    def get_cfg_dcommand(self):
        return self.read_register(CONFIG_DCOMMAND)

    def get_cfg_dcommand2(self):
        return self.read_register(CONFIG_DCOMMAND2)

    def get_cfg_dstatus(self):
        return self.read_register(CONFIG_DSTATUS)

    def get_cfg_lcommand(self):
        return self.read_register(CONFIG_LCOMMAND)

    def get_cfg_lstatus(self):
        return self.read_register(CONFIG_LSTATUS)

    def get_link_state(self):
        return self.read_register(CONFIG_LINK_STATE)

    def get_elec_idle(self):
        return self.read_register(RX_ELEC_IDLE)


