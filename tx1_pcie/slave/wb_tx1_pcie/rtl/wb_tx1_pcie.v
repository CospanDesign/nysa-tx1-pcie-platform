//wb_tx1_pcie.v
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

/*
  Set the Vendor ID (Hexidecimal 64-bit Number)
  SDB_VENDOR_ID:0x800000000000C594

  Set the Device ID (Hexcidecimal 32-bit Number)
  SDB_DEVICE_ID:0x800000000000C594

  Set the version of the Core XX.XXX.XXX Example: 01.000.000
  SDB_CORE_VERSION:00.000.001

  Set the Device Name: 19 UNICODE characters
  SDB_NAME:wb_tx1_pcie

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x0F

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0

  Set the Module URL (63 Unicode Characters)
  SDB_MODULE_URL:http://www.example.com

  Set the date of module YYYY/MM/DD
  SDB_DATE:2016/06/21

  Device is executable (True/False)
  SDB_EXECUTABLE:True

  Device is readable (True/False)
  SDB_READABLE:True

  Device is writeable (True/False)
  SDB_WRITEABLE:True

  Device Size: Number of Registers
  SDB_SIZE:3
*/
`include "project_defines.v"

`define CTRL_BIT_SOURCE_EN      0
`define CTRL_BIT_CANCEL_WRITE   1
`define CTRL_BIT_SINK_EN        2


`define STS_BIT_LINKUP          0
`define STS_BIT_READ_IDLE       1
`define STS_PER_FIFO_SEL        2
`define STS_MEM_FIFO_SEL        3
`define STS_DMA_FIFO_SEL        4
`define STS_WRITE_EN            5
`define STS_READ_EN             6


`define LOCAL_BUFFER_OFFSET         24'h000100

module wb_tx1_pcie #(
  parameter           DATA_INGRESS_FIFO_DEPTH = 10,
  parameter           DATA_EGRESS_FIFO_DEPTH  = 6,
  parameter           CONTROL_FIFO_DEPTH      = 7
) (
  input               clk,
  input               rst,
//  output              o_sys_rst,

  //Add signals to control your device here

  //Wishbone Bus Signals
  input               i_wbs_we,
  input               i_wbs_cyc,
  input       [3:0]   i_wbs_sel,
  input       [31:0]  i_wbs_dat,
  input               i_wbs_stb,
  output  reg         o_wbs_ack,
  output  reg [31:0]  o_wbs_dat,
  input       [31:0]  i_wbs_adr,

  output              o_pcie_reset,
  output              o_pcie_per_fifo_sel,
  output              o_pcie_mem_fifo_sel,
  output              o_pcie_dma_fifo_sel,

  input               i_pcie_write_fin,
  input               i_pcie_read_fin,

  output      [31:0]  o_pcie_data_size,
  output      [31:0]  o_pcie_data_address,
  output              o_pcie_data_fifo_flg,
  output              o_pcie_data_read_flg,
  output              o_pcie_data_write_flg,

  input               i_pcie_interrupt_stb,
  input       [31:0]  i_pcie_interrupt_value,

  input               i_pcie_data_clk,
  output              o_pcie_ingress_fifo_rdy,
  input               i_pcie_ingress_fifo_act,
  output      [23:0]  o_pcie_ingress_fifo_size,
  input               i_pcie_ingress_fifo_stb,
  output      [31:0]  o_pcie_ingress_fifo_data,
  output              o_pcie_ingress_fifo_idle,

  output      [1:0]   o_pcie_egress_fifo_rdy,
  input       [1:0]   i_pcie_egress_fifo_act,
  output      [23:0]  o_pcie_egress_fifo_size,
  input               i_pcie_egress_fifo_stb,
  input       [31:0]  i_pcie_egress_fifo_data,

  //DEBUG
  output      [3:0]   o_sm_state,

  // Tx
  output              o_pcie_exp_tx_p,
  output              o_pcie_exp_tx_n,

  // Rx
  input               i_pcie_exp_rx_p,
  input               i_pcie_exp_rx_n,

  input               i_pcie_clk_p,
  input               i_pcie_clk_n,

  //PCIE Control
  input               i_pcie_reset_n,
//  output              o_pcie_wake_n,
  input               i_pcie_wake_n,
  output              o_lax_clk,
  output      [31:0]  o_debug,
  output              o_pcie_clkreq,
  output  reg         o_wbs_int
);

//Local Parameters
localparam  CONTROL             = 32'h00;
localparam  STATUS              = 32'h01;

