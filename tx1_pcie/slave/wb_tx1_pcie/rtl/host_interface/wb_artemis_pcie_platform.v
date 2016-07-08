//wb_artemis_pcie_platform.v
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
  SDB_NAME:wb_artemis_pcie_platform

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x0F

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0

  Set the Module URL (63 Unicode Characters)
  SDB_MODULE_URL:http://www.example.com

  Set the date of module YYYY/MM/DD
  SDB_DATE:2015/12/20

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

module wb_artemis_pcie_platform #(
  parameter           DATA_INGRESS_FIFO_DEPTH = 10,
  parameter           DATA_EGRESS_FIFO_DEPTH  = 6,
  parameter           CONTROL_FIFO_DEPTH = 7
) (
  input               clk,
  input               rst,
  output              o_sys_rst,

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

  output      [31:0]  o_debug_data,
  //This interrupt can be controlled from this module or a submodule
  output  reg         o_wbs_int,

  //Host Interface
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

  //PCIE Physical Signals
  input               i_clk_100mhz_gtp_p,
  input               i_clk_100mhz_gtp_n,

  output              o_pcie_phy_tx_p,
  output              o_pcie_phy_tx_n,

  input               i_pcie_phy_rx_p,
  input               i_pcie_phy_rx_n,

  input               i_pcie_reset_n,
  output              o_pcie_wake_n
);

//Local Parameters
localparam  CONTROL             = 32'h00;
localparam  STATUS              = 32'h01;
localparam  CFG_READ_EXEC       = 32'h02;
localparam  CFG_SM_STATE        = 32'h03;
localparam  CTR_SM_STATE        = 32'h04;
localparam  INGRESS_COUNT       = 32'h05;
localparam  INGRESS_STATE       = 32'h06;
localparam  INGRESS_RI_COUNT    = 32'h07;
localparam  INGRESS_CI_COUNT    = 32'h08;
localparam  INGRESS_ADDR        = 32'h09;
localparam  INGRESS_CMPLT_COUNT = 32'h0A;
localparam  IH_STATE            = 32'h0B;
localparam  OH_STATE            = 32'h0C;
localparam  BRAM_NUM_READS      = 32'h0D;
localparam  LOCAL_BUFFER_SIZE   = 32'h0E;
localparam  DBG_ID_VALUE        = 32'h0F;
localparam  DBG_COMMAND_VALUE   = 32'h10;
localparam  DBG_COUNT_VALUE     = 32'h11;
localparam  DBG_ADDRESS_VALUE   = 32'h12;

localparam  CONTROL_BUFFER_SIZE = 2 ** CONTROL_FIFO_DEPTH;

//Local Registers/Wires
reg               r_mem_2_ppfifo_stb;
reg               r_snk_en;


wire              w_out_en;
wire  [31:0]      w_out_status;
wire  [31:0]      w_out_address;
wire  [31:0]      w_out_data;
wire  [27:0]      w_out_data_count;
wire              w_master_ready;

wire              w_in_ready;
wire  [31:0]      w_in_command;
wire  [31:0]      w_in_address;
wire  [31:0]      w_in_data;
wire  [27:0]      w_in_data_count;
wire              w_out_ready;
wire              w_ih_reset;

//Submodules
  //Memory Interface
  //DDR3 Control Signals
//wire      [3:0]      w_ih_state;
//wire      [3:0]      w_oh_state;



wire                  w_lcl_mem_en;

wire      [31:0]      w_id_value;
wire      [31:0]      w_command_value;
wire      [31:0]      w_count_value;
wire      [31:0]      w_address_value;

//assign  w_lcl_mem_en            = ((i_wbs_adr >= `LOCAL_BUFFER_OFFSET) &&
//                                   (i_wbs_adr < (`LOCAL_BUFFER_OFFSET + CONTROL_BUFFER_SIZE)));

//assign  w_bram_addr             = w_lcl_mem_en ? (i_wbs_adr - `LOCAL_BUFFER_OFFSET) : 0;

