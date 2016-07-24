module tx1_ddr3 (

  // Inouts
  inout    [7:0]                               ddr3_dq,
  inout    [0:0]                               ddr3_dqs_n,
  inout    [0:0]                               ddr3_dqs_p,

  // Outputs
  output    [13:0]                             ddr3_addr,
  output    [2:0]                              ddr3_ba,
  output                                       ddr3_ras_n,
  output                                       ddr3_cas_n,
  output                                       ddr3_we_n,
  output                                       ddr3_reset_n,
  output    [0:0]                              ddr3_ck_p,
  output    [0:0]                              ddr3_ck_n,
  output    [0:0]                              ddr3_cke,
  output    [0:0]                              ddr3_cs_n,
  output    [0:0]                              ddr3_dm,
  output    [0:0]                              ddr3_odt,

  //Clock Interface
  // Single-ended system clock
  input                                        sys_clk_i,
  input                                        clk_ref_i,

  //ZQ Controller (Not Used)
  input                                        app_zq_req,  //Set to 0
  output                                       app_zq_ack,

  // user interface signals
  input    [27:0]                              app_addr,
  input    [2:0]                               app_cmd,
  input                                        app_en,
  output                                       app_rdy,

  input    [31:0]                              app_wdf_data,
  input                                        app_wdf_end,
  input    [3:0]                               app_wdf_mask,
  input                                        app_wdf_wren,
  output                                       app_wdf_rdy,

  output   [31:0]                              app_rd_data,
  output                                       app_rd_data_end,
  output                                       app_rd_data_valid,

  input                                        app_sr_req,
  output                                       app_sr_active,
  input                                        app_ref_req,
  output                                       app_ref_ack,

  output                                       ui_clk,
  output                                       ui_clk_sync_rst,

  output                                       init_calib_complete,

  input                                        sys_rst
);


endmodule
