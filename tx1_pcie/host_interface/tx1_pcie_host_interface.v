/*
Distributed under the MIT license.
Copyright (c) 2015 Dave McCoy (dave.mccoy@cospandesign.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sel copies
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

module tx1_pcie_host_interface (
  input                       clk,
  input                       rst,

  //Artemis PCIE Interface
  input                       i_sys_rst,
  input                       i_pcie_reset,
  input                       i_pcie_per_fifo_sel,
  input                       i_pcie_mem_fifo_sel,
  input                       i_pcie_dma_fifo_sel,

  output                      o_pcie_write_fin,
  output                      o_pcie_read_fin,

  input           [31:0]      i_pcie_data_size,
  input           [31:0]      i_pcie_data_address,
  input                       i_pcie_data_fifo_flg,
  input                       i_pcie_data_read_flg,
  input                       i_pcie_data_write_flg,

  output                      o_pcie_interrupt_stb,
  output          [31:0]      o_pcie_interrupt_value,

  output                      o_pcie_data_clk,
  input                       i_pcie_ingress_fifo_rdy,
  output                      o_pcie_ingress_fifo_act,
  input           [23:0]      i_pcie_ingress_fifo_size,
  output                      o_pcie_ingress_fifo_stb,
  input           [31:0]      i_pcie_ingress_fifo_data,
  input                       i_pcie_ingress_fifo_idle,

  input           [1:0]       i_pcie_egress_fifo_rdy,
  output          [1:0]       o_pcie_egress_fifo_act,
  input           [23:0]      i_pcie_egress_fifo_size,
  output                      o_pcie_egress_fifo_stb,
  output          [31:0]      o_pcie_egress_fifo_data,

  //Master Interface
  input                       i_master_ready,

  output                      o_ih_reset,
  output                      o_ih_ready,

  output          [31:0]      o_in_command,
  output          [31:0]      o_in_address,
  output          [31:0]      o_in_data,
  output          [27:0]      o_in_data_count,

  output                      o_oh_ready,
  input                       i_oh_en,

  input           [31:0]      i_out_status,
  input           [31:0]      i_out_address,
  input           [31:0]      i_out_data,
  input           [27:0]      i_out_data_count,

  input           [31:0]      i_usr_interrupt_value,

  //Memory Interface
  output                      o_ddr3_cmd_clk,
  output                      o_ddr3_cmd_en,
  output          [2:0]       o_ddr3_cmd_instr,
  output          [5:0]       o_ddr3_cmd_bl,
  output          [29:0]      o_ddr3_cmd_byte_addr,
  input                       i_ddr3_cmd_empty,
  input                       i_ddr3_cmd_full,

  output                      o_ddr3_wr_clk,
  output                      o_ddr3_wr_en,
  output          [3:0]       o_ddr3_wr_mask,
  output          [31:0]      o_ddr3_wr_data,
  input                       i_ddr3_wr_full,
  input                       i_ddr3_wr_empty,
  input           [6:0]       i_ddr3_wr_count,
  input                       i_ddr3_wr_underrun,
  input                       i_ddr3_wr_error,

  output                      o_ddr3_rd_clk,
  output                      o_ddr3_rd_en,
  input           [31:0]      i_ddr3_rd_data,
  input                       i_ddr3_rd_full,
  input                       i_ddr3_rd_empty,
  input           [6:0]       i_ddr3_rd_count,
  input                       i_ddr3_rd_overflow,
  input                       i_ddr3_rd_error,

  //DMA Interface
  input                       i_idma_enable,
  input                       i_idma_flush,
  input                       i_idma_activate,
  output                      o_idma_ready,
  input                       i_idma_stb,
  output          [23:0]      o_idma_size,
  output          [31:0]      o_idma_data,

  input                       i_odma_enable,
  input                       i_odma_flush,
  output          [1:0]       o_odma_ready,
  input           [1:0]       i_odma_activate,
  input                       i_odma_stb,
  output          [23:0]      o_odma_size,
  input           [31:0]      i_odma_data,


  input           [3:0]       i_dbg_sm_state,
  output          [31:0]      o_debug
);
//local parameters
localparam     PARAM1  = 32'h00000000;
//registes/wires
wire                                            w_mem_fin;
wire                                            w_dma_write_fin;
reg                                             r_dma_read_fin;

//DDR3 Controller PPFIFO Interface
wire    [27:0]                                  o_ddr3_cmd_word_addr;

wire                                            w_mem_ingress_rdy;
wire    [23:0]                                  w_mem_ingress_size;
wire                                            w_mem_ingress_act;
wire                                            w_mem_ingress_stb;
wire    [31:0]                                  w_mem_ingress_data;

wire    [1:0]                                   w_mem_egress_rdy;
wire    [1:0]                                   w_mem_egress_act;
wire    [23:0]                                  w_mem_egress_size;
wire                                            w_mem_egress_stb;
wire    [31:0]                                  w_mem_egress_data;

//Ingress
wire                                            w_per_ingress_rdy;
wire                                            w_per_ingress_act;
wire    [23:0]                                  w_per_ingress_size;
wire                                            w_per_ingress_stb;
wire    [31:0]                                  w_per_ingress_data;

//Egress FIFO
wire    [1:0]                                   w_per_egress_rdy;
wire    [1:0]                                   w_per_egress_act;
wire    [23:0]                                  w_per_egress_size;
wire                                            w_per_egress_stb;
wire    [31:0]                                  w_per_egress_data;

//Single PCIE PPFIFO Interface
//submodules
wire                                            w_mem_write_en;
wire                                            w_mem_read_en;

//wire                                            i_pcie_per_fifo_sel;
//wire                                            i_pcie_mem_fifo_sel;
//wire                                            i_pcie_dma_fifo_sel;

wire    [27:0]                                  w_mem_adr;

wire    [1:0]                                   w_ddr3_ingress_rdy;
wire    [23:0]                                  w_ddr3_ingress_size;
wire    [1:0]                                   w_ddr3_ingress_act;
wire                                            w_ddr3_ingress_stb;
wire    [31:0]                                  w_ddr3_ingress_data;

wire                                            w_ddr3_egress_rdy;
wire    [23:0]                                  w_ddr3_egress_size;
wire                                            w_ddr3_egress_act;
wire                                            w_ddr3_egress_stb;
wire    [31:0]                                  w_ddr3_egress_data;
wire                                            w_ddr3_egress_inactive;


wire    [3:0]                                   w_ih_state;
wire    [3:0]                                   w_oh_state;

//wire    [31:0]                                  w_id_value;
//wire    [31:0]                                  w_command_value;
//wire    [31:0]                                  w_count_value;
//wire    [31:0]                                  w_address_value;


//submodules
//DDR3 Memory Controller
ddr3_pcie_controller dc (
  .clk                (clk                     ),
  .rst                (rst                     ),

  .data_size          (i_pcie_data_address             ),
  .write_address      (w_mem_adr               ),
  .write_en           (w_mem_write_en          ),
  .read_address       (w_mem_adr               ),
  .read_en            (w_mem_read_en           ),
  .finished           (w_mem_fin               ),

  .if_write_strobe    (w_ddr3_ingress_stb      ),
  .if_write_data      (w_ddr3_ingress_data     ),
  .if_write_ready     (w_ddr3_ingress_rdy      ),
  .if_write_activate  (w_ddr3_ingress_act      ),
  .if_write_fifo_size (w_ddr3_ingress_size     ),

  .of_read_strobe     (w_ddr3_egress_stb       ),
  .of_read_ready      (w_ddr3_egress_rdy       ),
  .of_read_activate   (w_ddr3_egress_act       ),
  .of_read_size       (w_ddr3_egress_size      ),
  .of_read_data       (w_ddr3_egress_data      ),
  .of_read_inactive   (w_ddr3_egress_inactive  ),

  .cmd_en             (o_ddr3_cmd_en           ),
  .cmd_instr          (o_ddr3_cmd_instr        ),
  .cmd_bl             (o_ddr3_cmd_bl           ),
  .cmd_word_addr      (o_ddr3_cmd_word_addr    ),
  .cmd_empty          (i_ddr3_cmd_empty        ),
  .cmd_full           (i_ddr3_cmd_full         ),

  .wr_en              (o_ddr3_wr_en            ),
  .wr_mask            (o_ddr3_wr_mask          ),
  .wr_data            (o_ddr3_wr_data          ),
  .wr_full            (i_ddr3_wr_full          ),
  .wr_empty           (i_ddr3_wr_empty         ),
  .wr_count           (i_ddr3_wr_count         ),
  .wr_underrun        (i_ddr3_wr_underrun      ),
  .wr_error           (i_ddr3_wr_error         ),

  .rd_en              (o_ddr3_rd_en            ),
  .rd_data            (i_ddr3_rd_data          ),
  .rd_full            (i_ddr3_rd_full          ),
  .rd_empty           (i_ddr3_rd_empty         ),
  .rd_count           (i_ddr3_rd_count         ),
  .rd_overflow        (i_ddr3_rd_overflow      ),
  .rd_error           (i_ddr3_rd_error         )
);

ppfifo_pcie_host_interface phi (
  .rst                (rst              ),
  .clk                (clk              ),

  .i_ing_en           (i_pcie_per_fifo_sel & i_pcie_data_write_flg  ),
  .i_egr_en           (i_pcie_per_fifo_sel & i_pcie_data_read_flg   ),

  .o_ing_fin          (w_ing_per_fin    ),
  .o_egr_fin          (w_egr_per_fin    ),

  .i_sys_rst          (i_sys_rst        ),

  //master interface
  .i_master_ready     (i_master_ready   ),
  .o_ih_reset         (o_ih_reset       ),
  .o_ih_ready         (o_ih_ready       ),

  .o_in_command       (o_in_command     ),
  .o_in_address       (o_in_address     ),
  .o_in_data          (o_in_data        ),
  .o_in_data_count    (o_in_data_count  ),

  .o_oh_ready         (o_oh_ready       ),
  .i_oh_en            (i_oh_en          ),

  .o_ih_state         (w_ih_state       ),
  .o_oh_state         (w_oh_state       ),

  .i_out_status       (i_out_status     ),
  .i_out_address      (i_out_address    ),
  .i_out_data         (i_out_data       ),
  .i_out_data_count   (i_out_data_count ),

/*
  .o_id_value         (w_id_value           ),
  .o_command_value    (w_command_value      ),
  .o_count_value      (w_count_value        ),
  .o_address_value    (w_address_value      ),
*/

  //Ingress Ping Pong
  .i_ingress_rdy      (w_per_ingress_rdy    ),
  .o_ingress_act      (w_per_ingress_act    ),
  .o_ingress_stb      (w_per_ingress_stb    ),
  .i_ingress_size     (w_per_ingress_size   ),
  .i_ingress_data     (w_per_ingress_data   ),

  //Egress Ping Pong
  .i_egress_rdy       (w_per_egress_rdy     ),
  .o_egress_act       (w_per_egress_act     ),
  .o_egress_stb       (w_per_egress_stb     ),
  .i_egress_size      (w_per_egress_size    ),
  .o_egress_data      (w_per_egress_data    )
);

