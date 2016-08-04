/*
Distributed under the MIT license.
Copyright (c) 2016 Dave McCoy (dave.mccoy@cospandesign.com)

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

/*
 * Author:
 * Description:
 *
 * Changes:
 */

`timescale 1ps / 1ps

module ddr3_ppfifo_controller #(
  parameter                           ING_BUF_DEPTH   = 10,
  parameter                           EGR_BUF_DEPTH   = 6,
  parameter                           MEM_ADDR_DEPTH  = 28

)(
  input                               clk,
  input                               rst,

  input                               ui_clk,
  input                               ui_rst,

  //DMA In Interface 0
  input                               i_idma0_enable,
  output                              o_idma0_finished, //XXX: Not Needed for WB but for DMA it is important!!
  input       [31:0]                  i_idma0_addr,
  input                               i_idma0_busy,
  input       [23:0]                  i_idma0_count,  //XXX: Not Needed for WB but for DMA it is important!!
  input                               i_idma0_flush,  //XXX: Do I need to use this??


  input                               i_idma0_strobe,
  output      [1:0]                   o_idma0_ready,
  input       [1:0]                   i_idma0_activate,
  output      [23:0]                  o_idma0_size,
  input       [31:0]                  i_idma0_data,


  //DMA In Interface 1
  input                               i_idma1_enable,
  output                              o_idma1_finished, //XXX: Not Needed for WB but for DMA it is important!!
  input       [31:0]                  i_idma1_addr,
  input                               i_idma1_busy,
  input       [23:0]                  i_idma1_count,  //XXX: Not Needed for WB but for DMA it is important!!
  input                               i_idma1_flush,  //XXX: Do I need to use this??


  input                               i_idma1_strobe,
  output      [1:0]                   o_idma1_ready,
  input       [1:0]                   i_idma1_activate,
  output      [23:0]                  o_idma1_size,
  input       [31:0]                  i_idma1_data,

  //DMA Out Interface 0
  input                               i_odma0_enable,
  input      [31:0]                   i_odma0_address,
  input      [23:0]                   i_odma0_count,  //XXX: Not Needed for WB but for DMA it is important!!
  input                               i_odma0_flush,  //XXX: Do I need to use this??


  input                               i_odma0_strobe,
  output      [31:0]                  o_odma0_data,
  output                              o_odma0_ready,
  input                               i_odma0_activate,
  output      [23:0]                  o_odma0_size,

  //DMA Out Interface 1
  input                               i_odma1_enable,
  input      [31:0]                   i_odma1_address,
  input      [23:0]                   i_odma1_count,  //XXX: Not Needed for WB but for DMA it is important!!
  input                               i_odma1_flush,  //XXX: Do I need to use this??


  input                               i_odma1_strobe,
  output      [31:0]                  o_odma1_data,
  output                              o_odma1_ready,
  input                               i_odma1_activate,
  output      [23:0]                  o_odma1_size,


  //DDR3 APP IF
  input                               i_init_calib_complete,
  input                               i_app_rdy,
  output                              o_app_en,
  output  [2:0]                       o_app_cmd,
  output  [MEM_ADDR_DEPTH - 1:0]      o_app_addr,

  input                               i_app_wdf_rdy,
  output                              o_app_wdf_wren,
  output                              o_app_wdf_end,
  output  [3:0]                       o_app_wdf_mask,
  output  [31:0]                      o_app_wdf_data,

  input   [31:0]                      i_app_rd_data,
  input                               i_app_rd_data_valid,
  input                               i_app_rd_data_end,

  output  [1:0]                       o_ing_enable,
  output  [1:0]                       o_egr_enable,
  output  [1:0]                       o_inout_enable,
  output  [3:0]                       o_state
);

//local parameters
localparam  IDLE                  = 4'h0;
localparam  IDMA_SELECT           = 4'h1;
localparam  ODMA_SELECT           = 4'h2;
localparam  IDMA_PREPARE          = 4'h3;
localparam  ODMA_PREPARE          = 4'h4;
localparam  IDMA_FIRST            = 4'h5;
localparam  IDMA_ACTIVE           = 4'h6;
localparam  IDMA_WAIT_FOR_IDLE    = 4'h7;
localparam  ODMA_FIRST            = 4'h8;
localparam  ODMA_ACTIVE           = 4'h9;
localparam  ODMA_WAIT_FOR_IDLE    = 4'hA;

localparam  ING_MAX               = 1;
localparam  EGR_MAX               = 1;

localparam  TIMEOUT               = 256;


//registes/wires
(* keep = "true" *) reg     [3:0]                   state;
reg     [MEM_ADDR_DEPTH - 3:0]  r_ram_addr;
reg     [3:0]                   r_select;
reg                             r_ing_path_en;
reg                             r_egr_path_en;

reg                             r_ing_app_en;
wire                            w_cc_ing_app_en;
reg                             r_egr_app_en;
wire                            w_cc_egr_app_en;

reg                             r_ingress_priority;
reg                             r_egress_priority;
reg                             r_inout_priority;

wire                            w_adapter_busy;
wire    [ING_BUF_DEPTH - 1: 0]  w_bram_addr;

wire    [1:0]                   w_inout_enable;
wire                            w_inout_priority;

(*keep = "true" *)wire                            w_ingress_enable;
reg                             r_ingress_finished;
wire    [MEM_ADDR_DEPTH - 1:0]  w_ingress_address;
wire                            w_ingress_bsy;
wire    [23:0]                  w_ingress_count;
wire                            w_ingress_flush;  //XXX: Do I need to use this??

wire                            w_contention;
reg                             r_release;
reg     [31:0]                  r_timeout;


wire                            w_ingress_fifo_stb;
(*keep = "true" *) wire  [1:0]  w_ingress_fifo_rdy;
wire    [1:0]                   w_ingress_fifo_act;
wire    [23:0]                  w_ingress_fifo_size;
wire    [31:0]                  w_ingress_fifo_data;


(*keep = "true" *) wire                            w_egress_enable;
wire    [MEM_ADDR_DEPTH - 1:0]  w_egress_address;
wire    [23:0]                  w_egress_count;
wire                            w_egress_flush;  //XXX: Do I need to use this??


(*keep = "true" *) wire                            w_egress_fifo_stb;
(*keep = "true" *) wire                            w_egress_fifo_rdy;
(*keep = "true" *) wire                            w_egress_fifo_act;
(*keep = "true" *) wire    [23:0]                  w_egress_fifo_size;
(*keep = "true" *) wire    [31:0]                  w_egress_fifo_data;

wire    [ING_MAX:0]             w_ing_enable;
wire    [ING_MAX:0]             w_ing_finished;
wire    [MEM_ADDR_DEPTH - 1:0]  w_ing_mem_addr  [0:ING_MAX];
wire    [ING_MAX:0]             w_ing_bsy;
wire    [23:0]                  w_ing_count     [0:ING_MAX];
wire    [ING_MAX:0]             w_ing_flush;

wire    [ING_MAX:0]             w_ing_fifo_stb;
wire    [1:0]                   w_ing_fifo_rdy  [0:ING_MAX];
wire    [1:0]                   w_ing_fifo_act  [0:ING_MAX];
wire    [23:0]                  w_ing_fifo_size [0:ING_MAX];
wire    [31:0]                  w_ing_fifo_data [0:ING_MAX];


wire    [EGR_MAX:0]             w_egr_enable;
wire    [MEM_ADDR_DEPTH - 1:0]  w_egr_mem_addr  [0:EGR_MAX];
wire    [23:0]                  w_egr_count     [0:EGR_MAX];
wire    [EGR_MAX:0]             w_egr_flush;

wire    [EGR_MAX:0]             w_egr_fifo_stb;
wire    [EGR_MAX:0]             w_egr_fifo_rdy;
wire    [EGR_MAX:0]             w_egr_fifo_act;
wire    [23:0]                  w_egr_fifo_size [0:EGR_MAX];
wire    [31:0]                  w_egr_fifo_data [0:EGR_MAX];

//PPFIFO to BRAM
wire                            w_ing_ddr3_fifo_rdy;
wire                            w_ing_ddr3_fifo_act;
wire    [23:0]                  w_ing_ddr3_fifo_size;
wire                            w_ing_ddr3_fifo_stb;
wire    [31:0]                  w_ing_ddr3_fifo_data;

//PPFIFO to BRAM
wire    [1:0]                   w_egr_ddr3_fifo_rdy;
wire    [1:0]                   w_egr_ddr3_fifo_act;
wire    [23:0]                  w_egr_ddr3_fifo_size;
wire                            w_egr_ddr3_fifo_stb;
wire    [31:0]                  w_egr_ddr3_fifo_data;
wire                            w_egress_inactive;

reg                             r_egress_fifo_rst;

wire                            w_egress_cc_inactive;

wire                            ddr3_app_if_idle;
(*keep = "true" *)wire                            ddr3_app_cc_if_idle;

//submodules
ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (ING_BUF_DEPTH              )
) lcl_ingress_fifo (
  .reset                      (rst || ui_rst              ),

  //Write Side
  .write_clock                (clk                        ),
  .write_ready                (w_ingress_fifo_rdy         ),
  .write_activate             (w_ingress_fifo_act         ),
  .write_fifo_size            (w_ingress_fifo_size        ),
  .write_strobe               (w_ingress_fifo_stb         ),
  .write_data                 (w_ingress_fifo_data        ),
//  .inactive                   (w_ingress_inactive         ),

  //Read Side
  .read_clock                 (ui_clk                     ),
  .read_ready                 (w_ing_ddr3_fifo_rdy        ),
  .read_activate              (w_ing_ddr3_fifo_act        ),
  .read_count                 (w_ing_ddr3_fifo_size       ),
  .read_strobe                (w_ing_ddr3_fifo_stb        ),
  .read_data                  (w_ing_ddr3_fifo_data       )
);

ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (EGR_BUF_DEPTH              )
) lcl_egress_fifo (
  .reset                      (rst || r_egress_fifo_rst || ui_rst  ),
  //Write Side
  .write_clock                (ui_clk                     ),
  .write_ready                (w_egr_ddr3_fifo_rdy        ),
  .write_activate             (w_egr_ddr3_fifo_act        ),
  .write_fifo_size            (w_egr_ddr3_fifo_size       ),
  .write_strobe               (w_egr_ddr3_fifo_stb        ),
  .write_data                 (w_egr_ddr3_fifo_data       ),

  //Read Side
  .read_clock                 (clk                        ),
  .read_ready                 (w_egress_fifo_rdy          ),
  .read_activate              (w_egress_fifo_act          ),
  .read_count                 (w_egress_fifo_size         ),
  .read_strobe                (w_egress_fifo_stb          ),
  .read_data                  (w_egress_fifo_data         ),
  .inactive                   (w_egress_inactive          )
);



ddr3_app_if #(
  .MEM_ADDR_DEPTH             (MEM_ADDR_DEPTH             )
)ddr3_app_interface (

  .rst                        (rst                        ),
  .clk                        (ui_clk                     ),

  .idle                       (ddr3_app_if_idle           ),

  .i_init_calib_complete      (i_init_calib_complete      ),

  .i_app_rdy                  (i_app_rdy                  ),
  .o_app_en                   (o_app_en                   ),
  .o_app_cmd                  (o_app_cmd                  ),
  .o_app_addr                 (o_app_addr                 ),

  .i_app_wdf_rdy              (i_app_wdf_rdy              ),
  .o_app_wdf_wren             (o_app_wdf_wren             ),
  .o_app_wdf_end              (o_app_wdf_end              ),
  .o_app_wdf_mask             (o_app_wdf_mask             ),
  .o_app_wdf_data             (o_app_wdf_data             ),

  .i_app_rd_data              (i_app_rd_data              ),
  .i_app_rd_data_valid        (i_app_rd_data_valid        ),
  .i_app_rd_data_end          (i_app_rd_data_end          ),


  .i_ingress_en               (w_cc_ing_app_en            ),
  .i_ingress_dword_addr       (r_ram_addr                 ),

  .i_ingress_rdy              (w_ing_ddr3_fifo_rdy        ),
  .o_ingress_act              (w_ing_ddr3_fifo_act        ),
  .i_ingress_size             (w_ing_ddr3_fifo_size       ),
  .i_ingress_data             (w_ing_ddr3_fifo_data       ),
  .o_ingress_stb              (w_ing_ddr3_fifo_stb        ),

  .i_egress_en                (w_cc_egr_app_en            ),
  .i_egress_dword_addr        (r_ram_addr                 ),

  .i_egress_rdy               (w_egr_ddr3_fifo_rdy        ),
  .o_egress_act               (w_egr_ddr3_fifo_act        ),
  .i_egress_size              (w_egr_ddr3_fifo_size       ),
  .o_egress_data              (w_egr_ddr3_fifo_data       ),
  .o_egress_stb               (w_egr_ddr3_fifo_stb        )
);

cross_clock_enable cce_idle (
  .rst                        (rst                        ),
  .in_en                      (ddr3_app_if_idle           ),

  .out_clk                    (clk                        ),
  .out_en                     (ddr3_app_cc_if_idle        )   //If we are reading from the DDR3 this flag will tell us it's okay to clear the DDR3 output FIFO
);

cross_clock_enable cce_ing_app_en(
  .rst                        (rst                        ),
  .in_en                      (r_ing_app_en               ),

  .out_clk                    (ui_clk                     ),
  .out_en                     (w_cc_ing_app_en            )
);

cross_clock_enable cce_egr_app_en(
  .rst                        (rst                        ),
  .in_en                      (r_egr_app_en               ),

  .out_clk                    (ui_clk                     ),
  .out_en                     (w_cc_egr_app_en            )
);

//asynchronous logic
//assign  w_bram_addr         = r_ing_path_en ? i_ibuf_addrb: i_obuf_addra;

assign  w_ingress_enable    = r_ing_path_en ? w_ing_enable    [r_select] : 1'b0;
assign  w_ingress_address   = r_ing_path_en ? w_ing_mem_addr  [r_select] : 0;
assign  w_ingress_count     = r_ing_path_en ? w_ing_count     [r_select] : 24'h0;
assign  w_ingress_flush     = r_ing_path_en ? w_ing_flush     [r_select] : 1'b0;
assign  w_ingress_fifo_stb  = r_ing_path_en ? w_ing_fifo_stb  [r_select] : 1'b0;
assign  w_ingress_fifo_act  = r_ing_path_en ? w_ing_fifo_act  [r_select] : 2'b0;
assign  w_ingress_fifo_data = r_ing_path_en ? w_ing_fifo_data [r_select] : 32'h0;

genvar gvi;
generate
for (gvi = 0; gvi <= ING_MAX; gvi = gvi + 1) begin: ingress_select_for
  assign  w_ing_fifo_rdy  [gvi]  = (r_ing_path_en && (r_select == gvi) && !r_release) ? w_ingress_fifo_rdy   : 2'b00;
  assign  w_ing_fifo_size [gvi]  = (r_ing_path_en && (r_select == gvi)) ? w_ingress_fifo_size  : 24'h00;
  assign  w_ing_finished  [gvi]  = (r_ing_path_en && (r_select == gvi)) ? r_ingress_finished   : 1'b0;
end
endgenerate

assign  w_egress_enable     = r_egr_path_en ? w_egr_enable    [r_select] : 1'b0;
assign  w_egress_address    = r_egr_path_en ? w_egr_mem_addr  [r_select] : 0;
assign  w_egress_count      = r_egr_path_en ? w_egr_count     [r_select] : 24'h0;
assign  w_egress_flush      = r_egr_path_en ? w_egr_flush     [r_select] : 1'b0;
assign  w_egress_fifo_stb   = r_egr_path_en ? w_egr_fifo_stb  [r_select] : 1'b0;
assign  w_egress_fifo_act   = r_egr_path_en ? w_egr_fifo_act  [r_select] : 1'b0;

genvar gva;
generate
for (gva = 0; gva <= EGR_MAX; gva = gva + 1) begin: egress_select_for
  assign  w_egr_fifo_rdy  [gva]  = (r_egr_path_en && (r_select == gva)) ? w_egress_fifo_rdy   : 1'b0;
  assign  w_egr_fifo_size [gva]  = (r_egr_path_en && (r_select == gva)) ? w_egress_fifo_size  : 24'h00;
  assign  w_egr_fifo_data [gva]  = (r_egr_path_en && (r_select == gva)) ? w_egress_fifo_data  : 32'h00;
end
endgenerate


//DMA In Interface 0
assign w_ing_enable[0]    = i_idma0_enable;
assign o_idma0_finished   = w_ing_finished[0];
assign w_ing_mem_addr[0]  = i_idma0_addr;
assign w_ing_bsy[0]       = i_idma0_busy;
assign w_ing_count[0]     = i_idma0_count;
assign w_ing_flush[0]     = i_idma0_flush;

assign w_ing_fifo_stb[0]  = i_idma0_strobe;
assign o_idma0_ready      = w_ing_fifo_rdy[0];
assign w_ing_fifo_act[0]  = i_idma0_activate;
assign o_idma0_size       = w_ing_fifo_size[0];
assign w_ing_fifo_data[0] = i_idma0_data;


//DMA In Interface 1
assign w_ing_enable[1]    = i_idma1_enable;
assign o_idma1_finished   = w_ing_finished[1];
assign w_ing_mem_addr[1]  = i_idma1_addr;
assign w_ing_bsy[1]       = i_idma1_busy;
assign w_ing_count[1]     = i_idma1_count;
assign w_ing_flush[1]     = i_idma1_flush;

assign w_ing_fifo_stb[1]  = i_idma1_strobe;
assign o_idma1_ready      = w_ing_fifo_rdy[1];
assign w_ing_fifo_act[1]  = i_idma1_activate;
assign o_idma1_size       = w_ing_fifo_size[1];
assign w_ing_fifo_data[1] = i_idma1_data;

//DMA Out Interface 0
assign w_egr_enable[0]    = i_odma0_enable;
assign w_egr_mem_addr[0]  = i_odma0_address;
assign w_egr_count[0]     = i_odma0_count;
assign w_egr_flush[0]     = i_odma0_flush;

assign w_egr_fifo_stb[0]  = i_odma0_strobe;
assign o_odma0_data       = w_egr_fifo_data[0];
assign o_odma0_ready      = w_egr_fifo_rdy[0];
assign w_egr_fifo_act[0]  = i_odma0_activate;
assign o_odma0_size       = w_egr_fifo_size[0];

//DMA Out Interface 1
assign w_egr_enable[1]    = i_odma1_enable;
assign w_egr_mem_addr[1]  = i_odma1_address;
assign w_egr_count[1]     = i_odma1_count;
assign w_egr_flush[1]     = i_odma1_flush;

assign w_egr_fifo_stb[1]  = i_odma1_strobe;
assign o_odma1_data       = w_egr_fifo_data[1];
assign o_odma1_ready      = w_egr_fifo_rdy[1];
assign w_egr_fifo_act[1]  = i_odma1_activate;
assign o_odma1_size       = w_egr_fifo_size[1];


assign  w_inout_enable[0] = (w_ing_enable != 0);
assign  w_inout_enable[1] = (w_egr_enable != 0);


assign  o_ing_enable      = 2'b0;
assign  o_egr_enable      = 2'b0;
assign  o_inout_enable    = 2'b0;

assign  o_state           = state;

assign  w_contention      = ((w_ing_enable == 2'b11) || (w_egr_enable == 2'b11)) || ((w_ing_enable != 0) && (w_egr_enable != 0));


//synchronous logic
integer k;
always @ (posedge clk) begin
  r_egress_fifo_rst     <=  0;

  if (rst) begin
    state               <=  IDLE;
    r_ram_addr          <=  0;
    r_ing_path_en       <=  0;
    r_egr_path_en       <=  0;


    r_ing_app_en        <=  0;
    r_egr_app_en        <=  0;


    r_ingress_priority  <=  0;
    r_egress_priority   <=  0;
    r_inout_priority    <=  0;
    r_select            <=  0;
    r_release           <=  0;

    r_timeout           <=  0;


  end
  else begin
    case (state)
      IDLE: begin
        r_ram_addr            <=  0;
        r_ing_path_en         <=  0;
        r_egr_path_en         <=  0;
        r_ing_app_en          <=  0;
        r_egr_app_en          <=  0;
        r_release             <=  0;
        r_timeout             <=  0;

        //Wait for an activate on any one of the DMA interfaces
        case (w_inout_enable)
          2'b01: begin
            $display("Input Path Selected");
            r_inout_priority  <=  1;
            state             <= IDMA_SELECT;
          end
          2'b10: begin
            $display("Output Path Selected");
            r_inout_priority  <=  0;
            state             <= ODMA_SELECT;
          end
          2'b11: begin
            $display("Both Path Selected, break tie with priority");
            r_inout_priority  <=  ~r_inout_priority;
            if (!r_inout_priority) begin
              state           <=  IDMA_SELECT;
            end
            else begin
              state           <=  ODMA_SELECT;
            end
          end
          default: begin
            //Nothing Selected
          end
        endcase
      end
      IDMA_SELECT: begin
        case(w_ing_enable)
          2'b01: begin
            $display("Select Ingress Channel 0");
            r_ingress_priority  <=  1;
            r_select            <=  0;
          end
          2'b10: begin
            $display("Select Ingress Channel 1");
            r_ingress_priority  <=  0;
            r_select            <=  1;
          end
          2'b11: begin
            $display("Select Ingress Channel %h", r_ingress_priority);
            r_ingress_priority  <=  ~r_ingress_priority;
            r_select            <=  r_ingress_priority;
          end
        endcase
        state                   <= IDMA_PREPARE;
        r_ing_path_en           <= 1;
        r_ram_addr              <= w_ingress_address;
      end
      IDMA_PREPARE: begin
        state                   <= IDMA_FIRST;
        r_ing_app_en            <= 1;
      end
      ODMA_SELECT: begin
        case(w_egr_enable)
          2'b01: begin
            r_egress_priority   <=  1;
            r_select            <=  0;
          end
          2'b10: begin
            r_egress_priority   <=  0;
            r_select            <=  1;
          end
          2'b11: begin
            r_egress_priority   <=  ~r_egress_priority;
            r_select            <=  r_egress_priority;
          end
        endcase
        state                   <= ODMA_PREPARE;
        r_ram_addr              <= w_egress_address;
        r_egr_path_en           <= 1;
      end
      ODMA_PREPARE: begin
        //pass through, need to give everything a chance to setup
        state                   <= ODMA_FIRST;
        r_egr_app_en            <=  1;
      end
      ODMA_FIRST: begin
        if (w_egress_fifo_act > 0) begin
          state                 <=  ODMA_ACTIVE;
        end
        //XXX: Need a timeout so that if the user is idle, it just moves to the next item
        if (r_timeout < TIMEOUT) begin
          r_timeout             <=  r_timeout + 1;
        end
        else if (w_egress_fifo_act == 0) begin
          state                 <=  ODMA_ACTIVE;
        end
      end
      ODMA_ACTIVE: begin
        if (!w_egress_enable || r_release) begin
          r_egr_app_en          <= 0;
          state                 <= ODMA_WAIT_FOR_IDLE;
        end
      end
      ODMA_WAIT_FOR_IDLE: begin
        if (ddr3_app_cc_if_idle) begin
          state                 <= IDLE;
          r_egress_fifo_rst     <=  1;
        end
      end

      //Ingress
      IDMA_FIRST: begin
        if (w_ingress_fifo_act > 0) begin
          state                 <=  IDMA_ACTIVE;
        end
        //XXX: Need a timeout so that if the user is idle, it just moves to the next item
        if (r_timeout < TIMEOUT) begin
          r_timeout             <=  r_timeout + 1;
        end
        else if (w_ingress_fifo_act == 0) begin
          state                 <=  IDMA_ACTIVE;
        end

      end
      IDMA_ACTIVE: begin
        //if (!w_ingress_enable || r_release) begin
        if ((!w_ingress_enable || r_release) && (w_ingress_fifo_rdy == 2'b11)) begin
          r_ing_app_en          <= 0;
          state                 <=  IDMA_WAIT_FOR_IDLE;
        end
      end
      IDMA_WAIT_FOR_IDLE: begin
        if (ddr3_app_cc_if_idle) begin
          //Wrote all the data to memory, done
          state                 <= IDLE;
        end
      end


      default: begin
        //Shouldn't get here
        state <=  IDLE;
      end
    endcase


    if (w_contention) begin
      if (w_ingress_enable && (state == IDMA_ACTIVE)) begin
        if (w_ingress_fifo_act > 0) begin
          //At least on of the packets got through, we can let go
          r_release <=  1;
        end
      end
      else if (w_egress_enable && (state == ODMA_ACTIVE)) begin
        if (w_egress_fifo_act) begin
          r_release <= 1;
        end
      end
    end
    if (!w_contention && r_release) begin
      r_release     <= 0;
    end

  end
end




endmodule
