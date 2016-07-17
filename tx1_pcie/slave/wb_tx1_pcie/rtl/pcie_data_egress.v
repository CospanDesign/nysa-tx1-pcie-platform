module pcie_data_egress (
  input           ACLK,
  input           ARESETN,

  input           S00_AXIS_ACLK,
  input           S00_AXIS_ARESETN,
  input           S00_AXIS_TVALID,
  output          S00_AXIS_TREADY,
  input   [31:0]  S00_AXIS_TDATA,
  input   [3:0]   S00_AXIS_TKEEP,
  input           S00_AXIS_TLAST,
//  output  [31:0]  S00_FIFO_DATA_COUNT,

  input           M00_AXIS_ACLK,
  input           M00_AXIS_ARESETN,
  output          M00_AXIS_TVALID,
  input           M00_AXIS_TREADY,
  output  [63:0]  M00_AXIS_TDATA,
  output  [7:0]   M00_AXIS_TKEEP,
  output          M00_AXIS_TLAST
);

endmodule