//Memory FIFO Adapter
adapter_ppfifo_2_ppfifo ap2p_to_ddr3 (
  .clk                (clk                ),
  .rst                (rst                ),

  .i_read_ready       (w_mem_ingress_rdy  ),
  .o_read_activate    (w_mem_ingress_act  ),
  .i_read_size        (w_mem_ingress_size ),
  .i_read_data        (w_mem_ingress_data ),
  .o_read_stb         (w_mem_ingress_stb  ),

  .i_write_ready      (w_ddr3_ingress_rdy ),
  .o_write_activate   (w_ddr3_ingress_act ),
  .i_write_size       (w_ddr3_ingress_size),
  .o_write_stb        (w_ddr3_ingress_stb ),
  .o_write_data       (w_ddr3_ingress_data)
);

adapter_ppfifo_2_ppfifo ap2p_from_ddr3 (
  .clk                (clk                ),
  .rst                (rst                ),

  .i_read_ready       (w_ddr3_egress_rdy  ),
  .o_read_activate    (w_ddr3_egress_act  ),
  .i_read_size        (w_ddr3_egress_size ),
  .i_read_data        (w_ddr3_egress_data ),
  .o_read_stb         (w_ddr3_egress_stb  ),

  .i_write_ready      (w_mem_egress_rdy   ),
  .o_write_activate   (w_mem_egress_act   ),
  .i_write_size       (w_mem_egress_size  ),
  .o_write_stb        (w_mem_egress_stb   ),
  .o_write_data       (w_mem_egress_data  )
);