//Local Registers/Wires
wire                    w_sys_rst;
wire                    w_user_link_up;
wire                    w_user_reset_out;

/*
wire        [15:0]      w_cfg_status;
wire        [15:0]      w_cfg_command;
wire        [15:0]      w_cfg_dstatus;
wire        [15:0]      w_cfg_dcommand;
wire        [15:0]      w_cfg_lstatus;
wire        [15:0]      w_cfg_lcommand;
wire        [15:0]      w_cfg_dcommand2;
wire        [2:0]       w_cfg_pcie_link_state;
*/
wire        [5:0]       w_pl_ltssm_state;

wire                    w_clock_locked;
wire                    o_clk_in_stopped;

wire        [2:0]       pipe_rx0_status_gt;
wire                    pipe_rx0_phy_status_gt;
wire        [3:0]       w_tx_diff_ctr;

wire                    w_pl_sel_lnk_rate;
wire        [1:0]       w_pl_sel_lnk_width;
wire        [2:0]       w_pl_initial_link_width;

wire        [15:0]      w_rx_data;
wire        [1:0]       w_rx_data_k;

wire                    w_out_en;
wire        [31:0]      w_out_status;
wire        [31:0]      w_out_address;
wire        [31:0]      w_out_data;
wire        [27:0]      w_out_data_count;
wire                    w_master_ready;

wire                    w_in_ready;
wire        [31:0]      w_in_command;
wire        [31:0]      w_in_address;
wire        [31:0]      w_in_data;
wire        [27:0]      w_in_data_count;
wire                    w_out_ready;
wire                    w_ih_reset;

wire        [31:0]      w_id_value;
wire        [31:0]      w_command_value;
wire        [31:0]      w_count_value;
wire        [31:0]      w_address_value;

wire        [63:0]      m64_axis_rx_tdata;
wire        [7:0]       m64_axis_rx_tkeep;
wire                    m64_axis_rx_tlast;
wire                    m64_axis_rx_tvalid;
wire                    m64_axis_rx_tready;
wire        [21:0]      m_axis_rx_tuser;

wire        [31:0]      m32_axis_rx_tdata;
wire        [3:0]       m32_axis_rx_tkeep;
wire                    m32_axis_rx_tlast;
wire                    m32_axis_rx_tvalid;
wire                    m32_axis_rx_tready;

wire                    s64_axis_tx_tready;
wire        [63:0]      s64_axis_tx_tdata;
wire        [7:0]       s64_axis_tx_tkeep;
wire                    s64_axis_tx_tlast;
wire                    s64_axis_tx_tvalid;

wire                    s32_axis_tx_tready;
wire        [31:0]      s32_axis_tx_tdata;
wire        [3:0]       s32_axis_tx_tkeep;
wire                    s32_axis_tx_tlast;
wire                    s32_axis_tx_tvalid;

wire        [3:0]       ingress_state;
wire        [3:0]       egress_state;
wire        [3:0]       controller_state;

