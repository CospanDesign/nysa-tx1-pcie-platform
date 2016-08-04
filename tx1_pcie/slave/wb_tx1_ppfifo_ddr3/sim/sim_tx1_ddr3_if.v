/*
Distributed under the MIT license.
Copyright (c) 2015 Dave McCoy (dave.mccoy@cospandesign.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/


module sim_tx1_ddr3_if #(
  parameter          MEM_ADDR_DEPTH  = 28
)(
  input                                         sys_clk_i,
  input                                         sys_rst,

  output  reg                                   init_calib_complete,

  output  reg                                   ui_clk,
  output  reg                                   ui_clk_sync_rst = 0,


  // Inouts
  inout [7:0]                                  ddr3_dq,
  inout                                        ddr3_dqs_n,
  inout                                        ddr3_dqs_p,

  // Outputs
  output [13:0]                                ddr3_addr,
  output [2:0]                                 ddr3_ba,
  output                                       ddr3_ras_n,
  output                                       ddr3_cas_n,
  output                                       ddr3_we_n,
  output                                       ddr3_reset_n,
  output                                       ddr3_ck_p,
  output                                       ddr3_ck_n,
  output                                       ddr3_cke,
  output                                       ddr3_cs_n,
  output                                       ddr3_dm,
  output                                       ddr3_odt,


  // user interface signals
  input   [MEM_ADDR_DEPTH-1:0]                 app_addr,
  input   [2:0]                                app_cmd,
  input                                        app_en,
  input   [31:0]                               app_wdf_data,
  input                                        app_wdf_end,
  input   [3:0]                                app_wdf_mask,
  input                                        app_wdf_wren,
  output  reg [31:0]                           app_rd_data,
  output  reg                                  app_rd_data_end,
  output  reg                                  app_rd_data_valid,
  output  reg                                  app_rdy,
  output  reg                                  app_wdf_rdy,
  input                                        app_sr_req,
  output                                       app_sr_active,
  input                                        app_ref_req,
  output                                       app_ref_ack,
  input                                        app_zq_req,
  output                                       app_zq_ack,

  output                                       pll_locked
);

//Local Parameters
localparam            CMD_WRITE     = 3'b000;
localparam            CMD_READ      = 3'b001;
localparam            WR_FIFO_SIZE  = 2;
localparam            CMD_FIFO_SIZE = 4;
localparam            RD_FIFO_SIZE  = 16;

//Registers/Wires


wire                w_cmd_empty;
wire                w_cmd_full;
wire                w_wr_full;
wire                w_wr_empty;

reg [6:0]           r_wr_count;
reg                 r_wr_underrun;
reg                 r_wr_error;
wire                w_rd_en;
wire                w_rd_full;
wire                w_rd_empty;
reg                 r_rd_overflow;
reg                 r_rd_error;


reg           [23:0]  write_data_count = 0;
reg           [23:0]  write_data_size  = 0;
reg           [23:0]  cmd_count;
reg           [23:0]  read_data_count;
reg           [23:0]  read_data_size;

reg           [23:0]  write_timeout       =  WFIFO_READ_DELAY;
reg           [23:0]  cmd_timeout;
reg           [23:0]  read_timeout;
reg                   p3_cmd_error;


wire          [5:0]   w_block_length;

reg           [31:0]  init_count;
reg           [31:0]  ui_reset_count;
reg           [31:0]  rst_count       = 0;

wire                  sim_ui_clk;

reg                   lcl_rst;
reg                   read_req;
reg                   write_req;
reg                   r_prev_wdf_rdy;


assign pll_locked           = 1;
//Submodules


//Asynchronous Logic

assign w_wr_full      = ((write_data_size - write_data_count) == WR_FIFO_SIZE);
assign w_wr_empty     = ((write_data_size - write_data_count) == 0);

assign w_cmd_full     = (cmd_count == CMD_FIFO_SIZE);
assign w_cmd_empty    = (cmd_count == 0);

assign w_rd_full      = ((read_data_size - read_data_count) == RD_FIFO_SIZE);
assign w_rd_empty     = ((read_data_size - read_data_count) == 0);

assign w_block_length = 2;


assign app_sr_active  = 0;
assign app_ref_ack    = 0;

always @ (*)  ui_clk  = sim_ui_clk;

//Synchronous Logic
parameter CFIFO_READ_DELAY = 20;
parameter WFIFO_READ_DELAY = 20;
parameter RFIFO_WRITE_DELAY = 10;

localparam  RST_COUNT           = 10;
localparam  INIT_CALIB_TIMEOUT  = 50;
localparam  RESET_TIMEOUT       = 100;

always @ (posedge ui_clk) begin
  lcl_rst                   <=  0;
  if (rst_count < RST_COUNT) begin
    rst_count               <=  rst_count + 1;
    lcl_rst                 <=  1;
  end
end


always @ (posedge ui_clk) begin
  ui_clk_sync_rst           <=  0;
  if (lcl_rst) begin
    init_calib_complete     <=  0;
    init_count              <=  0;

    ui_reset_count          <=  0;
  end
  else begin
    if (init_count < INIT_CALIB_TIMEOUT) begin
      init_count            <=  init_count + 1;
    end
    else begin
      init_calib_complete   <=  1;
    end

    if (ui_reset_count < RESET_TIMEOUT) begin
      ui_reset_count        <=  ui_reset_count + 1;
      ui_clk_sync_rst       <=  1;
    end
  end
end




always @ (posedge ui_clk) begin
  app_rd_data_end       <=  0;
  app_rd_data_valid     <=  0;
  app_rdy               <=  0;
  app_wdf_rdy           <=  0;
  read_req              <=  0;
  write_req             <=  0;

  if (ui_clk_sync_rst) begin
    r_wr_count          <=  0;
    r_wr_underrun       <=  0;
    r_wr_error          <=  0;

    app_rd_data         <=  0;
    r_rd_overflow       <=  0;
    r_rd_error          <=  0;

    p3_cmd_error        <=  0;

    cmd_count           <=  0;
    read_data_count     <=  0;
    read_data_size      <=  0;
    write_data_count    <=  0;

    read_timeout        <=  RFIFO_WRITE_DELAY;
    write_timeout       <=  WFIFO_READ_DELAY;
    cmd_timeout         <=  CFIFO_READ_DELAY;

  end
  else begin
    //Command Stuff
    if (!w_cmd_full) begin
      app_rdy           <=  1;
    end

    if (app_en && !w_cmd_full) begin
      if (app_cmd == CMD_WRITE) begin
        /*
        if (write_data_count  <  w_block_length) begin
          r_wr_underrun  <=  1;
        end
        */
      end
      cmd_count       <=  cmd_count + 1;
      if (cmd_timeout == CFIFO_READ_DELAY) begin
        cmd_timeout   <=  0;
      end
    end



    if (app_en && app_rdy && !w_cmd_full && (app_cmd == CMD_WRITE)) begin
      write_data_size   <=  write_data_size + 2;
    end
    if (app_en && app_rdy && (app_cmd == CMD_READ)) begin
      read_data_size    <=  read_data_size + 2;
    end

    if (cmd_count > 0) begin
      if (cmd_timeout < CFIFO_READ_DELAY) begin
        cmd_timeout       <=  cmd_timeout + 1;
      end
      else begin
        cmd_timeout       <=  0;
        cmd_count         <=  cmd_count - 1;
      end
    end


    //Write Stuff
    if (write_timeout < WFIFO_READ_DELAY) begin
      write_timeout     <= write_timeout + 1;
    end
    else begin
      write_timeout     <=  0;
      write_data_count  <= write_data_count + 1;
    end


    if (!w_wr_full) begin
      app_wdf_rdy       <=  1;
    end



    //Read Stuff
    if (read_timeout < RFIFO_WRITE_DELAY) begin
      read_timeout  <=  read_timeout + 1;
    end
    else begin
      if (!w_rd_empty) begin
        read_data_count <= read_data_count + 1;
        app_rd_data_valid <=  1;
        if (read_data_count[0]) begin
            app_rd_data_end <=  1;
        end
      end
      else begin
        read_timeout  <=  0;
      end
    end
    if (app_rd_data_valid) begin
        app_rd_data     <= app_rd_data + 1;
    end

    //Error Condition

  end
end

endmodule