artemis_pcie_controller #(
  .DATA_INGRESS_FIFO_DEPTH           (10                           ),
  .DATA_EGRESS_FIFO_DEPTH            (6                            ),
  .SERIAL_NUMBER                     (64'h000000000000C594         )
)api (
  .clk                               (clk                          ), //User Clock
  .rst                               (rst                          ), //User Reset
  .o_sys_rst                         (o_sys_rst                    ),

  //PCIE Phy Interface
  .gtp_clk_p                         (i_clk_100mhz_gtp_p           ),
  .gtp_clk_n                         (i_clk_100mhz_gtp_n           ),

  .pci_exp_txp                       (o_pcie_phy_tx_p              ),
  .pci_exp_txn                       (o_pcie_phy_tx_n              ),
  .pci_exp_rxp                       (i_pcie_phy_rx_p              ),
  .pci_exp_rxn                       (i_pcie_phy_rx_n              ),

  // Transaction (TRN) Interface
  .o_pcie_reset                      (o_pcie_reset                 ),
  .user_lnk_up                       (user_lnk_up                  ),
  .clk_62p5                          (clk_62p5                     ),
  .i_pcie_reset                      (!i_pcie_reset_n              ),

  //User Interfaces
  .o_per_fifo_sel                    (o_pcie_per_fifo_sel          ),
  .o_mem_fifo_sel                    (o_pcie_mem_fifo_sel          ),
  .o_dma_fifo_sel                    (o_pcie_dma_fifo_sel          ),

  .i_write_fin                       (i_pcie_write_fin             ),
  .i_read_fin                        (i_pcie_read_fin              ),

  .i_usr_interrupt_stb               (i_pcie_interrupt             ),
  .i_usr_interrupt_value             (i_pcie_interrupt_value       ),

  .o_data_size                       (o_pcie_data_size             ),
  .o_data_address                    (o_pcie_data_address          ),
  .o_data_fifo_flg                   (o_pcie_data_fifo_flg         ),
  .o_data_read_flg                   (o_pcie_data_read_flg         ),
  .o_data_write_flg                  (o_pcie_data_write_flg        ),

  //Ingress FIFO
  .i_data_clk                        (i_pcie_data_clk              ),
  .o_ingress_fifo_rdy                (o_pcie_ingress_fifo_rdy      ),
  .i_ingress_fifo_act                (i_pcie_ingress_fifo_act      ),
  .o_ingress_fifo_size               (o_pcie_ingress_fifo_size     ),
  .i_ingress_fifo_stb                (i_pcie_ingress_fifo_stb      ),
  .o_ingress_fifo_data               (o_pcie_ingress_fifo_data     ),
  .o_ingress_fifo_idle               (o_pcie_ingress_fifo_idle     ),

  //Egress FIFO
  .o_egress_fifo_rdy                 (o_pcie_egress_fifo_rdy       ),
  .i_egress_fifo_act                 (i_pcie_egress_fifo_act       ),
  .o_egress_fifo_size                (o_pcie_egress_fifo_size      ),
  .i_egress_fifo_stb                 (i_pcie_egress_fifo_stb       ),
  .i_egress_fifo_data                (i_pcie_egress_fifo_data      ),

  // Configuration: Power Management
  .cfg_turnoff_ok                    (1'b0                         ),
  .cfg_pm_wake                       (1'b0                         ),

  // System Interface
//  .received_hot_reset                (received_hot_reset           ),
//  .gtp_pll_lock_detect               (gtp_pll_lock_detect          ),
//  .gtp_reset_done                    (gtp_reset_done               ),
//  .pll_lock_detect                   (pll_lock_detect              ),

//  .rx_elec_idle                      (rx_elec_idle                 ),
  .rx_equalizer_ctrl                 (2'b11                        ),

  .tx_diff_ctrl                      (4'h9                         ),
  .tx_pre_emphasis                   (3'b00                        ),


//  .o_cfg_read_exec                   (o_cfg_read_exec              ),
//  .o_cfg_sm_state                    (o_cfg_sm_state               ),
  .o_sm_state                        (o_sm_state                   ),
//  .o_ingress_count                   (o_ingress_count              ),
//  .o_ingress_state                   (o_ingress_state              ),
//  .o_ingress_ri_count                (o_ingress_ri_count           ),
//  .o_ingress_ci_count                (o_ingress_ci_count           ),
//  .o_ingress_cmplt_count             (o_ingress_cmplt_count        ),
//  .o_ingress_addr                    (o_ingress_addr               ),


  // Configuration: Error
  .cfg_err_ur                        (1'b0                         ),
  .cfg_err_cor                       (1'b0                         ),
  .cfg_err_ecrc                      (1'b0                         ),
  .cfg_err_cpl_timeout               (1'b0                         ),
  .cfg_err_cpl_abort                 (1'b0                         ),
  .cfg_err_posted                    (1'b0                         ),
  .cfg_err_locked                    (1'b0                         ),
  .cfg_err_tlp_cpl_header            (48'b0                        )
  //.cfg_err_cpl_rdy                   (cfg_err_cpl_rdy              )
);


assign  o_pcie_wake_n = 1'b1;

always @ (posedge clk) begin
  //r_mem_2_ppfifo_stb      <= 0;
  //r_cancel_write_stb      <= 0;
  //r_bram_we               <=  0;
  if (rst) begin
    o_wbs_dat             <= 32'h0;
    o_wbs_ack             <= 0;
    o_wbs_int             <= 0;
//    r_bram_din            <= 0;

    r_snk_en              <= 1;
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
              //r_mem_2_ppfifo_stb                  <=  i_wbs_dat[`CTRL_BIT_SOURCE_EN];
              //r_cancel_write_stb                  <=  i_wbs_dat[`CTRL_BIT_CANCEL_WRITE];
              r_snk_en                            <=  i_wbs_dat[`CTRL_BIT_SINK_EN];
            end
            default: begin
/*
              if (w_lcl_mem_en) begin
                r_bram_we                          <=  1;
                r_bram_din                         <=  i_wbs_dat;
              end
*/

            end
          endcase
          o_wbs_ack                                 <= 1;
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              o_wbs_dat <= 0;
              //o_wbs_dat[`CTRL_BIT_SOURCE_EN]      <= r_mem_2_ppfifo_stb;
              //o_wbs_dat[`CTRL_BIT_CANCEL_WRITE]   <= r_cancel_write_stb;
              o_wbs_dat[`CTRL_BIT_SINK_EN]        <= r_snk_en;

            end
            STATUS: begin
              o_wbs_dat <= 0;
              //o_wbs_dat[`STS_BIT_LINKUP]          <=  w_user_lnk_up;
              //o_wbs_dat[`STS_BIT_READ_IDLE]       <=  w_read_idle;

/*
              o_wbs_dat[`STS_PER_FIFO_SEL]        <=  w_per_fifo_sel;
              o_wbs_dat[`STS_MEM_FIFO_SEL]        <=  w_mem_fifo_sel;
              o_wbs_dat[`STS_DMA_FIFO_SEL]        <=  w_dma_fifo_sel;
              o_wbs_dat[`STS_WRITE_EN]            <=  w_write_flag;
              o_wbs_dat[`STS_READ_EN]             <=  w_read_flag;
*/

            end
/*
            CFG_READ_EXEC: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_cfg_read_exec;
            end
            CFG_SM_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_cfg_sm_state;
            end
            CTR_SM_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_sm_state;
            end
            INGRESS_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_count;
            end
            INGRESS_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_ingress_state;
            end
            INGRESS_RI_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_ri_count;
            end
            INGRESS_CI_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_ci_count;
            end
            INGRESS_ADDR: begin
              o_wbs_dat <= 0;
              o_wbs_dat[31:0]  <=  o_ingress_addr;
            end
            INGRESS_CMPLT_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[31:0]  <=  o_ingress_cmplt_count;
            end
            IH_STATE: begin
              o_wbs_dat         <= 0;
              o_wbs_dat[3:0]    <=  w_ih_state;
            end
            OH_STATE: begin
              o_wbs_dat         <= 0;
              o_wbs_dat[3:0]    <=  w_oh_state;
            end
            BRAM_NUM_READS: begin
              o_wbs_dat         <=  w_num_reads;
            end
            LOCAL_BUFFER_SIZE: begin
              o_wbs_dat         <= CONTROL_BUFFER_SIZE;
            end
            DBG_ID_VALUE: begin
              o_wbs_dat         <=  w_id_value;
            end
            DBG_COMMAND_VALUE: begin
              o_wbs_dat         <=  w_command_value;
            end
            DBG_COUNT_VALUE: begin
              o_wbs_dat         <=  w_count_value;
            end
            DBG_ADDRESS_VALUE: begin
              o_wbs_dat         <=  w_address_value;
            end
*/
            //add as many ADDR_X you need here
            default: begin
/*
              if (w_lcl_mem_en) begin
                o_wbs_dat         <=  w_bram_dout;
              end
*/
            end
          endcase
          //if (w_bram_valid) begin
            o_wbs_ack             <=  1;
          //end
        end
      end
    end
  end
end

endmodule