//Submodules
tx1_pcie_adapter pcie_adapter (
  .clk                      (clk                          ),
  .rst                      (rst                          ),
  .o_user_link_up           (w_user_link_up               ),
  .o_sys_rst                (w_sys_rst                    ),

  /******************************************
  * Debug Interface                         *
  ******************************************/
  .o_lax_clk                (w_lax_clk                    ),
  .o_user_reset_out         (w_user_reset_out             ),
  .o_pl_ltssm_state         (w_pl_ltssm_state             ),
  .pipe_rx0_status_gt       (pipe_rx0_status_gt           ),
  .pipe_rx0_phy_status_gt   (pipe_rx0_phy_status_gt       ),

  .o_clock_locked           (w_clock_locked               ),
  .o_clk_in_stopped         (o_clk_in_stopped             ),

  .i_tx_diff_ctr            (w_tx_diff_ctr                ),

  .o_pl_sel_lnk_rate        (w_pl_sel_lnk_rate            ),
  .o_pl_sel_lnk_width       (w_pl_sel_lnk_width           ),
  .o_pl_initial_link_width  (w_pl_initial_link_width      ),

/*
  .o_cfg_status             (w_cfg_status                 ),
  .o_cfg_command            (w_cfg_command                ),
  .o_cfg_dstatus            (w_cfg_dstatus                ),
  .o_cfg_dcommand           (w_cfg_dcommand               ),
  .o_cfg_lstatus            (w_cfg_lstatus                ),
  .o_cfg_lcommand           (w_cfg_lcommand               ),
  .o_cfg_dcommand2          (w_cfg_dcommand2              ),
  .o_cfg_pcie_link_state    (w_cfg_pcie_link_state        ),
*/

  .m64_axis_rx_tdata       (m64_axis_rx_tdata             ),
  .m64_axis_rx_tkeep       (m64_axis_rx_tkeep             ),
  .m64_axis_rx_tlast       (m64_axis_rx_tlast             ),
  .m64_axis_rx_tvalid      (m64_axis_rx_tvalid            ),
  .m64_axis_rx_tready      (m64_axis_rx_tready            ),
  .m_axis_rx_tuser         (maxis_rx_tuser                ),

  .m32_axis_rx_tdata       (m32_axis_rx_tdata             ),
  .m32_axis_rx_tkeep       (m32_axis_rx_tkeep             ),
  .m32_axis_rx_tlast       (m32_axis_rx_tlast             ),
  .m32_axis_rx_tvalid      (m32_axis_rx_tvalid            ),
  .m32_axis_rx_tready      (m32_axis_rx_tready            ),

  .s64_axis_tx_tdata       (s64_axis_tx_tdata             ),
  .s64_axis_tx_tkeep       (s64_axis_tx_tkeep             ),
  .s64_axis_tx_tlast       (s64_axis_tx_tlast             ),
  .s64_axis_tx_tvalid      (s64_axis_tx_tvalid            ),
  .s64_axis_tx_tready      (s64_axis_tx_tready            ),

  .s32_axis_tx_tdata       (s32_axis_tx_tdata             ),
  .s32_axis_tx_tkeep       (s32_axis_tx_tkeep             ),
  .s32_axis_tx_tlast       (s32_axis_tx_tlast             ),
  .s32_axis_tx_tvalid      (s32_axis_tx_tvalid            ),
  .s32_axis_tx_tready      (s32_axis_tx_tready            ),

  .o_ingress_state         (ingress_state                 ),
  .o_egress_state          (egress_state                  ),
  .o_controller_state      (controller_state              ),


  /******************************************
  * PCIE Phy Interface                      *
  ******************************************/

  // Tx
  .o_pcie_exp_tx_p          (o_pcie_exp_tx_p              ),
  .o_pcie_exp_tx_n          (o_pcie_exp_tx_n              ),

  // Rx
  .i_pcie_exp_rx_p          (i_pcie_exp_rx_p              ),
  .i_pcie_exp_rx_n          (i_pcie_exp_rx_n              ),

  .i_pcie_clk_p             (i_pcie_clk_p                 ),
  .i_pcie_clk_n             (i_pcie_clk_n                 ),

  .o_rx_data                (w_rx_data                    ),
  .o_rx_data_k              (w_rx_data_k                  ),

  .o_rx_byte_is_comma       (w_rx_byte_is_comma           ),
  .o_rx_byte_is_aligned     (w_rx_byte_is_aligned         ),


  //PCIE Control control
  .i_pcie_reset_n           (i_pcie_reset_n               ),
  .o_pcie_clkreq            (o_pcie_clkreq                ),


  /******************************************
  * Host Interface                          *
  ******************************************/
  .o_per_fifo_sel           (o_pcie_per_fifo_sel          ),
  .o_mem_fifo_sel           (o_pcie_mem_fifo_sel          ),
  .o_dma_fifo_sel           (o_pcie_dma_fifo_sel          ),

  .i_write_fin              (i_pcie_write_fin             ),
  .i_read_fin               (i_pcie_read_fin              ),

  .o_data_size              (o_pcie_data_size             ),
  .o_data_address           (o_pcie_data_address          ),
  .o_data_fifo_flg          (o_pcie_data_fifo_flg         ),
  .o_data_read_flg          (o_pcie_data_read_flg         ),
  .o_data_write_flg         (o_pcie_data_write_flg        ),

  .i_usr_interrupt_stb      (i_pcie_interrupt             ),
  .i_usr_interrupt_value    (i_pcie_interrupt_value       ),

  //Ingress FIFO
  .i_data_clk               (i_pcie_data_clk              ),
  .o_ingress_fifo_rdy       (o_pcie_ingress_fifo_rdy      ),
  .i_ingress_fifo_act       (i_pcie_ingress_fifo_act      ),
  .o_ingress_fifo_size      (o_pcie_ingress_fifo_size     ),
  .i_ingress_fifo_stb       (i_pcie_ingress_fifo_stb      ),
  .o_ingress_fifo_data      (o_pcie_ingress_fifo_data     ),
  .o_ingress_fifo_idle      (o_pcie_ingress_fifo_idle     ),

  //Egress FIFO
  .o_egress_fifo_rdy        (o_pcie_egress_fifo_rdy       ),
  .i_egress_fifo_act        (i_pcie_egress_fifo_act       ),
  .o_egress_fifo_size       (o_pcie_egress_fifo_size      ),
  .i_egress_fifo_stb        (i_pcie_egress_fifo_stb       ),
  .i_egress_fifo_data       (i_pcie_egress_fifo_data      )
);


