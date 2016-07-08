///////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995/2010 Xilinx, Inc.
// All Right Reserved.
///////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor : Xilinx
// \   \   \/     Version : 10.1
//  \   \         Description : Xilinx Functional Simulation Library Component
//  /   /                  Differential Signaling Input Buffer
// /___/   /\     Filename : IBUFDS_GTE2.v
// \   \  /  \    Timestamp : Tue Jun  1 14:31:01 PDT 2010
//  \___\/\___\
//
// Revision:
//    06/01/10 - Initial version.
//    09/12/11 - 624988 -- Changed CLKSWING_CFG from blooean to bits
// End Revision

`timescale  1 ps / 1 ps

module IBUFDS_GTE2 (
  output O,
  output ODIV2,

  input CEB,
  input I,
  input IB
);
endmodule
