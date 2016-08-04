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

//`define ING_MAX 1
`define EGR_MAX 1

module ddr3_arbiter_controller #(
  parameter                           BUF_DEPTH       = 10,
  parameter                           MEM_ADDR_DEPTH  = 26
)(
  input                               clk,
  input                               rst,

  input                               ui_clk,
  input                               ui_rst,

  //DMA In Interface 0
  input                               i_idma0_enable,
  output                              o_idma0_finished,
  input       [31:0]                  i_idma0_addr,
  input                               i_idma0_busy,
  input       [23:0]                  i_idma0_count,
  input                               i_idma0_flush,  //XXX: Do I need to use this??


  input                               i_idma0_strobe,
  output      [1:0]                   o_idma0_ready,
  input       [1:0]                   i_idma0_activate,
  output      [23:0]                  o_idma0_size,
  input       [31:0]                  i_idma0_data,


  //DMA In Interface 1
  input                               i_idma1_enable,
  output                              o_idma1_finished,
  input       [31:0]                  i_idma1_addr,
  input                               i_idma1_busy,
  input       [23:0]                  i_idma1_count,
  input                               i_idma1_flush,  //XXX: Do I need to use this??


  input                               i_idma1_strobe,
  output      [1:0]                   o_idma1_ready,
  input       [1:0]                   i_idma1_activate,
  output      [23:0]                  o_idma1_size,
  input       [31:0]                  i_idma1_data,

  //DMA Out Interface 0
  input                               i_odma0_enable,
  input      [31:0]                   i_odma0_address,
  input      [23:0]                   i_odma0_count,
  input                               i_odma0_flush,  //XXX: Do I need to use this??


  input                               i_odma0_strobe,
  output      [31:0]                  o_odma0_data,
  output                              o_odma0_ready,
  input                               i_odma0_activate,
  output      [23:0]                  o_odma0_size,

  //DMA Out Interface 1
  input                               i_odma1_enable,
  input      [31:0]                   i_odma1_address,
  input      [23:0]                   i_odma1_count,
  input                               i_odma1_flush,  //XXX: Do I need to use this??


  input                               i_odma1_strobe,
  output      [31:0]                  o_odma1_data,
  output                              o_odma1_ready,
  input                               i_odma1_activate,
  output      [23:0]                  o_odma1_size,

  //BRAM Interface
  output                              o_ibuf_go,
  input                               i_ibuf_bsy,
  input                               i_ibuf_ddr3_fault,
  output reg  [BUF_DEPTH - 1:0]       o_ibuf_count,
  output reg  [BUF_DEPTH - 1:0]       o_ibuf_start_addrb,
  input       [BUF_DEPTH - 1:0]       i_ibuf_addrb,
  output      [31:0]                  o_ibuf_doutb,
  output reg  [MEM_ADDR_DEPTH - 1:0]  o_ibuf_ddr3_addrb,

  output                              o_obuf_go,
  input                               i_obuf_bsy,
  input                               i_obuf_ddr3_fault,
  output reg  [BUF_DEPTH - 1:0]       o_obuf_count,
  output reg  [BUF_DEPTH - 1:0]       o_obuf_start_addra,
  input       [BUF_DEPTH - 1:0]       i_obuf_addra,
  input       [31:0]                  i_obuf_dina,
  input                               i_obuf_wea,
  output reg  [MEM_ADDR_DEPTH - 1:0]  o_obuf_ddr3_addra,

  output  [1:0]                       o_ing_enable,
  output  [1:0]                       o_egr_enable,
  output  [1:0]                       o_inout_enable,
  output  [3:0]                       o_state
);
//local parameters
localparam  MAX_COUNT             = 2 ** BUF_DEPTH;
localparam  READ_COUNT            = (MAX_COUNT >> 2);

localparam  IDLE                  = 4'h0;
localparam  IDMA_SELECT           = 4'h1;
localparam  ODMA_SELECT           = 4'h2;
localparam  IDMA_PREPARE          = 4'h3;
localparam  ODMA_PREPARE          = 4'h4;

localparam  IDMA_CONFIGURE        = 4'h5;
localparam  IDMA_WAIT_BRAM_START  = 4'h6;
localparam  IDMA_WAIT_BRAM        = 4'h7;
localparam  IDMA_WAIT_DDR3_START  = 4'h8;
localparam  IDMA_WAIT_DDR3        = 4'h9;

localparam  ODMA_CONFIGURE        = 4'hA;
localparam  ODMA_WAIT_DDR3_START  = 4'hB;
localparam  ODMA_WAIT_DDR3        = 4'hC;
localparam  ODMA_WAIT_PPFIFO_START= 4'hD;
localparam  ODMA_WAIT_PPFIFO      = 4'hE;

localparam  ING_MAX               = 1;
localparam  EGR_MAX               = 1;


//registes/wires
reg     [3:0]                   state;
reg     [31:0]                  r_ram_addr;
reg                             r_reset_fifo;
reg     [3:0]                   r_select;
reg                             r_ingress_path_en;
reg                             r_egress_path_en;

reg                             r_ingress_priority;
reg                             r_egress_priority;
reg                             r_inout_priority;

wire                            w_ing_ppfifo_has_data;
wire                            w_egr_ppfifo_is_ready;

reg                             r_ppfifo_2_mem_stb;
reg                             r_mem_2_ppfifo_stb;
wire                            w_adapter_busy;
wire    [BUF_DEPTH - 1: 0]      w_bram_addr;

wire    [1:0]                   w_inout_enable;
wire                            w_inout_priority;

wire                            w_ingress_enable;
reg                             r_ingress_finished;
wire    [MEM_ADDR_DEPTH - 1:0]  w_ingress_mem_addr;
reg                             w_ingress_bsy;
wire    [23:0]                  w_ingress_count;
wire                            w_ingress_flush;  //XXX: Do I need to use this??

wire                            w_ingress_fifo_stb;
wire    [1:0]                   w_ingress_fifo_rdy;
wire    [1:0]                   w_ingress_fifo_act;
wire    [23:0]                  w_ingress_fifo_size;
wire    [31:0]                  w_ingress_fifo_data;


wire                            w_egress_enable;
wire    [MEM_ADDR_DEPTH - 1:0]  w_egress_mem_addr;
wire    [23:0]                  w_egress_count;
wire                            w_egress_flush;  //XXX: Do I need to use this??


wire                            w_egress_fifo_stb;
wire                            w_egress_fifo_rdy;
wire                            w_egress_fifo_act;
wire    [23:0]                  w_egress_fifo_size;
wire    [31:0]                  w_egress_fifo_data;

wire    [ING_MAX:0]             w_ing_enable;
reg                             r_ing_finished  [0:ING_MAX];
wire    [MEM_ADDR_DEPTH - 1:0]  w_ing_mem_addr  [0:ING_MAX];
wire                            w_ing_bsy       [0:ING_MAX];
wire    [23:0]                  w_ing_count     [0:ING_MAX];
wire                            w_ing_flush     [0:ING_MAX];

wire                            w_ing_fifo_stb  [0:ING_MAX];
reg     [1:0]                   r_ing_fifo_rdy  [0:ING_MAX];
wire    [1:0]                   w_ing_fifo_act  [0:ING_MAX];
reg     [23:0]                  r_ing_fifo_size [0:ING_MAX];
wire    [31:0]                  w_ing_fifo_data [0:ING_MAX];


wire    [ING_MAX:0]             w_egr_enable;
wire    [MEM_ADDR_DEPTH - 1:0]  w_egr_mem_addr  [0:EGR_MAX];
wire    [23:0]                  w_egr_count     [0:EGR_MAX];
wire                            w_egr_flush     [0:EGR_MAX];

wire                            w_egr_fifo_stb  [0:EGR_MAX];
reg     [1:0]                   r_egr_fifo_rdy  [0:EGR_MAX];
wire    [1:0]                   w_egr_fifo_act  [0:EGR_MAX];
reg     [23:0]                  r_egr_fifo_size [0:EGR_MAX];
reg     [31:0]                  r_egr_fifo_data [0:EGR_MAX];

//PPFIFO to BRAM
wire                            w_ing_bram_fifo_rdy;
wire                            w_ing_bram_fifo_act;
wire    [23:0]                  w_ing_bram_fifo_size;
wire                            w_ing_bram_fifo_stb;
wire    [31:0]                  w_ing_bram_fifo_data;
wire                            w_ingress_inactive;

//PPFIFO to BRAM
wire    [1:0]                   w_egr_bram_fifo_rdy;
wire    [1:0]                   w_egr_bram_fifo_act;
wire    [23:0]                  w_egr_bram_fifo_size;
wire                            w_egr_bram_fifo_stb;
wire    [31:0]                  w_egr_bram_fifo_data;
wire                            w_egress_inactive;

//submodules
reg                             r_ibuf_go;
reg                             r_obuf_go;
wire                            w_ibuf_bsy;
wire                            w_obuf_bsy;

//Incomming Interrupt Strobe
cross_clock_strobe cc_ibuf_stb (
  .rst                        (rst                        ),
  .in_clk                     (clk                        ),
  .in_stb                     (r_ibuf_go                  ),

  .out_clk                    (ui_clk                     ),
  .out_stb                    (o_ibuf_go                  )
);
cross_clock_strobe cc_obuf_stb (
  .rst                        (rst                        ),
  .in_clk                     (clk                        ),
  .in_stb                     (r_obuf_go                  ),

  .out_clk                    (ui_clk                     ),
  .out_stb                    (o_obuf_go                  )
);

cross_clock_enable cc_ibuf_en (
  .rst                        (rst                        ),
  .in_en                      (i_ibuf_bsy                 ),

  .out_clk                    (clk                        ),
  .out_en                     (w_ibuf_bsy                 )
);

cross_clock_enable cc_obuf_en (
  .rst                        (rst                        ),
  .in_en                      (i_obuf_bsy                 ),

  .out_clk                    (clk                        ),
  .out_en                     (w_obuf_bsy                 )
);


ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (BUF_DEPTH                  )
) lcl_ingress_fifo (
  //.reset                      (rst || ui_rst            ),
  .reset                      (rst                        ),
  //Write Side
  .write_clock                (clk                        ),
  .write_ready                (w_ingress_fifo_rdy         ),
  .write_activate             (w_ingress_fifo_act         ),
  .write_fifo_size            (w_ingress_fifo_size        ),
  .write_strobe               (w_ingress_fifo_stb         ),
  .write_data                 (w_ingress_fifo_data        ),
  .inactive                   (w_ingress_inactive         ),

  //Read Side
  //.read_clock                 (ui_clk                     ),
  .read_clock                 (clk                        ),
  .read_ready                 (w_ing_bram_fifo_rdy        ),
  .read_activate              (w_ing_bram_fifo_act        ),
  .read_count                 (w_ing_bram_fifo_size       ),
  .read_strobe                (w_ing_bram_fifo_stb        ),
  .read_data                  (w_ing_bram_fifo_data       )
);

ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (BUF_DEPTH                  )
) lcl_egress_fifo (
  //.reset                      (rst || ui_rst            ),
  .reset                      (rst || r_reset_fifo        ),
  //Write Side
  //.write_clock                (ui_clk                     ),
  .write_clock                (clk                        ),
  .write_ready                (w_egr_bram_fifo_rdy        ),
  .write_activate             (w_egr_bram_fifo_act        ),
  .write_fifo_size            (w_egr_bram_fifo_size       ),
  .write_strobe               (w_egr_bram_fifo_stb        ),
  .write_data                 (w_egr_bram_fifo_data       ),

  //Read Side
  .read_clock                 (clk                        ),
  .read_ready                 (w_egress_fifo_rdy          ),
  .read_activate              (w_egress_fifo_act          ),
  .read_count                 (w_egress_fifo_size         ),
  .read_strobe                (w_egress_fifo_stb          ),
  .read_data                  (w_egress_fifo_data         ),
  .inactive                   (w_egress_inactive          )
);


adapter_ppfifo_dpb #(
  .DATA_WIDTH                 (32                         ),
  .MEM_DEPTH                  (BUF_DEPTH                  )
) ppfifo_2_bram (
  .clk                        (clk                        ),
  .rst                        (rst || ui_rst              ),

  .i_ppfifo_2_mem_stb         (r_ppfifo_2_mem_stb         ),
  .i_mem_2_ppfifo_stb         (r_mem_2_ppfifo_stb         ),
  .o_ing_ppfifo_has_data      (w_ing_ppfifo_has_data      ),
  .o_egr_ppfifo_is_ready      (w_egr_ppfifo_is_ready      ),
  .o_busy                     (w_adapter_busy             ),

  //User Memory Interface
  .i_bram_clk                 (ui_clk                     ),
  .i_bram_we                  (i_obuf_wea                 ),
  .i_bram_addr                (w_bram_addr                ),
  .i_bram_din                 (i_obuf_dina                ),
  .o_bram_dout                (o_ibuf_doutb               ),

  //Ping Pong FIFO Interface
  .i_write_ready              (w_egr_bram_fifo_rdy        ),
  .o_write_activate           (w_egr_bram_fifo_act        ),
  .i_write_size               (w_egr_bram_fifo_size       ),
  .o_write_stb                (w_egr_bram_fifo_stb        ),
  .o_write_data               (w_egr_bram_fifo_data       ),

  .i_read_ready               (w_ing_bram_fifo_rdy        ),
  .o_read_activate            (w_ing_bram_fifo_act        ),
  .i_read_size                (w_ing_bram_fifo_size       ),
  .o_read_stb                 (w_ing_bram_fifo_stb        ),
  .i_read_data                (w_ing_bram_fifo_data       )

);

//asynchronous logic
assign  w_bram_addr         = r_ingress_path_en ? i_ibuf_addrb: i_obuf_addra;

assign  w_ingress_enable    = r_ingress_path_en ? w_ing_enable[r_select]    : 1'b0;
assign  w_ingress_address   = r_ingress_path_en ? w_ing_mem_addr[r_select]  : 0;
assign  w_ingress_count     = r_ingress_path_en ? w_ing_count[r_select]     : 24'h0;
assign  w_ingress_flush     = r_ingress_path_en ? w_ing_flush[r_select]     : 1'b0;
assign  w_ingress_fifo_stb  = r_ingress_path_en ? w_ing_fifo_stb[r_select]  : 1'b0;
assign  w_ingress_fifo_act  = r_ingress_path_en ? w_ing_fifo_act[r_select]  : 2'b0;
assign  w_ingress_fifo_data = r_ingress_path_en ? w_ing_fifo_data[r_select] : 32'h0;

integer i;
always @ (*) begin
  for (i = 0; i < ING_MAX + 1; i = i + 1) begin
    if (r_ingress_path_en && (r_select == i)) begin
      r_ing_finished[i]   = r_ingress_finished;
      r_ing_fifo_rdy[i]   = w_ingress_fifo_rdy;
      r_ing_fifo_size[i]  = w_ingress_fifo_size;
    end
    else begin
      r_ing_finished[i]   = 1'b0;
      r_ing_fifo_rdy[i]   = 2'b0;
      r_ing_fifo_size[i]  = 24'h0;
    end
  end
end


assign  w_egress_enable     = r_egress_path_en ? w_egr_enable[r_select]     : 1'b0;
assign  w_egress_address    = r_egress_path_en ? w_egr_mem_addr[r_select]   : 0;
assign  w_egress_count      = r_egress_path_en ? w_egr_count[r_select]      : 24'h0;
assign  w_egress_flush      = r_egress_path_en ? w_egr_flush[r_select]      : 1'b0;

assign  w_egress_fifo_stb   = r_egress_path_en ? w_egr_fifo_stb[r_select]   : 1'b0;
assign  w_egress_fifo_act   = r_egress_path_en ? w_egr_fifo_act[r_select]   : 2'b0;

integer j;
always @ (*) begin
  for (j = 0; j < EGR_MAX + 1; j = j + 1) begin
    if (r_egress_path_en && (r_select == j)) begin
      r_egr_fifo_rdy[j]   = w_egress_fifo_rdy;
      r_egr_fifo_size[j]  = w_egress_fifo_size;
      r_egr_fifo_data[j]  = w_egress_fifo_data;
    end
    else begin
      r_egr_fifo_rdy[j]   = 2'b0;
      r_egr_fifo_size[j]  = 24'h0;
      r_egr_fifo_data[j]  = 32'h0;
    end
  end
end

//DMA In Interface 0
assign w_ing_enable[0]    = i_idma0_enable;
assign o_idma0_finished   = r_ing_finished[0];
assign w_ing_mem_addr[0]  = i_idma0_addr;
assign w_ing_bsy[0]       = i_idma0_busy;
assign w_ing_count[0]     = i_idma0_count;
assign w_ing_flush[0]     = i_idma0_flush;

assign w_ing_fifo_stb[0]  = i_idma0_strobe;
assign o_idma0_ready      = r_ing_fifo_rdy[0];
assign w_ing_fifo_act[0]  = i_idma0_activate;
assign o_idma0_size       = r_ing_fifo_size[0];
assign w_ing_fifo_data[0] = i_idma0_data;


//DMA In Interface 1
assign w_ing_enable[1]    = i_idma1_enable;
assign o_idma1_finished   = r_ing_finished[1];
assign w_ing_mem_addr[1]  = i_idma1_addr;
assign w_ing_bsy[1]       = i_idma1_busy;
assign w_ing_count[1]     = i_idma1_count;
assign w_ing_flush[1]     = i_idma1_flush;

assign w_ing_fifo_stb[1]  = i_idma1_strobe;
assign o_idma1_ready      = r_ing_fifo_rdy[1];
assign w_ing_fifo_act[1]  = i_idma1_activate;
assign o_idma1_size       = r_ing_fifo_size[1];
assign w_ing_fifo_data[1] = i_idma1_data;

//DMA Out Interface 0
assign w_egr_enable[0]    = i_odma0_enable;
assign w_egr_mem_addr[0]  = i_odma0_address;
assign w_egr_count[0]     = i_odma0_count;
assign w_egr_flush[0]     = i_odma0_flush;

assign w_egr_fifo_stb[0]  = i_odma0_strobe;
assign o_odma0_data       = r_egr_fifo_data[0];
assign o_odma0_ready      = r_egr_fifo_rdy[0];
assign w_egr_fifo_act[0]  = i_odma0_activate;
assign o_odma0_size       = r_egr_fifo_size[0];

//DMA Out Interface 1
assign w_egr_enable[1]    = i_odma1_enable;
assign w_egr_mem_addr[1]  = i_odma1_address;
assign w_egr_count[1]     = i_odma1_count;
assign w_egr_flush[1]     = i_odma1_flush;

assign w_egr_fifo_stb[1]  = i_odma1_strobe;
assign o_odma1_data       = r_egr_fifo_data[1];
assign o_odma1_ready      = r_egr_fifo_rdy[1];
assign w_egr_fifo_act[1]  = i_odma1_activate;
assign o_odma1_size       = r_egr_fifo_size[1];


assign  w_inout_enable[0] = (w_ing_enable != 0);
assign  w_inout_enable[1] = (w_egr_enable != 0);


assign o_ing_enable       = w_ing_enable;
assign o_egr_enable       = w_egr_enable;
assign o_inout_enable     = w_inout_enable;
assign o_state            = state;


//synchronous logic
integer k;
always @ (posedge clk) begin
  r_ppfifo_2_mem_stb    <=  0;
  r_mem_2_ppfifo_stb    <=  0;
  r_ibuf_go             <=  0;
  r_obuf_go             <=  0;
  r_reset_fifo          <=  0;

  if (rst) begin
    state               <=  IDLE;
    r_ram_addr          <=  0;
    r_ingress_path_en   <=  0;
    r_egress_path_en    <=  0;
    r_ingress_priority  <=  0;
    r_egress_priority   <=  0;
    r_inout_priority    <=  0;
    r_select            <=  0;

    o_ibuf_count        <=  0;
    o_ibuf_start_addrb  <=  0;
    o_ibuf_ddr3_addrb   <=  0;

    o_obuf_count        <=  0;
    o_obuf_start_addra  <=  0;
    o_obuf_ddr3_addra   <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        r_ram_addr        <=  0;
        r_ingress_path_en <=  0;
        r_egress_path_en  <=  0;

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
        r_ingress_path_en       <= 1;
      end
      IDMA_PREPARE: begin
        state                   <= IDMA_CONFIGURE;
        r_ram_addr              <= w_ingress_address;
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
        r_egress_path_en        <= 1;
      end
      ODMA_PREPARE: begin
        //pass through, need to give everything a chance to setup
        state                   <= ODMA_CONFIGURE;
        r_ram_addr              <= w_egress_address;
      end




      //Ingress
      IDMA_CONFIGURE: begin
        //All incomming FIFOs should automatically fill up, need to just wait for initial FIFO to be populated
        if (!w_ingress_enable & w_ingress_inactive) begin
          //Wrote all the data to memory, done
          state                 <= IDLE;
        end
        else if(w_ing_ppfifo_has_data) begin
          //an ingress fifo has been filled up, now start filling up the BRAM
          r_ppfifo_2_mem_stb    <= 1;
          o_ibuf_count          <= w_ing_bram_fifo_size;
          state                 <= IDMA_WAIT_BRAM_START;
          o_ibuf_ddr3_addrb     <= r_ram_addr;
        end
      end
      IDMA_WAIT_BRAM_START: begin
        if (w_adapter_busy) begin
          state                 <=  IDMA_WAIT_BRAM;
        end
      end
      IDMA_WAIT_BRAM: begin
        //Block RAM is filled up. Tell the DDR3 Controller to do it's thing
        if (!w_adapter_busy) begin
          //All the data is in the Block RAM
          r_ibuf_go             <=  1;
          state                 <=  IDMA_WAIT_DDR3_START;
        end
      end
      IDMA_WAIT_DDR3_START: begin
        if (w_ibuf_bsy) begin
          //Wait for any cross clock delays to pass
          state                 <=  IDMA_WAIT_DDR3;
        end
      end
      IDMA_WAIT_DDR3: begin
        //DDR3 Controller is done with this transaction,
        if (!w_ibuf_bsy) begin
          //DDR3 controller is finished go back to configure
          r_ram_addr            <=  r_ram_addr + (o_ibuf_count << 2);
          state                 <=  IDMA_CONFIGURE;
        end
      end



      //Egress
      ODMA_CONFIGURE: begin
        //User has requested data, it really doesn't matter the size. Ask the memory to populate
        //the local block RAM, we can manage the count one 1024 block at a time
        if (!w_egress_enable) begin
          r_reset_fifo            <=  1;
          state                   <=  IDLE;
        end
        else begin
          o_obuf_ddr3_addra       <=  r_ram_addr;
          o_obuf_count            <=  READ_COUNT;
          r_obuf_go               <=  1;
          state                   <=  ODMA_WAIT_DDR3_START;
        end
      end
      ODMA_WAIT_DDR3_START: begin
        //Wait for any cross clock enable to finish
        if (w_obuf_bsy) begin
          state                   <=  ODMA_WAIT_DDR3;
        end
      end
      ODMA_WAIT_DDR3: begin
        //DDR3 has populated the block ram
        //Fill up the PPFIFO
        if (!w_obuf_bsy && w_egr_ppfifo_is_ready) begin
          r_mem_2_ppfifo_stb      <=  1;
          state                   <=  ODMA_WAIT_PPFIFO_START;
        end
      end
      ODMA_WAIT_PPFIFO_START: begin
        //Make sure the ppfifo has started
        if (w_egress_fifo_act != 0) begin
          state                   <=  ODMA_WAIT_PPFIFO;
        end
      end
      ODMA_WAIT_PPFIFO: begin
        //Set the count, if this is the last packet it may not need 1024 32-bit words
        if (w_egress_fifo_act == 0) begin
          r_ram_addr                <=  r_ram_addr + READ_COUNT;
          state                     <=  ODMA_CONFIGURE;
        end
      end

      default: begin
        //Shouldn't get here
        state <=  IDLE;
      end
    endcase
  end
end




endmodule