assign  o_lax_clk   = w_lax_clk;

//Asynchronous Logic

/*
//LINKUP Debug
assign  o_debug[15:0]   = w_rx_data;
assign  o_debug[17:16]  = w_rx_data_k;
assign  o_debug[20:18]  = pipe_rx0_status_gt;
assign  o_debug[21]     = pipe_rx0_phy_status_gt;
assign  o_debug[23:22]  = w_rx_byte_is_comma;
assign  o_debug[29:24]  = w_pl_ltssm_state;
//assign  o_debug[31:30]  = w_rx_byte_is_aligned;
assign  o_debug[30]     = w_rx_byte_is_aligned;
assign  o_debug[31]     = w_clock_locked;
*/

/*
//PCIE Comm Incomming Debug
//assign  o_debug[15:0]   = m64_axis_rx_tdata[15:0];
assign  o_debug[15:0]   = m32_axis_rx_tdata[15:0];
//assign  o_debug[15:0]   = m32_axis_rx_tdata[31:16];
assign  o_debug[19:16]  = m32_axis_rx_tkeep[3:0];
assign  o_debug[20]     = m32_axis_rx_tvalid;
assign  o_debug[21]     = m32_axis_rx_tready;
assign  o_debug[22]     = m32_axis_rx_tlast;
assign  o_debug[23]     = 1'b0;

assign  o_debug[27:24]  = ingress_state;
assign  o_debug[31:28]  = controller_state;
*/



/*
assign  o_debug[28]     = m32_axis_rx_tvalid;
assign  o_debug[29]     = m32_axis_rx_tready;
assign  o_debug[30]     = m32_axis_rx_tlast;
assign  o_debug[31]     = 1'b0;
*/

//assign  o_debug[15:0]   = s64_axis_tx_tdata[15:0];
//assign  o_debug[15:0]   = s32_axis_tx_tdata[15:0];
assign  o_debug[15:0]   = s32_axis_tx_tdata[31:16];
//assign  o_debug[19:16]  = s32_axis_tx_tkeep[3:0];
assign  o_debug[19:16]  = s32_axis_tx_tkeep[3:0];
assign  o_debug[20]     = s32_axis_tx_tvalid;
assign  o_debug[21]     = s32_axis_tx_tready;
assign  o_debug[22]     = s32_axis_tx_tlast;
assign  o_debug[23]     = s64_axis_tx_tvalid;;

//assign  o_debug[27:24]  = ingress_state;
assign  o_debug[27:24]  = egress_state;
assign  o_debug[31:28]  = controller_state;




//assign  o_pcie_reset    = w_user_reset_out;
assign  o_pcie_reset    = w_sys_rst;

assign  w_tx_diff_ctr   = 4'hC;
//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin
    o_wbs_dat     <= 32'h0;
    o_wbs_ack     <= 0;
    o_wbs_int     <= 0;
  end
  else begin
    //when the master acks our ack, then put our ack down
    if (o_wbs_ack && ~i_wbs_stb)begin
      o_wbs_ack <= 0;
    end

    if (i_wbs_stb && i_wbs_cyc) begin
      //master is requesting somethign
      if (!o_wbs_ack) begin
        if (i_wbs_we) begin
          //write request
          case (i_wbs_adr)
            CONTROL: begin
              $display("ADDR: %h user wrote %h", i_wbs_adr, i_wbs_dat);
            end
            //add as many ADDR_X you need here
            default: begin
            end
          endcase
          o_wbs_ack                                 <= 1;
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              o_wbs_dat <= 0;
            end
            STATUS: begin
              o_wbs_dat <= 0;
            end
            default: begin
            end
          endcase
          o_wbs_ack               <=  1;
        end
      end
    end
  end
end

endmodule