//Asynchronous Logic
assign  o_ddr3_cmd_clk              = clk;
assign  o_ddr3_wr_clk               = clk;
assign  o_ddr3_rd_clk               = clk;
assign  o_ddr3_cmd_byte_addr        = {o_ddr3_cmd_word_addr, 2'b0};
assign  o_pcie_data_clk             = clk;


//XXX: This needs to be added in the future
assign  o_pcie_interrupt_stb        = 1'b0;
assign  o_pcie_interrupt_value      = 0;


//Ingress PPFIFO
//Interface to Master

//PPFIFO Multiplexer/Demultiplexer
assign w_per_ingress_rdy       = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_rdy :  1'b0;
assign w_per_ingress_size      = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_size:  24'h0;
assign w_per_ingress_data      = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_data:  32'h0;

assign w_mem_ingress_rdy       = (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_rdy :  1'b0;
assign w_mem_ingress_size      = (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_size:  24'h0;
assign w_mem_ingress_data      = (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_data:  32'h0;

assign o_idma_ready            = (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_rdy :  1'b0;
assign o_idma_size             = (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_size:  24'h0;
assign o_idma_data             = (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? i_pcie_ingress_fifo_data:  32'h0;

assign o_pcie_ingress_fifo_act = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? w_per_ingress_act :
                                 (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? w_mem_ingress_act :
                                 (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? i_idma_activate :
                                 1'b0;
assign o_pcie_ingress_fifo_stb = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? w_per_ingress_stb :
                                 (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? w_mem_ingress_stb :
                                 (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? i_idma_stb :
                                 1'b0;

//Egress FIFO
assign w_per_egress_rdy        = (i_pcie_per_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_rdy :  2'b0;
assign w_mem_egress_rdy        = (i_pcie_mem_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_rdy :  2'b0;
assign o_odma_ready            = (i_pcie_dma_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_rdy :  2'b0;

assign w_per_egress_size       = (i_pcie_per_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_size:  24'h0;
assign w_mem_egress_size       = (i_pcie_mem_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_size:  24'h0;
assign o_odma_size             = (i_pcie_dma_fifo_sel & i_pcie_data_read_flg) ? i_pcie_egress_fifo_size:  24'h0;

assign o_pcie_egress_fifo_act  = (i_pcie_per_fifo_sel & i_pcie_data_read_flg) ? w_per_egress_act  :
                                 (i_pcie_mem_fifo_sel & i_pcie_data_read_flg) ? w_mem_egress_act  :
                                 (i_pcie_dma_fifo_sel & i_pcie_data_read_flg) ? i_odma_activate   :
                                 1'b0;
assign o_pcie_egress_fifo_data = (i_pcie_per_fifo_sel & i_pcie_data_read_flg) ? w_per_egress_data :
                                 (i_pcie_mem_fifo_sel & i_pcie_data_read_flg) ? w_mem_egress_data :
                                 (i_pcie_dma_fifo_sel & i_pcie_data_read_flg) ? i_odma_data       :
                                 1'b0;
assign o_pcie_egress_fifo_stb  = (i_pcie_per_fifo_sel & i_pcie_data_read_flg) ? w_per_egress_stb  :
                                 (i_pcie_mem_fifo_sel & i_pcie_data_read_flg) ? w_mem_egress_stb  :
                                 (i_pcie_dma_fifo_sel & i_pcie_data_read_flg) ? i_odma_stb        :
                                 1'b0;

//XXX: This may need to be changed for increased memory size
assign w_mem_adr             = i_pcie_data_size[27:0];
assign w_mem_write_en        = i_pcie_data_write_flg & i_pcie_mem_fifo_sel;
assign w_mem_read_en         = i_pcie_data_read_flg  & i_pcie_mem_fifo_sel;


assign o_pcie_write_fin      = (i_pcie_per_fifo_sel & i_pcie_data_write_flg) ? w_ing_per_fin   :
                               (i_pcie_mem_fifo_sel & i_pcie_data_write_flg) ? w_mem_fin       :
                               (i_pcie_dma_fifo_sel & i_pcie_data_write_flg) ? w_dma_write_fin :
                               1'b0;

assign o_pcie_read_fin       = (i_pcie_per_fifo_sel & i_pcie_data_read_flg)  ? w_egr_per_fin   :
                               (i_pcie_mem_fifo_sel & i_pcie_data_read_flg)  ? (w_mem_fin  & w_ddr3_egress_inactive):
                               (i_pcie_dma_fifo_sel & i_pcie_data_read_flg)  ? r_dma_read_fin  :
                               1'b0;


assign w_dma_write_fin        = i_pcie_ingress_fifo_idle;


assign o_debug[0]      = i_pcie_data_read_flg;
assign o_debug[1]      = i_pcie_data_write_flg;
assign o_debug[2]      = i_pcie_dma_fifo_sel;
assign o_debug[3]      = i_oh_en;
assign o_debug[4]      = i_pcie_per_fifo_sel;
assign o_debug[5]      = w_ing_per_fin;
assign o_debug[6]      = o_pcie_write_fin;
assign o_debug[7]      = w_per_egress_stb;
assign o_debug[8]      = i_master_ready;
assign o_debug[9]      = 1'b0;
assign o_debug[10]     = o_ih_ready;
assign o_debug[11]     = o_oh_ready;
assign o_debug[15:12]  = w_oh_state;
assign o_debug[17:16]  = w_per_egress_act;
//assign o_debug[5]      = o_pcie_ingress_fifo_stb;
//assign o_debug[6]      = o_pcie_ingress_fifo_act;
//assign o_debug[7]      = i_pcie_ingress_fifo_rdy;
//assign o_debug[8]      = o_pcie_egress_fifo_stb;
//assign o_debug[10:9]   = o_pcie_egress_fifo_act;
//assign o_debug[12:11]  = i_pcie_egress_fifo_rdy;
//assign o_debug[13]     = w_per_egress_stb;
//assign o_debug[15:14]  = w_per_egress_act;
//assign o_debug[17:16]  = w_per_egress_rdy;
assign o_debug[18]     = w_per_ingress_stb;
assign o_debug[19]     = w_per_ingress_act;
assign o_debug[20]     = w_per_ingress_rdy;
assign o_debug[24:21]  = w_ih_state;
assign o_debug[26:25]  = o_in_command;
//assign o_debug[30:27]  = o_in_data;
assign o_debug[30:27]  = i_dbg_sm_state;
assign o_debug[31]     = w_egr_per_fin;


reg   [31:0]                  r_dma_count;
always @ (posedge clk) begin
  if (rst) begin
    r_dma_count               <=  0;
    r_dma_read_fin            <=  0;
  end
  else begin
    if (i_pcie_data_read_flg & i_pcie_dma_fifo_sel) begin
      if (r_dma_count < i_pcie_data_address) begin
        if (i_odma_stb) begin
          r_dma_count           <=  r_dma_count + 1;
        end
      end
      else begin
        r_dma_read_fin          <=  1;
      end
    end
    else begin
      r_dma_count               <=  0;
      r_dma_read_fin            <=  0;
    end
  end
end


//synchronous logic
endmodule
