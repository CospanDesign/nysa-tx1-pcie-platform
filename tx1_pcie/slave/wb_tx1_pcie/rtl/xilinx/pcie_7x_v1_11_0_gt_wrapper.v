//-----------------------------------------------------------------------------
//
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : pcie_7x_v1_11_0_gt_wrapper.v
// Version    : 1.11
//------------------------------------------------------------------------------
//  Filename     :  gt_wrapper.v
//  Description  :  GT Wrapper Module for 7 Series Transceiver
//  Version      :  19.0
//------------------------------------------------------------------------------



`timescale 1ns / 1ps



//---------- GT Wrapper --------------------------------------------------------
module pcie_7x_v1_11_0_gt_wrapper #
(

    parameter PCIE_SIM_MODE                 = "FALSE",      // PCIe sim mode
    parameter PCIE_SIM_SPEEDUP              = "FALSE",      // PCIe sim speedup
    parameter PCIE_SIM_TX_EIDLE_DRIVE_LEVEL = "1",          // PCIe sim TX electrical idle drive level
    parameter PCIE_GT_DEVICE                = "GTX",        // PCIe GT device
    parameter PCIE_USE_MODE                 = "3.0",        // PCIe use mode
    parameter PCIE_PLL_SEL                  = "CPLL",       // PCIe PLL select for Gen1/Gen2
    parameter PCIE_LPM_DFE                  = "LPM",        // PCIe LPM or DFE mode for Gen1/Gen2 only
    parameter PCIE_LPM_DFE_GEN3             = "DFE",        // PCIe LPM or DFE mode for Gen3      only
    parameter PCIE_ASYNC_EN                 = "FALSE",      // PCIe async enable
    parameter PCIE_TXBUF_EN                 = "FALSE",      // PCIe TX buffer enable for Gen1/Gen2 only
    parameter PCIE_TXSYNC_MODE              = 0,            // PCIe TX sync mode
    parameter PCIE_RXSYNC_MODE              = 0,            // PCIe RX sync mode
    parameter PCIE_CHAN_BOND                = 0,            // PCIe channel bonding mode
    parameter PCIE_CHAN_BOND_EN             = "TRUE",       // PCIe channel bonding enable for Gen1/Gen2 only
    parameter PCIE_LANE                     = 1,            // PCIe number of lane
    parameter PCIE_REFCLK_FREQ              = 0,            // PCIe reference clock frequency
    parameter PCIE_TX_EIDLE_ASSERT_DELAY    = 3'd4,         // PCIe TX electrical idle assert delay
    parameter PCIE_OOBCLK_MODE              = 1,            // PCIe OOB clock mode
    parameter PCIE_DEBUG_MODE               = 0             // PCIe debug mode

)

(

    //---------- GT User Ports -----------------------------
    input               GT_MASTER,
    input               GT_GEN3,
    input               GT_RX_CONVERGE,

    //---------- GT Clock Ports ----------------------------
    input               GT_GTREFCLK0,
    input               GT_QPLLCLK,
    input               GT_QPLLREFCLK,
    input               GT_TXUSRCLK,
    input               GT_RXUSRCLK,
    input               GT_TXUSRCLK2,
    input               GT_RXUSRCLK2,
    input               GT_OOBCLK,
    input       [ 1:0]  GT_TXSYSCLKSEL,
    input       [ 1:0]  GT_RXSYSCLKSEL,

    output              GT_TXOUTCLK,
    output              GT_RXOUTCLK,
    output              GT_CPLLLOCK,
    output              GT_RXCDRLOCK,

    //---------- GT Reset Ports ----------------------------
    input               GT_CPLLPD,
    input               GT_CPLLRESET,
    input               GT_TXUSERRDY,
    input               GT_RXUSERRDY,
    input               GT_RESETOVRD,
    input               GT_GTTXRESET,
    input               GT_GTRXRESET,
    input               GT_TXPMARESET,
    input               GT_RXPMARESET,
    input               GT_RXCDRRESET,
    input               GT_RXCDRFREQRESET,
    input               GT_RXDFELPMRESET,
    input               GT_EYESCANRESET,
    input               GT_TXPCSRESET,
    input               GT_RXPCSRESET,
    input               GT_RXBUFRESET,

    output              GT_TXRESETDONE,
    output              GT_RXRESETDONE,
    output              GT_RXPMARESETDONE,

    //---------- GT TX Data Ports --------------------------
    input       [31:0]  GT_TXDATA,
    input       [ 3:0]  GT_TXDATAK,

    output              GT_TXP,
    output              GT_TXN,

    //---------- GT RX Data Ports --------------------------
    input               GT_RXN,
    input               GT_RXP,

    output      [31:0]  GT_RXDATA,
    output      [ 3:0]  GT_RXDATAK,

    //---------- GT Command Ports --------------------------
    input               GT_TXDETECTRX,
    input               GT_TXELECIDLE,
    input               GT_TXCOMPLIANCE,
    input               GT_RXPOLARITY,
    input       [ 1:0]  GT_TXPOWERDOWN,
    input       [ 1:0]  GT_RXPOWERDOWN,
    input       [ 2:0]  GT_TXRATE,
    input       [ 2:0]  GT_RXRATE,

    //---------- GT Electrical Command Ports ---------------
    input       [ 2:0]  GT_TXMARGIN,
    input               GT_TXSWING,
    input               GT_TXDEEMPH,
    input       [ 4:0]  GT_TXPRECURSOR,
    input       [ 6:0]  GT_TXMAINCURSOR,
    input       [ 4:0]  GT_TXPOSTCURSOR,

    //---------- GT Status Ports ---------------------------
    output              GT_RXVALID,
    output              GT_PHYSTATUS,
    output              GT_RXELECIDLE,
    output      [ 2:0]  GT_RXSTATUS,
    output      [ 2:0]  GT_RXBUFSTATUS,
    output              GT_TXRATEDONE,
    output              GT_RXRATEDONE,

    //---------- GT DRP Ports ------------------------------
    input               GT_DRPCLK,
    input       [ 8:0]  GT_DRPADDR,
    input               GT_DRPEN,
    input       [15:0]  GT_DRPDI,
    input               GT_DRPWE,

    output      [15:0]  GT_DRPDO,
    output              GT_DRPRDY,

    //---------- GT TX Sync Ports --------------------------
    input               GT_TXPHALIGN,
    input               GT_TXPHALIGNEN,
    input               GT_TXPHINIT,
    input               GT_TXDLYBYPASS,
    input               GT_TXDLYSRESET,
    input               GT_TXDLYEN,

    output              GT_TXDLYSRESETDONE,
    output              GT_TXPHINITDONE,
    output              GT_TXPHALIGNDONE,

    input               GT_TXPHDLYRESET,
    input               GT_TXSYNCMODE,                      // GTH
    input               GT_TXSYNCIN,                        // GTH
    input               GT_TXSYNCALLIN,                     // GTH

    output              GT_TXSYNCOUT,                       // GTH
    output              GT_TXSYNCDONE,                      // GTH

    //---------- GT RX Sync Ports --------------------------
    input               GT_RXPHALIGN,
    input               GT_RXPHALIGNEN,
    input               GT_RXDLYBYPASS,
    input               GT_RXDLYSRESET,
    input               GT_RXDLYEN,
    input               GT_RXDDIEN,

    output              GT_RXDLYSRESETDONE,
    output              GT_RXPHALIGNDONE,

    input               GT_RXSYNCMODE,                      // GTH
    input               GT_RXSYNCIN,                        // GTH
    input               GT_RXSYNCALLIN,                     // GTH

    output              GT_RXSYNCOUT,                       // GTH
    output              GT_RXSYNCDONE,                      // GTH

    //---------- GT Comma Alignment Ports ------------------
    input               GT_RXSLIDE,

    output              GT_RXCOMMADET,
    output      [ 3:0]  GT_RXCHARISCOMMA,
    output              GT_RXBYTEISALIGNED,
    output              GT_RXBYTEREALIGN,

    //---------- GT Channel Bonding Ports ------------------
    input               GT_RXCHBONDEN,
    input       [ 4:0]  GT_RXCHBONDI,
    input       [ 2:0]  GT_RXCHBONDLEVEL,
    input               GT_RXCHBONDMASTER,
    input               GT_RXCHBONDSLAVE,

    output              GT_RXCHANISALIGNED,
    output      [ 4:0]  GT_RXCHBONDO,

    //---------- GT PRBS/Loopback Ports --------------------
    input       [ 2:0]  GT_TXPRBSSEL,
    input       [ 2:0]  GT_RXPRBSSEL,
    input               GT_TXPRBSFORCEERR,
    input               GT_RXPRBSCNTRESET,
    input       [ 2:0]  GT_LOOPBACK,

    output              GT_RXPRBSERR,

    input       [3:0]   i_tx_diff_ctr,
    //---------- GT Debug Ports ----------------------------
    output      [14:0]  GT_DMONITOROUT

);

    //---------- Internal Signals --------------------------
    wire        [ 2:0]  txoutclksel;
    wire        [ 2:0]  rxoutclksel;
    wire        [63:0]  rxdata;
    wire        [ 7:0]  rxdatak;
    wire        [ 7:0]  rxchariscomma;
    wire                rxlpmen;
    wire        [14:0]  dmonitorout;
    wire                dmonitorclk;

    //---------- Select CPLL and Clock Dividers ------------
    localparam          CPLL_REFCLK_DIV = 1;
    localparam          CPLL_FBDIV_45   = 5;
    localparam          CPLL_FBDIV      = (PCIE_REFCLK_FREQ == 2) ?  2 :
                                          (PCIE_REFCLK_FREQ == 1) ?  4 : 5;
    localparam          OUT_DIV         = (PCIE_PLL_SEL == "QPLL") ? 4 : 2;
    localparam          CLK25_DIV       = (PCIE_REFCLK_FREQ == 2) ? 10 :
                                          (PCIE_REFCLK_FREQ == 1) ?  5 : 4;

    //---------- Select IES vs. GES ------------------------
    localparam          CLKMUX_PD = ((PCIE_USE_MODE == "1.0") || (PCIE_USE_MODE == "1.1")) ?  1'd0      :  1'd1;

    //---------- Select GTP CPLL configuration -------------
    //  PLL0/1_CFG[ 5:2] = CP1 : [    8, 4, 2, 1] units
    //  PLL0/1_CFG[10:6] = CP2 : [16, 8, 4, 2, 1] units
    //  CP2/CP1 = 2 to 3
    //  (8/4=2)    = 27'h01F0210 = 0000_0001_1111_0000_0010_0001_0000
    //  (9/3=3)    = 27'h01F024C = 0000_0001_1111_0000_0010_0100_1100
    //  (8/3=2.67) = 27'h01F020C = 0000_0001_1111_0000_0010_0000_1100
    //  (7/3=2.33) = 27'h01F01CC = 0000_0001_1111_0000_0001_1100_1100
    //  (6/3=2)    = 27'h01F018C = 0000_0001_1111_0000_0001_1000_1100
    //  (5/3=1.67) = 27'h01F014C = 0000_0001_1111_0000_0001_0100_1100
    //  (6/2=3)    = 27'h01F0188 = 0000_0001_1111_0000_0001_1000_1000
    //---------- Select GTX CPLL configuration -------------
    //  CPLL_CFG[ 5: 2]  = CP1 : [    8, 4, 2, 1] units
    //  CPLL_CFG[22:18]  = CP2 : [16, 8, 4, 2, 1] units
    //  CP2/CP1 = 2 to 3
    //  (9/3=3)    = 1010_0100_0000_0111_1100_1100
    //------------------------------------------------------
    localparam          CPLL_CFG  = ((PCIE_USE_MODE == "1.0") || (PCIE_USE_MODE == "1.1")) ? 24'hB407CC : 24'hA407CC;

    //---------- Select TX XCLK ----------------------------
    //  TXOUT for TX Buffer Use
    //  TXUSR for TX Buffer Bypass
    //------------------------------------------------------
    localparam          TX_XCLK_SEL = (PCIE_TXBUF_EN == "TRUE") ? "TXOUT" : "TXUSR";

    //---------- Select TX Receiver Detection Configuration
    localparam          TX_RXDETECT_CFG = (PCIE_REFCLK_FREQ == 2) ? 14'd250 :
                                          (PCIE_REFCLK_FREQ == 1) ? 14'd125 : 14'd100;
    localparam          TX_RXDETECT_REF = (((PCIE_USE_MODE == "1.0") || (PCIE_USE_MODE == "1.1")) && (PCIE_SIM_MODE == "FALSE")) ? 3'b000 : 3'b011;

    //---------- Select PCS_RSVD_ATTR ----------------------
    //  [0]: 1 = enable latch when bypassing TX buffer, 0 = disable latch when using TX buffer
    //  [1]: 1 = enable manual TX sync,                 0 = enable auto TX sync
    //  [2]: 1 = enable manual RX sync,                 0 = enable auto RX sync
    //  [3]: 1 = select external clock for OOB          0 = select reference clock for OOB
    //  [6]: 1 = enable DMON                            0 = disable DMON
    //  [7]: 1 = filter stale TX[P/N] data when exiting TX electrical idle
    //  [8]: 1 = power up OOB                           0 = power down OOB
    //------------------------------------------------------
    localparam          OOBCLK_SEL    = (PCIE_OOBCLK_MODE == 0) ? 1'd0  : 1'd1;      // GTX
    localparam          RXOOB_CLK_CFG = (PCIE_OOBCLK_MODE == 0) ? "PMA" : "FABRIC";  // GTH/GTP

    localparam          PCS_RSVD_ATTR = ((PCIE_USE_MODE == "1.0")                           && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd1} :
                                        ((PCIE_USE_MODE == "1.0")                           && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd0} :
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd7} :
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd6} :
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd5} :
                                        ((PCIE_RXSYNC_MODE == 0) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd4} :
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd3} :
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 0) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd2} :
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "FALSE")) ? {44'h0000000001C, OOBCLK_SEL, 3'd1} :
                                        ((PCIE_RXSYNC_MODE == 1) && (PCIE_TXSYNC_MODE == 1) && (PCIE_TXBUF_EN == "TRUE" )) ? {44'h0000000001C, OOBCLK_SEL, 3'd0} : {44'h0000000001C, OOBCLK_SEL, 3'd7};

    //---------- Select RXCDR_CFG --------------------------

    //---------- GTX Note ----------------------------------
    // For GTX PCIe Gen1/Gen2 with 8B/10B, the following CDR setting may provide more margin
    // Async 72'h03_8000_23FF_1040_0020
    // Sync: 72'h03_0000_23FF_1040_0020
    //------------------------------------------------------

    localparam          RXCDR_CFG_GTX = ((PCIE_USE_MODE == "1.0") || (PCIE_USE_MODE == "1.1")) ?
                                        ((PCIE_ASYNC_EN == "TRUE") ? 72'b0000_0010_0000_0111_1111_1110_0010_0000_0110_0000_0010_0001_0001_0000_0000000000010000
                                                                   : 72'h11_07FE_4060_0104_0000):   // IES setting
                                        ((PCIE_ASYNC_EN == "TRUE") ? 72'h03_8000_23FF_1020_0020     //
                                                                   : 72'h03_0000_23FF_1020_0020);   // optimized for GES silicon

    localparam          RXCDR_CFG_GTH = (PCIE_USE_MODE == "2.0") ?
                                        ((PCIE_ASYNC_EN == "TRUE") ? 83'h0_0011_07FE_4060_2104_1010
                                                                   : 83'h0_0011_07FE_4060_0104_1010):  // Optimized for IES silicon
                                        ((PCIE_ASYNC_EN == "TRUE") ? 83'h0_0020_07FE_2000_C208_8018
                                                                   : 83'h0_0020_07FE_2000_C208_0018);  // Optimized for 1.2 silicon

    localparam          RXCDR_CFG_GTP = ((PCIE_ASYNC_EN == "TRUE") ? 83'h0_0001_07FE_4060_2104_1010
                                                                   : 83'h0_0001_07FE_4060_0104_1010);  // Optimized for IES silicon




    //---------- Select TX and RX Sync Mode ----------------
    localparam          TXSYNC_OVRD      = (PCIE_TXSYNC_MODE == 1) ? 1'd0 : 1'd1;
    localparam          RXSYNC_OVRD      = (PCIE_TXSYNC_MODE == 1) ? 1'd0 : 1'd1;

    localparam          TXSYNC_MULTILANE = (PCIE_LANE == 1) ? 1'd0 : 1'd1;
    localparam          RXSYNC_MULTILANE = (PCIE_LANE == 1) ? 1'd0 : 1'd1;

    //---------- Select Clock Correction Min and Max Latency
    //  CLK_COR_MIN_LAT = Larger of (2 * RXCHBONDLEVEL + 13) or (CHAN_BOND_MAX_SKEW + 11)
    //                  = 13 when PCIE_LANE = 1
    //  CLK_COR_MAX_LAT = CLK_COR_MIN_LAT + CLK_COR_SEQ_LEN + 1
    //                  = CLK_COR_MIN_LAT + 2
    //------------------------------------------------------

    //---------- CLK_COR_MIN_LAT Look-up Table -------------
    // Lane | One-Hop  | Daisy-Chain | Binary-Tree
    //------------------------------------------------------
    //    0 |       13 |       13    |       13
    //    1 | 15 to 18 | 15 to 18    | 15 to 18
    //    2 | 15 to 18 | 17 to 18    | 15 to 18
    //    3 | 15 to 18 |       19    | 17 to 18
    //    4 | 15 to 18 |       21    | 17 to 18
    //    5 | 15 to 18 |       23    |       19
    //    6 | 15 to 18 |       25    |       19
    //    7 | 15 to 18 |       27    |       21
    //------------------------------------------------------

    localparam          CLK_COR_MIN_LAT = ((PCIE_LANE == 8) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 27 : 21) :
                                          ((PCIE_LANE == 7) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 25 : 19) :
                                          ((PCIE_LANE == 6) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 23 : 19) :
                                          ((PCIE_LANE == 5) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 21 : 18) :
                                          ((PCIE_LANE == 4) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 19 : 18) :
                                          ((PCIE_LANE == 3) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 18 : 18) :
                                          ((PCIE_LANE == 2) && (PCIE_CHAN_BOND != 0) && (PCIE_CHAN_BOND_EN == "TRUE"))  ? ((PCIE_CHAN_BOND == 1) ? 18 : 18) :
                                          ((PCIE_LANE == 1)                          || (PCIE_CHAN_BOND_EN == "FALSE")) ? 13 : 18;

    localparam          CLK_COR_MAX_LAT = CLK_COR_MIN_LAT + 2;

    //---------- Simulation Speedup ------------------------
  //localparam          CFOK_CFG_GTH = (PCIE_SIM_MODE == "TRUE") ? 42'h240_0004_0F80 : 42'h248_0004_0E80;  // [8] : 1 = Skip CFOK
  //localparam          CFOK_CFG_GTP = (PCIE_SIM_MODE == "TRUE") ? 43'h000_0000_0000 : 43'h000_0000_0100;  // [2] : 1 = Skip CFOK

    //---------- Select [TX/RX]OUTCLK ----------------------
    assign txoutclksel = GT_MASTER ? 3'd3 : 3'd0;
    assign rxoutclksel = ((PCIE_DEBUG_MODE == 1) || ((PCIE_ASYNC_EN == "TRUE") && GT_MASTER)) ? 3'd2 : 3'd0;

    //---------- Select DFE vs. LPM ------------------------
    //  Gen1/2 = Use LPM by default.  Option to use DFE.
    //  Gen3   = Use DFE by default.  Option to use LPM.
    //------------------------------------------------------
    assign rxlpmen = GT_GEN3 ? ((PCIE_LPM_DFE_GEN3 == "LPM") ? 1'd1 : 1'd0) : ((PCIE_LPM_DFE == "LPM") ? 1'd1 : 1'd0);



//---------- Generate DMONITOR Clock Buffer for Debug ------
generate if (PCIE_DEBUG_MODE == 1)

    begin : dmonitorclk_i
    //---------- DMONITOR CLK ------------------------------
    BUFG dmonitorclk_i
    (
        //---------- Input ---------------------------------
        .I                              (dmonitorout[7]),
        //---------- Output --------------------------------
        .O                              (dmonitorclk)
    );
    end

else

    begin : dmonitorclk_i_disable
    assign dmonitorclk = 1'd0;
    end

endgenerate



//---------- Select GTX or GTH or GTP ------------------------------------------
//  Notes  :  Attributes that are commented out always use the GT default settings
//------------------------------------------------------------------------------
//---------- GTX Channel Module --------------------------------------------
GTXE2_CHANNEL #
(
    //---------- Simulation Attributes -------------------------------------
    .SIM_CPLLREFCLK_SEL             (3'b001),                               //
    .SIM_RESET_SPEEDUP              (PCIE_SIM_SPEEDUP),                     //
    .SIM_RECEIVER_DETECT_PASS       ("TRUE"),                               //
    .SIM_TX_EIDLE_DRIVE_LEVEL       (PCIE_SIM_TX_EIDLE_DRIVE_LEVEL),        //
    .SIM_VERSION                    (PCIE_USE_MODE),                        //

    //---------- Clock Attributes ------------------------------------------
    .CPLL_REFCLK_DIV                (CPLL_REFCLK_DIV),                      //
    .CPLL_FBDIV_45                  (CPLL_FBDIV_45),                        //
    .CPLL_FBDIV                     (CPLL_FBDIV),                           //
    .TXOUT_DIV                      (OUT_DIV),                              //
    .RXOUT_DIV                      (OUT_DIV),                              //
    .TX_CLK25_DIV                   (CLK25_DIV),                            //
    .RX_CLK25_DIV                   (CLK25_DIV),                            //
    .TX_CLKMUX_PD                   (CLKMUX_PD),                            // GTX
    .RX_CLKMUX_PD                   (CLKMUX_PD),                            // GTX
    .TX_XCLK_SEL                    (TX_XCLK_SEL),                          // TXOUT = use TX buffer, TXUSR = bypass TX buffer
    .RX_XCLK_SEL                    ("RXREC"),                              // RXREC = use RX buffer, RXUSR = bypass RX buffer
    .OUTREFCLK_SEL_INV              ( 2'b11),                               //
    .CPLL_CFG                       (CPLL_CFG),                             // Optimized for silicon
  //.CPLL_INIT_CFG                  (24'h00001E),                           //
  //.CPLL_LOCK_CFG                  (16'h01E8),                             //

    //---------- Reset Attributes ------------------------------------------
    .TXPCSRESET_TIME                (5'b00001),                             //
    .RXPCSRESET_TIME                (5'b00001),                             //
    .TXPMARESET_TIME                (5'b00011),                             //
    .RXPMARESET_TIME                (5'b00011),                             // Optimized for sim and for DRP
  //.RXISCANRESET_TIME              (5'b00001),                             //

    //---------- TX Data Attributes ----------------------------------------
    .TX_DATA_WIDTH                  (20),                                   // 2-byte external datawidth for Gen1/Gen2
    .TX_INT_DATAWIDTH               ( 0),                                   // 2-byte internal datawidth for Gen1/Gen2

    //---------- RX Data Attributes ----------------------------------------
    .RX_DATA_WIDTH                  (20),                                   // 2-byte external datawidth for Gen1/Gen2
    .RX_INT_DATAWIDTH               ( 0),                                   // 2-byte internal datawidth for Gen1/Gen2

    //---------- Command Attributes ----------------------------------------
    .TX_RXDETECT_CFG                (TX_RXDETECT_CFG),                      //
    .TX_RXDETECT_REF                (TX_RXDETECT_REF),                      //
    .RX_CM_SEL                      ( 2'd3),                                // 0 = AVTT, 1 = GND, 2 = Float, 3 = Programmable
    .RX_CM_TRIM	                    ( 3'b010),                              // Select 800mV
    .TX_EIDLE_ASSERT_DELAY          (PCIE_TX_EIDLE_ASSERT_DELAY),           // Optimized for sim (3'd4)
    .TX_EIDLE_DEASSERT_DELAY        ( 3'b100),                              // Optimized for sim
  //.PD_TRANS_TIME_FROM_P2          (12'h03C),                              //
    .PD_TRANS_TIME_NONE_P2          ( 8'h09),                               //
  //.PD_TRANS_TIME_TO_P2            ( 8'h64),                               //
  //.TRANS_TIME_RATE                ( 8'h0E),                               //

    //---------- Electrical Command Attributes -----------------------------
    .TX_DRIVE_MODE                  ("PIPE"),                               // Gen1/Gen2 = PIPE, Gen3 = PIPEGEN3
    .TX_DEEMPH0                     ( 5'b10100),                            //  6.0 dB
    .TX_DEEMPH1                     ( 5'b01011),                            //  3.5 dB
    .TX_MARGIN_FULL_0               ( 7'b1001111),                          // 1000 mV
    .TX_MARGIN_FULL_1               ( 7'b1001110),                          //  950 mV
    .TX_MARGIN_FULL_2               ( 7'b1001101),                          //  900 mV
    .TX_MARGIN_FULL_3               ( 7'b1001100),                          //  850 mV
    .TX_MARGIN_FULL_4               ( 7'b1000011),                          //  400 mV
    .TX_MARGIN_LOW_0                ( 7'b1000101),                          //  500 mV
    .TX_MARGIN_LOW_1                ( 7'b1000110),                          //  450 mV
    .TX_MARGIN_LOW_2                ( 7'b1000011),                          //  400 mV
    .TX_MARGIN_LOW_3                ( 7'b1000010),                          //  350 mV
    .TX_MARGIN_LOW_4                ( 7'b1000000),                          //  250 mV
    .TX_MAINCURSOR_SEL              ( 1'b0),                                //
    .TX_PREDRIVER_MODE              ( 1'b0),                                // GTX
    .TX_QPI_STATUS_EN               ( 1'b0),                                //

    //---------- Status Attributes -----------------------------------------
    .RX_SIG_VALID_DLY               (4),                                    // Optimized for sim

    //---------- DRP Attributes --------------------------------------------

    //---------- PCS Attributes --------------------------------------------
    .PCS_PCIE_EN                    ("TRUE"),                               // PCIe
    .PCS_RSVD_ATTR                  (PCS_RSVD_ATTR),                        //

    //---------- PMA Attributes --------------------------------------------
    .PMA_RSV                        (32'h00018480),                         // Optimized for GES Gen1/Gen2
    .PMA_RSV2                       (16'h2070),                             // Optimized for silicon, [4] RX_CM_TRIM[4], [5] = 1 Enable Eye Scan
  //.PMA_RSV3                       ( 2'd0),                                //
  //.PMA_RSV4                       (32'd0),                                // GTX 3.0 new
    .RX_BIAS_CFG                    (12'b000000000100),                     // Optimized for GES
  //.TERM_RCAL_CFG                  ( 5'b10000),                            //
  //.TERM_RCAL_OVRD                 ( 1'd0),                                //

    //---------- CDR Attributes --------------------------------------------
    .RXCDR_CFG                      (RXCDR_CFG_GTX),                        //
    .RXCDR_LOCK_CFG                 ( 6'b010101),                           // [5:3] Window Refresh, [2:1] Window Size, [0] Enable Detection (sensitive lock = 6'b111001)
    .RXCDR_HOLD_DURING_EIDLE        ( 1'd1),                                // Hold  RX CDR           on electrical idle for Gen1/Gen2
    .RXCDR_FR_RESET_ON_EIDLE        ( 1'd0),                                // Reset RX CDR frequency on electrical idle for Gen3
    .RXCDR_PH_RESET_ON_EIDLE        ( 1'd0),                                // Reset RX CDR phase     on electrical idle for Gen3
  //.RXCDRFREQRESET_TIME            ( 5'b00001),                            //
  //.RXCDRPHRESET_TIME              ( 5'b00001),                            //

    //---------- LPM Attributes --------------------------------------------
    .RXLPM_HF_CFG                   (14'h00F0),                             // Optimized for silicon
    .RXLPM_LF_CFG                   (14'h00F0),                             // Optimized for silicon

    //---------- DFE Attributes --------------------------------------------
  //.RXDFELPMRESET_TIME	            ( 7'b0001111),                          //
    .RX_DFE_GAIN_CFG                (23'h020FEA),                           // Optimized for GES, IES = 23'h001F0A
    .RX_DFE_H2_CFG                  (12'b000000000000),                     // Optimized for GES
    .RX_DFE_H3_CFG                  (12'b000001000000),                     // Optimized for GES
    .RX_DFE_H4_CFG                  (11'b00011110000),                      // Optimized for GES
    .RX_DFE_H5_CFG                  (11'b00011100000),                      // Optimized for GES
    .RX_DFE_KL_CFG                  (13'b0000011111110),                    // Optimized for GES
    .RX_DFE_KL_CFG2                 (32'h3290D86C),                         // Optimized for GES, GTX new, CTLE 3 3 5, default = 32'h3010D90C
    .RX_DFE_LPM_CFG                 (16'h0954),                             // Optimized for GES
    .RX_DFE_LPM_HOLD_DURING_EIDLE   ( 1'd1),                                // Optimized for PCIe
    .RX_DFE_UT_CFG                  (17'b10001111000000000),                // Optimized for GES, IES = 17'h08F00
    .RX_DFE_VP_CFG                  (17'b00011111100000011),                // Optimized for GES
    .RX_DFE_XYD_CFG                 (13'h0000),                             // Optimized for 4.0

    //---------- OS Attributes ---------------------------------------------
    .RX_OS_CFG                      (13'b0000010000000),                    // Optimized for GES

    //---------- Eye Scan Attributes ---------------------------------------
  //.ES_CONTROL                     ( 6'd0),                                //
  //.ES_ERRDET_EN                   ("FALSE"),                              //
    .ES_EYE_SCAN_EN                 ("TRUE"),                               //
    .ES_HORZ_OFFSET                 (12'd0),                                //
  //.ES_PMA_CFG                     (10'd0),                                //
  //.ES_PRESCALE                    ( 5'd0),                                //
  //.ES_QUAL_MASK                   (80'd0),                                //
  //.ES_QUALIFIER                   (80'd0),                                //
  //.ES_SDATA_MASK                  (80'd0),                                //
  //.ES_VERT_OFFSET                 ( 9'd0),                                //

    //---------- TX Buffer Attributes --------------------------------------
    .TXBUF_EN                       (PCIE_TXBUF_EN),                        //
    .TXBUF_RESET_ON_RATE_CHANGE	    ("TRUE"),                               //

    //---------- RX Buffer Attributes --------------------------------------
    .RXBUF_EN                       ("TRUE"),                               //
  //.RX_BUFFER_CFG                  ( 6'd0),                                //
    .RX_DEFER_RESET_BUF_EN          ("TRUE"),                               //
    .RXBUF_ADDR_MODE                ("FULL"),                               //
    .RXBUF_EIDLE_HI_CNT	            ( 4'd4),                                // Optimized for sim
    .RXBUF_EIDLE_LO_CNT	            ( 4'd0),                                // Optimized for sim
    .RXBUF_RESET_ON_CB_CHANGE       ("TRUE"),                               //
    .RXBUF_RESET_ON_COMMAALIGN      ("FALSE"),                              //
    .RXBUF_RESET_ON_EIDLE           ("TRUE"),                               // PCIe
    .RXBUF_RESET_ON_RATE_CHANGE	    ("TRUE"),                               //
    .RXBUF_THRESH_OVRD              ("FALSE"),                              //
    .RXBUF_THRESH_OVFLW	            (61),                                   //
    .RXBUF_THRESH_UNDFLW            ( 4),                                   //
  //.RXBUFRESET_TIME                ( 5'b00001),                            //

    //---------- TX Sync Attributes ----------------------------------------
  //.TXPH_CFG                       (16'h0780),                             //
    .TXPH_MONITOR_SEL               ( 5'd0),                                //
  //.TXPHDLY_CFG                    (24'h084020),                           //
  //.TXDLY_CFG                      (16'h001F),                             //
  //.TXDLY_LCFG	                    ( 9'h030),                              //
  //.TXDLY_TAP_CFG                  (16'd0),                                //

    //---------- RX Sync Attributes ----------------------------------------
  //.RXPH_CFG                       (24'd0),                                //
    .RXPH_MONITOR_SEL               ( 5'd0),                                //
    .RXPHDLY_CFG                    (24'h004020),                           // Optimized for sim
  //.RXDLY_CFG                      (16'h001F),                             //
  //.RXDLY_LCFG	                    ( 9'h030),                              //
  //.RXDLY_TAP_CFG                  (16'd0),                                //
    .RX_DDI_SEL	                    ( 6'd0),                                //

    //---------- Comma Alignment Attributes --------------------------------
    .ALIGN_COMMA_DOUBLE             ("FALSE"),                              //
    .ALIGN_COMMA_ENABLE             (10'b1111111111),                       // PCIe
    .ALIGN_COMMA_WORD               ( 1),                                   //
    .ALIGN_MCOMMA_DET               ("TRUE"),                               //
    .ALIGN_MCOMMA_VALUE             (10'b1010000011),                       //
    .ALIGN_PCOMMA_DET               ("TRUE"),                               //
    .ALIGN_PCOMMA_VALUE             (10'b0101111100),                       //
    .DEC_MCOMMA_DETECT              ("TRUE"),                               //
    .DEC_PCOMMA_DETECT              ("TRUE"),                               //
    .DEC_VALID_COMMA_ONLY           ("FALSE"),                              // PCIe
    .SHOW_REALIGN_COMMA             ("FALSE"),                              // PCIe
    .RXSLIDE_AUTO_WAIT              ( 7),                                   //
    .RXSLIDE_MODE                   ("PMA"),                                // PCIe

    //---------- Channel Bonding Attributes --------------------------------
    .CHAN_BOND_KEEP_ALIGN           ("TRUE"),                               // PCIe
    .CHAN_BOND_MAX_SKEW             ( 7),                                   //
    .CHAN_BOND_SEQ_LEN              ( 4),                                   // PCIe
    .CHAN_BOND_SEQ_1_ENABLE         ( 4'b1111),                             //
    .CHAN_BOND_SEQ_1_1              (10'b0001001010),                       // D10.2 (4A) - TS1
    .CHAN_BOND_SEQ_1_2              (10'b0001001010),                       // D10.2 (4A) - TS1
    .CHAN_BOND_SEQ_1_3              (10'b0001001010),                       // D10.2 (4A) - TS1
    .CHAN_BOND_SEQ_1_4              (10'b0110111100),                       // K28.5 (BC) - COM
    .CHAN_BOND_SEQ_2_USE            ("TRUE"),                               // PCIe
    .CHAN_BOND_SEQ_2_ENABLE         ( 4'b1111),                             //
    .CHAN_BOND_SEQ_2_1              (10'b0001000101),                       // D5.2  (45) - TS2
    .CHAN_BOND_SEQ_2_2              (10'b0001000101),                       // D5.2  (45) - TS2
    .CHAN_BOND_SEQ_2_3              (10'b0001000101),                       // D5.2  (45) - TS2
    .CHAN_BOND_SEQ_2_4              (10'b0110111100),                       // K28.5 (BC) - COM
    .FTS_DESKEW_SEQ_ENABLE          ( 4'b1111),                             //
    .FTS_LANE_DESKEW_EN	            ("TRUE"),                               // PCIe
    .FTS_LANE_DESKEW_CFG            ( 4'b1111),                             //

    //---------- Clock Correction Attributes -------------------------------
    .CBCC_DATA_SOURCE_SEL           ("DECODED"),                            //
    .CLK_CORRECT_USE                ("TRUE"),                               //
    .CLK_COR_KEEP_IDLE              ("TRUE"),                               // PCIe
    .CLK_COR_MAX_LAT                (CLK_COR_MAX_LAT),                      //
    .CLK_COR_MIN_LAT                (CLK_COR_MIN_LAT),                      //
    .CLK_COR_PRECEDENCE             ("TRUE"),                               //
    .CLK_COR_REPEAT_WAIT            ( 0),                                   //
    .CLK_COR_SEQ_LEN                ( 1),                                   //
    .CLK_COR_SEQ_1_ENABLE           ( 4'b1111),                             //
    .CLK_COR_SEQ_1_1                (10'b0100011100),                       // K28.0 (1C) - SKP
    .CLK_COR_SEQ_1_2                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_1_3                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_1_4                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_2_ENABLE           ( 4'b0000),                             // Disabled
    .CLK_COR_SEQ_2_USE              ("FALSE"),                              //
    .CLK_COR_SEQ_2_1                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_2_2                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_2_3                (10'b0000000000),                       // Disabled
    .CLK_COR_SEQ_2_4                (10'b0000000000),                       // Disabled

    //---------- 8b10b Attributes ------------------------------------------
    .RX_DISPERR_SEQ_MATCH           ("TRUE"),                               //

    //---------- 64b/66b & 64b/67b Attributes ------------------------------
    .GEARBOX_MODE                   (3'd0),                                 //
    .TXGEARBOX_EN                   ("FALSE"),                              //
    .RXGEARBOX_EN                   ("FALSE"),                              //

    //---------- PRBS & Loopback Attributes --------------------------------
    .RXPRBS_ERR_LOOPBACK            (1'd0),                                 //
    .TX_LOOPBACK_DRIVE_HIZ          ("FALSE"),                              //

    //---------- OOB & SATA Attributes -------------------------------------
  //.RXOOB_CFG                      ( 7'b0000110),                          //
  //.SAS_MAX_COM                    (64),                                   //
  //.SAS_MIN_COM                    (36),                                   //
  //.SATA_BURST_SEQ_LEN             ( 4'b1111),                             //
  //.SATA_BURST_VAL                 ( 3'b100),                              //
  //.SATA_CPLL_CFG                  ("VCO_3000MHZ"),                        //
  //.SATA_EIDLE_VAL                 ( 3'b100),                              //
  //.SATA_MAX_BURST                 ( 8),                                   //
  //.SATA_MAX_INIT                  (21),                                   //
  //.SATA_MAX_WAKE                  ( 7),                                   //
  //.SATA_MIN_BURST                 ( 4),                                   //
  //.SATA_MIN_INIT                  (12),                                   //
  //.SATA_MIN_WAKE                  ( 4),                                   //

    //---------- MISC ------------------------------------------------------
    .DMONITOR_CFG                   (24'h000B01),                           // Optimized for debug
    .RX_DEBUG_CFG                   (12'd0)                                 // Optimized for GES
  //.TST_RSV                        (32'd0),                                //
  //.UCODEER_CLR                    ( 1'd0)                                 //

)
gtxe2_channel_i
(

    //---------- Clock -----------------------------------------------------
    .GTGREFCLK                      (1'd0),                                 //
    .GTREFCLK0                      (GT_GTREFCLK0),                         //
    .GTREFCLK1                      (1'd0),                                 //
    .GTNORTHREFCLK0                 (1'd0),                                 //
    .GTNORTHREFCLK1                 (1'd0),                                 //
    .GTSOUTHREFCLK0                 (1'd0),                                 //
    .GTSOUTHREFCLK1                 (1'd0),                                 //
    .QPLLCLK                        (GT_QPLLCLK),                           //
    .QPLLREFCLK                     (GT_QPLLREFCLK),                        //
    .TXUSRCLK                       (GT_TXUSRCLK),                          //
    .RXUSRCLK                       (GT_RXUSRCLK),                          //
    .TXUSRCLK2                      (GT_TXUSRCLK2),                         //
    .RXUSRCLK2                      (GT_RXUSRCLK2),                         //
    .TXSYSCLKSEL                    (GT_TXSYSCLKSEL),                       //
    .RXSYSCLKSEL                    (GT_RXSYSCLKSEL),                       //
    .TXOUTCLKSEL                    (txoutclksel),                          //
    .RXOUTCLKSEL                    (rxoutclksel),                          //
    .CPLLREFCLKSEL                  (3'd1),                                 //
    .CPLLLOCKDETCLK                 (1'd0),                                 //
    .CPLLLOCKEN                     (1'd1),                                 //
    .CLKRSVD                        ({2'd0, dmonitorclk, GT_OOBCLK}),       // Optimized for debug

    .TXOUTCLK                       (GT_TXOUTCLK),                          //
    .RXOUTCLK                       (GT_RXOUTCLK),                          //
    .TXOUTCLKFABRIC                 (),                                     //
    .RXOUTCLKFABRIC                 (),                                     //
    .TXOUTCLKPCS                    (),                                     //
    .RXOUTCLKPCS                    (),                                     //
    .CPLLLOCK                       (GT_CPLLLOCK),                          //
    .CPLLREFCLKLOST                 (),                                     //
    .CPLLFBCLKLOST                  (),                                     //
    .RXCDRLOCK                      (GT_RXCDRLOCK),                         //
    .GTREFCLKMONITOR                (),                                     //

    //---------- Reset -----------------------------------------------------
    .CPLLPD                         (GT_CPLLPD),                            //
    .CPLLRESET                      (GT_CPLLRESET),                         //
    .TXUSERRDY                      (GT_TXUSERRDY),                         //
    .RXUSERRDY                      (GT_RXUSERRDY),                         //
    .CFGRESET                       (1'd0),                                 //
    .GTRESETSEL                     (1'd0),                                 //
    .RESETOVRD                      (GT_RESETOVRD),                         //
    .GTTXRESET                      (GT_GTTXRESET),                         //
    .GTRXRESET                      (GT_GTRXRESET),                         //

    .TXRESETDONE                    (GT_TXRESETDONE),                       //
    .RXRESETDONE                    (GT_RXRESETDONE),                       //

    //---------- TX Data ---------------------------------------------------
    .TXDATA                         ({32'd0, GT_TXDATA}),                   //
    .TXCHARISK                      ({ 4'd0, GT_TXDATAK}),                  //

    .GTXTXP                         (GT_TXP),                               // GTX
    .GTXTXN                         (GT_TXN),                               // GTX

    //---------- RX Data ---------------------------------------------------
    .GTXRXP                         (GT_RXP),                               // GTX
    .GTXRXN                         (GT_RXN),                               // GTX

    .RXDATA                         (rxdata),                               //
    .RXCHARISK                      (rxdatak),                              //

    //---------- Command ---------------------------------------------------
    .TXDETECTRX                     (GT_TXDETECTRX),                        //
    .TXPDELECIDLEMODE               ( 1'd0),                                //
    .RXELECIDLEMODE                 ( 2'd0),                                //
    .TXELECIDLE                     (GT_TXELECIDLE),                        //
    .TXCHARDISPMODE                 ({7'd0, GT_TXCOMPLIANCE}),              //
    .TXCHARDISPVAL                  ( 8'd0),                                //
    .TXPOLARITY                     ( 1'd0),                                //
    .RXPOLARITY                     (GT_RXPOLARITY),                        //
    .TXPD                           (GT_TXPOWERDOWN),                       //
    .RXPD                           (GT_RXPOWERDOWN),                       //
    .TXRATE                         (GT_TXRATE),                            //
    .RXRATE                         (GT_RXRATE),                            //

    //---------- Electrical Command ----------------------------------------
    .TXMARGIN                       (GT_TXMARGIN),                          //
    .TXSWING                        (GT_TXSWING),                           //
    .TXDEEMPH                       (GT_TXDEEMPH),                          //
    .TXINHIBIT                      (1'd0),                                 //
    .TXBUFDIFFCTRL                  (3'b100),                               //
    //.TXDIFFCTRL                     (4'b1100),                              //
    .TXDIFFCTRL                     (i_tx_diff_ctr),                        //
    .TXPRECURSOR                    (GT_TXPRECURSOR),                       //
    //.TXPRECURSOR                    (i_tx_precursor),                       //
    .TXPRECURSORINV                 (1'd0),                                 //
    .TXMAINCURSOR                   (GT_TXMAINCURSOR),                      //
    .TXPOSTCURSOR                   (GT_TXPOSTCURSOR),                      //
    //.TXPOSTCURSOR                   (i_tx_postcursor),                      //
    .TXPOSTCURSORINV                (1'd0),                                 //

    //---------- Status ----------------------------------------------------
    .RXVALID                        (GT_RXVALID),                           //
    .PHYSTATUS                      (GT_PHYSTATUS),                         //
    .RXELECIDLE                     (GT_RXELECIDLE),                        //
    .RXSTATUS                       (GT_RXSTATUS),                          //
    .TXRATEDONE                     (GT_TXRATEDONE),                        //
    .RXRATEDONE                     (GT_RXRATEDONE),                        //

    //---------- DRP -------------------------------------------------------
    .DRPCLK                         (GT_DRPCLK),                            //
    .DRPADDR                        (GT_DRPADDR),                           //
    .DRPEN                          (GT_DRPEN),                             //
    .DRPDI                          (GT_DRPDI),                             //
    .DRPWE                          (GT_DRPWE),                             //

    .DRPDO                          (GT_DRPDO),                             //
    .DRPRDY                         (GT_DRPRDY),                            //

    //---------- PMA -------------------------------------------------------
    .TXPMARESET                     (GT_TXPMARESET),                        //
    .RXPMARESET                     (GT_RXPMARESET),                        //
    .RXLPMEN                        (rxlpmen),                              //
    .RXLPMHFHOLD                    ( 1'd0),                                //
    .RXLPMHFOVRDEN                  ( 1'd0),                                //
    .RXLPMLFHOLD                    ( 1'd0),                                //
    .RXLPMLFKLOVRDEN                ( 1'd0),                                //
    .TXQPIBIASEN                    ( 1'd0),                                //
    .TXQPISTRONGPDOWN               ( 1'd0),                                //
    .TXQPIWEAKPUP                   ( 1'd0),                                //
    .RXQPIEN                        ( 1'd0),                                //
    .PMARSVDIN                      ( 5'd0),                                //
    .PMARSVDIN2                     ( 5'd0),                                // GTX
    .GTRSVD                         (16'd0),                                //

    .TXQPISENP                      (),                                     //
    .TXQPISENN                      (),                                     //
    .RXQPISENP                      (),                                     //
    .RXQPISENN                      (),                                     //
    .DMONITOROUT                    (dmonitorout[7:0]),                     // GTX 8-bits

    //---------- PCS -------------------------------------------------------
    .TXPCSRESET                     (GT_TXPCSRESET),                        //
    .RXPCSRESET                     (GT_RXPCSRESET),                        //
    .PCSRSVDIN                      (16'd0),                                // [0]: 1 = TXRATE async, [1]: 1 = RXRATE async
    .PCSRSVDIN2                     ( 5'd0),                                //

    .PCSRSVDOUT                     (),                                     //
    //---------- CDR -------------------------------------------------------
    .RXCDRRESET                     (GT_RXCDRRESET),                        //
    .RXCDRRESETRSV                  (1'd0),                                 //
    .RXCDRFREQRESET                 (GT_RXCDRFREQRESET),                    //
    .RXCDRHOLD                      (1'd0),                                 //
    .RXCDROVRDEN                    (1'd0),                                 //

    //---------- DFE -------------------------------------------------------
    .RXDFELPMRESET                  (GT_RXDFELPMRESET),                     //
    .RXDFECM1EN                     (1'd0),                                 //
    .RXDFEVSEN                      (1'd0),                                 //
    .RXDFETAP2HOLD                  (1'd0),                                 //
    .RXDFETAP2OVRDEN                (1'd0),                                 //
    .RXDFETAP3HOLD                  (1'd0),                                 //
    .RXDFETAP3OVRDEN                (1'd0),                                 //
    .RXDFETAP4HOLD                  (1'd0),                                 //
    .RXDFETAP4OVRDEN                (1'd0),                                 //
    .RXDFETAP5HOLD                  (1'd0),                                 //
    .RXDFETAP5OVRDEN                (1'd0),                                 //
    .RXDFEAGCHOLD                   (GT_RX_CONVERGE),                       // Optimized for GES, Set to 1 after convergence
    .RXDFEAGCOVRDEN                 (1'd0),                                 //
    .RXDFELFHOLD                    (1'd0),                                 //
    .RXDFELFOVRDEN                  (1'd1),                                 // Optimized for GES
    .RXDFEUTHOLD                    (1'd0),                                 //
    .RXDFEUTOVRDEN                  (1'd0),                                 //
    .RXDFEVPHOLD                    (1'd0),                                 //
    .RXDFEVPOVRDEN                  (1'd0),                                 //
    .RXDFEXYDEN                     (1'd0),                                 //
    .RXDFEXYDHOLD                   (1'd0),                                 // GTX
    .RXDFEXYDOVRDEN                 (1'd0),                                 // GTX
    .RXMONITORSEL                   (2'd0),                                 //

    .RXMONITOROUT                   (),                                     //

    //---------- OS --------------------------------------------------------
    .RXOSHOLD                       (1'd0),                                 //
    .RXOSOVRDEN                     (1'd0),                                 //

    //---------- Eye Scan --------------------------------------------------
    .EYESCANRESET                   (GT_EYESCANRESET),                      //
    .EYESCANMODE                    (1'd0),                                 //
    .EYESCANTRIGGER                 (1'd0),                                 //

    .EYESCANDATAERROR               (),                                     //

    //---------- TX Buffer -------------------------------------------------
    .TXBUFSTATUS                    (),                                     //

    //---------- RX Buffer -------------------------------------------------
    .RXBUFRESET                     (GT_RXBUFRESET),                        //

    .RXBUFSTATUS                    (GT_RXBUFSTATUS),                       //

    //---------- TX Sync ---------------------------------------------------
    .TXPHDLYRESET                   (1'd0),                                 //
    .TXPHDLYTSTCLK                  (1'd0),                                 //
    .TXPHALIGN                      (GT_TXPHALIGN),                         //
    .TXPHALIGNEN                    (GT_TXPHALIGNEN),                       //
    .TXPHDLYPD                      (1'd0),                                 //
    .TXPHINIT                       (GT_TXPHINIT),                          //
    .TXPHOVRDEN                     (1'd0),                                 //
    .TXDLYBYPASS                    (GT_TXDLYBYPASS),                       //
    .TXDLYSRESET                    (GT_TXDLYSRESET),                       //
    .TXDLYEN                        (GT_TXDLYEN),                           //
    .TXDLYOVRDEN                    (1'd0),                                 //
    .TXDLYHOLD                      (1'd0),                                 //
    .TXDLYUPDOWN                    (1'd0),                                 //

    .TXPHALIGNDONE                  (GT_TXPHALIGNDONE),                     //
    .TXPHINITDONE                   (GT_TXPHINITDONE),                      //
    .TXDLYSRESETDONE                (GT_TXDLYSRESETDONE),                   //

    //---------- RX Sync ---------------------------------------------------
    .RXPHDLYRESET                   (1'd0),                                 //
    .RXPHALIGN                      (GT_RXPHALIGN),                         //
    .RXPHALIGNEN                    (GT_RXPHALIGNEN),                       //
    .RXPHDLYPD                      (1'd0),                                 //
    .RXPHOVRDEN                     (1'd0),                                 //
    .RXDLYBYPASS                    (GT_RXDLYBYPASS),                       //
    .RXDLYSRESET                    (GT_RXDLYSRESET),                       //
    .RXDLYEN                        (GT_RXDLYEN),                           //
    .RXDLYOVRDEN                    (1'd0),                                 //
    .RXDDIEN                        (GT_RXDDIEN),                           //

    .RXPHALIGNDONE                  (GT_RXPHALIGNDONE),                     //
    .RXPHMONITOR                    (),                                     //
    .RXPHSLIPMONITOR                (),                                     //
    .RXDLYSRESETDONE                (GT_RXDLYSRESETDONE),                   //

    //---------- Comma Alignment -------------------------------------------
    .RXCOMMADETEN                   ( 1'd1),                                //
    .RXMCOMMAALIGNEN                (!GT_GEN3),                             // 0 = disable comma alignment in Gen3
    .RXPCOMMAALIGNEN                (!GT_GEN3),                             // 0 = disable comma alignment in Gen3
    .RXSLIDE                        ( GT_RXSLIDE),                          //

    .RXCOMMADET                     (GT_RXCOMMADET),                        //
    .RXCHARISCOMMA                  (rxchariscomma),                        //
    .RXBYTEISALIGNED                (GT_RXBYTEISALIGNED),                   //
    .RXBYTEREALIGN                  (GT_RXBYTEREALIGN),                     //

    //---------- Channel Bonding -------------------------------------------
    .RXCHBONDEN                     (GT_RXCHBONDEN),                        //
    .RXCHBONDI                      (GT_RXCHBONDI),                         //
    .RXCHBONDLEVEL                  (GT_RXCHBONDLEVEL),                     //
    .RXCHBONDMASTER                 (GT_RXCHBONDMASTER),                    //
    .RXCHBONDSLAVE                  (GT_RXCHBONDSLAVE),                     //

    .RXCHANBONDSEQ                  (),                                     //
    .RXCHANISALIGNED                (GT_RXCHANISALIGNED),                   //
    .RXCHANREALIGN                  (),                                     //
    .RXCHBONDO                      (GT_RXCHBONDO),                         //

    //---------- Clock Correction  -----------------------------------------
    .RXCLKCORCNT                    (),                                     //

    //---------- 8b10b -----------------------------------------------------
    .TX8B10BBYPASS                  (8'd0),                                 //
    .TX8B10BEN                      (!GT_GEN3),                             // 0 = disable TX 8b10b in Gen3
    .RX8B10BEN                      (!GT_GEN3),                             // 0 = disable RX 8b10b in Gen3

    .RXDISPERR                      (),                                     //
    .RXNOTINTABLE                   (),                                     //

    //---------- 64b/66b & 64b/67b -----------------------------------------
    .TXHEADER                       (3'd0),                                 //
    .TXSEQUENCE                     (7'd0),                                 //
    .TXSTARTSEQ                     (1'd0),                                 //
    .RXGEARBOXSLIP                  (1'd0),                                 //

    .TXGEARBOXREADY                 (),                                     //
    .RXDATAVALID                    (),                                     //
    .RXHEADER                       (),                                     //
    .RXHEADERVALID                  (),                                     //
    .RXSTARTOFSEQ                   (),                                     //

    //---------- PRBS/Loopback ---------------------------------------------
    .TXPRBSSEL                      (GT_TXPRBSSEL),                         //
    .RXPRBSSEL                      (GT_RXPRBSSEL),                         //
    .TXPRBSFORCEERR                 (GT_TXPRBSFORCEERR),                    //
    .RXPRBSCNTRESET                 (GT_RXPRBSCNTRESET),                    //
    .LOOPBACK                       (GT_LOOPBACK),                          //

    .RXPRBSERR                      (GT_RXPRBSERR),                         //

    //---------- OOB -------------------------------------------------------
    .TXCOMINIT                      (1'd0),                                 //
    .TXCOMSAS                       (1'd0),                                 //
    .TXCOMWAKE                      (1'd0),                                 //
    .RXOOBRESET                     (1'd0),                                 //

    .TXCOMFINISH                    (),                                     //
    .RXCOMINITDET                   (),                                     //
    .RXCOMSASDET                    (),                                     //
    .RXCOMWAKEDET                   (),                                     //

    //---------- MISC ------------------------------------------------------
    .SETERRSTATUS                   ( 1'd0),                                //
    .TXDIFFPD                       ( 1'd0),                                //
    .TXPISOPD                       ( 1'd0),                                //
    .TSTIN                          (20'hFFFFF),                            //

    .TSTOUT                         ()                                      // GTX

);

//---------- Default -------------------------------------------------------
assign dmonitorout[14:8] = 7'd0;                                            // GTH GTP
assign GT_TXSYNCOUT      = 1'd0;                                            // GTH GTP
assign GT_TXSYNCDONE     = 1'd0;                                            // GTH GTP
assign GT_RXSYNCOUT      = 1'd0;                                            // GTH GTP
assign GT_RXSYNCDONE     = 1'd0;                                            // GTH GTP
assign GT_RXPMARESETDONE = 1'd0;                                            // GTH GTP



//---------- GT Wrapper Outputs ------------------------------------------------
assign GT_RXDATA        = rxdata [31:0];
assign GT_RXDATAK       = rxdatak[ 3:0];
assign GT_RXCHARISCOMMA = rxchariscomma[ 3:0];
assign GT_DMONITOROUT   = dmonitorout;



endmodule
