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
//  output  reg [31:0]                           app_rd_data,
  output      [31:0]                           app_rd_data,
  output  reg                                  app_rd_data_end,
  output  reg                                  app_rd_data_valid,
  output                                       app_rdy,
  output                                       app_wdf_rdy,
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


wire                  w_cmd_empty;
wire                  w_cmd_full;
wire                  w_wr_full;
wire                  w_wr_empty;

reg           [6:0]   r_wr_count;
reg                   r_wr_underrun;
reg                   r_wr_error;
wire                  w_rd_en;
wire                  w_rd_full;
wire                  w_rd_empty;
reg                   r_rd_overflow;
reg                   r_rd_error;


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
reg                   r_mem_stb;


assign pll_locked           = 1;

localparam                        IDLE          = 4'h0;
localparam                        WRITE_PREPARE = 4'h1;
localparam                        WRITE_BOT     = 4'h2;
localparam                        WRITE_TOP     = 4'h3;
localparam                        WRITE_FIN     = 4'h4;
localparam                        READ_PREPARE  = 4'h5;
localparam                        READ_BOT      = 4'h6;
localparam                        READ_TOP      = 4'h7;


reg     [3:0]                     state;

reg                               r_cmd_stb;
reg                               r_write_fifo_stb;
reg   [MEM_ADDR_DEPTH - 2: 0]     r_fifo_app_addr;

//Submodules

wire  [MEM_ADDR_DEPTH - 3: 0]     w_fifo_app_addr;
wire                              w_fifo_app_cmd;
wire                              w_fifo_app_read_en;
wire   [31:0]                     w_fifo_app_cmd_dout;
wire                              w_fifo_app_empty;
wire                              w_fifo_app_full;

localparam                        CMD_DEPTH = 4;
localparam                        WRITE_DEPTH = CMD_DEPTH + 2;

sync_fifo #(
  .DATA_WIDTH                     (32),
  .MEM_DEPTH                      (CMD_DEPTH)
) addr_fifo (
  .in_clk                         (ui_clk),
  .out_clk                        (ui_clk),
  .rst                            (lcl_rst),

  .empty                          (w_fifo_app_empty),
  .full                           (w_fifo_app_full),

  .i_in_data                      ({2'h0, app_addr[(MEM_ADDR_DEPTH - 1) : 2], 1'b0,  app_cmd}),
  .i_in_stb                       (app_en & app_rdy),

  .i_out_stb                      (r_cmd_stb),
  .o_out_data                     (w_fifo_app_cmd_dout)

);
assign  w_fifo_app_addr           = w_fifo_app_cmd_dout[28:4];
assign  w_fifo_app_cmd            = w_fifo_app_cmd_dout[0];
assign  app_rdy                   = !w_fifo_app_full;

wire  [31:0]                      ddr3_write_data;
wire                              w_fifo_write_full;

sync_fifo #(
  .DATA_WIDTH                     (32),
  .MEM_DEPTH                      (WRITE_DEPTH)
) write_fifo (
  .in_clk                         (ui_clk),
  .out_clk                        (ui_clk),
  .rst                            (lcl_rst),

  .full                           (w_fifo_write_full),
  .empty                          (),

  .i_in_data                      (app_wdf_data),
  .i_in_stb                       (app_wdf_wren & app_wdf_rdy),

  .i_out_stb                      (r_write_fifo_stb),
  .o_out_data                     (ddr3_write_data)

);

localparam  MEM_DEPTH = 16;
wire  [MEM_DEPTH - 1: 0]        w_ddr3_addr;

assign  w_ddr3_addr             = r_fifo_app_addr[(MEM_DEPTH - 1):0];
assign  app_wdf_rdy             = !w_fifo_write_full;

blk_mem #
(
  .DATA_WIDTH                    (32),
  .ADDRESS_WIDTH                 (MEM_DEPTH)
)
u_ddr3 (
    .clka                        (ui_clk),
    .addra                       (w_ddr3_addr),
    .dina                        (ddr3_write_data),
    .wea                         (r_write_fifo_stb),

    .clkb                        (ui_clk),
    .addrb                       (w_ddr3_addr),
    .doutb                       (app_rd_data)
);


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
parameter CFIFO_READ_DELAY      = 20;
parameter WFIFO_READ_DELAY      = 20;
parameter RFIFO_WRITE_DELAY     = 10;

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
  read_req              <=  0;
  write_req             <=  0;
  r_mem_stb             <=  0;

  r_cmd_stb             <=  0;
  r_write_fifo_stb      <=  0;

  if (ui_clk_sync_rst) begin
    r_wr_count          <=  0;
    r_wr_underrun       <=  0;
    r_wr_error          <=  0;

//    app_rd_data         <=  0;
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

    state               <=  IDLE;
    r_fifo_app_addr     <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        if (!w_fifo_app_empty) begin
          if (!w_fifo_app_cmd) begin
            state         <=  WRITE_PREPARE;
            //state         <=  WRITE_BOT;
          end
          else begin
            state         <=  READ_BOT;
          end
          r_fifo_app_addr <=  w_fifo_app_addr;
          r_cmd_stb       <=  1;
        end
      end
      WRITE_PREPARE: begin
        r_write_fifo_stb  <=  1;
        state             <= WRITE_BOT;
      end
      WRITE_BOT: begin
        r_write_fifo_stb  <=  1;
        r_mem_stb         <=  1;
        r_fifo_app_addr   <=  r_fifo_app_addr + 1;
        state             <=  WRITE_TOP;
      end
      WRITE_TOP: begin
        r_fifo_app_addr   <=  r_fifo_app_addr + 1;
        //r_write_fifo_stb  <=  1;
        r_mem_stb         <=  1;
        state             <=  WRITE_FIN;
      end
      WRITE_FIN: begin
        state             <=  IDLE;
      end
      READ_BOT: begin
        r_fifo_app_addr   <=  r_fifo_app_addr + 1;
        app_rd_data_valid <=  1;
        state             <=  READ_TOP;
      end
      READ_TOP: begin
        app_rd_data_valid <=  1;
        app_rd_data_end   <=  1;
        //r_fifo_app_addr   <=  r_fifo_app_addr + 1;
        state             <=  IDLE;
      end
      default: begin
        state         <=  IDLE;
      end
    endcase
  end
end

endmodule
