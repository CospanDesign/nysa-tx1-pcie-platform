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
 * Author:
 * Description:
 *
 * Changes:
 */

`timescale 1ps / 1ps

module tx1_pcie_adapter #(
  parameter SERIAL_NUMBER             = 64'h000000000000C594,
  parameter DATA_INGRESS_FIFO_DEPTH   = 10,   //4096
  parameter DATA_EGRESS_FIFO_DEPTH    = 6     //256

)(
  input                     clk,
  input                     rst,
  output                    o_user_link_up,

  /******************************************
  * Debug Interface                         *
  ******************************************/
  output                    o_lax_clk,
  output                    o_user_reset_out,

  output                    o_pl_sel_lnk_rate,
  output        [1:0]       o_pl_sel_lnk_width,
  output        [2:0]       o_pl_initial_link_width,

  output        [5:0]       o_pl_ltssm_state,
  output                    o_clk_in_stopped,
  input         [3:0]       i_tx_diff_ctr,

  output        [15:0]      o_cfg_status,
  output        [15:0]      o_cfg_command,
  output        [15:0]      o_cfg_dstatus,
  output        [15:0]      o_cfg_dcommand,
  output        [15:0]      o_cfg_lstatus,
  output        [15:0]      o_cfg_lcommand,
  output        [15:0]      o_cfg_dcommand2,
  output        [2:0]       o_cfg_pcie_link_state,
  output        [2:0]       pipe_rx0_status_gt,
  output                    pipe_rx0_phy_status_gt,

  output        [63:0]      m64_axis_rx_tdata,
  output        [7:0]       m64_axis_rx_tkeep,
  output                    m64_axis_rx_tlast,
  output                    m64_axis_rx_tvalid,
  output                    m64_axis_rx_tready,
  output        [21:0]      m_axis_rx_tuser,

  output        [31:0]      m32_axis_rx_tdata,
  output        [3:0]       m32_axis_rx_tkeep,
  output                    m32_axis_rx_tlast,
  output                    m32_axis_rx_tvalid,
  output                    m32_axis_rx_tready,


  output                    s64_axis_tx_tready,
  output        [63:0]      s64_axis_tx_tdata,
  output        [7:0]       s64_axis_tx_tkeep,
  output                    s64_axis_tx_tlast,
  output                    s64_axis_tx_tvalid,
                
  output                    s32_axis_tx_tready,
  output        [31:0]      s32_axis_tx_tdata,
  output        [3:0]       s32_axis_tx_tkeep,
  output                    s32_axis_tx_tlast,
  output                    s32_axis_tx_tvalid,

  output        [3:0]       o_ingress_state,
  output        [3:0]       o_controller_state,

  /******************************************
  * PCIE Phy Interface                      *
  ******************************************/
  // Tx
  output                    o_pcie_exp_tx_p,
  output                    o_pcie_exp_tx_n,

  // Rx
  input                     i_pcie_exp_rx_p,
  input                     i_pcie_exp_rx_n,

  // Clock
  input                     i_pcie_clk_p,
  input                     i_pcie_clk_n,

  output                    o_clock_locked,

  output        [15:0]      o_rx_data,
  output        [1:0]       o_rx_data_k,

  output        [1:0]       o_rx_byte_is_comma,
  output                    o_rx_byte_is_aligned,

  input                     i_pcie_reset_n,
  output                    o_pcie_clkreq,

  output      [2:0]         o_cplt_sts,
  output                    o_unknown_tlp_stb,
  output                    o_unexpected_end_stb,

  /******************************************
  * Host Interface                          *
  ******************************************/

  //Host Interface
  output                    o_sys_rst,
  //User Interfaces
  output                    o_per_fifo_sel,
  output                    o_mem_fifo_sel,
  output                    o_dma_fifo_sel,

  input                     i_write_fin,
  input                     i_read_fin,

  output      [31:0]        o_data_size,
  output      [31:0]        o_data_address,
  output                    o_data_fifo_flg,
  output                    o_data_read_flg,
  output                    o_data_write_flg,

  input                     i_usr_interrupt_stb,
  input       [31:0]        i_usr_interrupt_value,

  //Ingress FIFO
  input                     i_data_clk,
  output                    o_ingress_fifo_rdy,
  input                     i_ingress_fifo_act,
  output      [23:0]        o_ingress_fifo_size,
  input                     i_ingress_fifo_stb,
  output      [31:0]        o_ingress_fifo_data,
  output                    o_ingress_fifo_idle,

  //Egress FIFO
  output      [1:0]         o_egress_fifo_rdy,
  input       [1:0]         i_egress_fifo_act,
  output      [23:0]        o_egress_fifo_size,
  input                     i_egress_fifo_stb,
  input       [31:0]        i_egress_fifo_data

);

//local parameters
localparam                                    PL_FAST_TRAIN     = "FALSE";              // Simulation Speedup
localparam                                    PCIE_EXT_CLK      = "TRUE";               // Use External Clocking Module
localparam                                    TCQ               = 1;


localparam                                    USER_CLK_FREQ     = 1;
localparam                                    USER_CLK2_DIV2    = "FALSE";
localparam                                    USERCLK2_FREQ     = (USER_CLK2_DIV2 == "TRUE") ?
                                                                  (USER_CLK_FREQ == 4) ? 3 :
                                                                  (USER_CLK_FREQ == 3) ? 2 : USER_CLK_FREQ :
                                                                    USER_CLK_FREQ;
//registes/wires

//  wire                                        sys_rst_n;
wire                                        pci_exp_txp;
wire                                        pci_exp_txn;
wire                                        pci_exp_rxp;
wire                                        pci_exp_rxn;

wire                                        sys_clk_p;
wire                                        sys_clk_n;

(* KEEP = "true" *) wire                    sys_clk;


wire                                        user_clk;
wire                                        user_reset;
wire                                        user_lnk_up;




// Tx
wire                                        tx_cfg_gnt;


/*
wire                                        s64_axis_tx_tready;
wire [63:0]                                 s64_axis_tx_tdata;
wire [7:0]                                  s64_axis_tx_tkeep;
wire                                        s64_axis_tx_tlast;
wire                                        s64_axis_tx_tvalid;

wire                                        s32_axis_tx_tready;
wire [31:0]                                 s32_axis_tx_tdata;
wire [3:0]                                  s32_axis_tx_tkeep;
wire                                        s32_axis_tx_tlast;
wire                                        s32_axis_tx_tvalid;
*/

wire [3:0]                                  s_axis_tx_tuser;


// Rx
/*
wire [63:0]                                 m64_axis_rx_tdata;
wire [7:0]                                  m64_axis_rx_tkeep;
wire                                        m64_axis_rx_tlast;
wire                                        m64_axis_rx_tvalid;
wire                                        m64_axis_rx_tready;
wire [21:0]                                 m_axis_rx_tuser;

wire [31:0]                                 m32_axis_rx_tdata;
wire [3:0]                                  m32_axis_rx_tkeep;
wire                                        m32_axis_rx_tlast;
wire                                        m32_axis_rx_tvalid;
wire                                        m32_axis_rx_tready;
*/

wire                                        rx_np_ok;
wire                                        rx_np_req;

//-------------------------------------------------------
// 3. Configuration (CFG) Interface
//-------------------------------------------------------
wire                                        cfg_err_cor;
wire                                        cfg_err_ur;
wire                                        cfg_err_ecrc;
wire                                        cfg_err_cpl_timeout;
wire                                        cfg_err_cpl_abort;
wire                                        cfg_err_cpl_unexpect;
wire                                        cfg_err_posted;
wire                                        cfg_err_locked;
wire  [47:0]                                cfg_err_tlp_cpl_header;
wire                                        cfg_interrupt;
wire                                        cfg_interrupt_assert;
wire   [7:0]                                cfg_interrupt_di;
wire                                        cfg_interrupt_stat;
wire   [4:0]                                cfg_pciecap_interrupt_msgnum;
wire                                        cfg_turnoff_ok;
wire                                        cfg_to_turnoff;
wire                                        cfg_trn_pending;
wire                                        cfg_pm_halt_aspm_l0s;
wire                                        cfg_pm_halt_aspm_l1;
wire                                        cfg_pm_force_state_en;
wire   [1:0]                                cfg_pm_force_state;
wire                                        cfg_pm_wake;
wire   [7:0]                                cfg_bus_number;
wire   [4:0]                                cfg_device_number;
wire   [2:0]                                cfg_function_number;

wire  [63:0]                                cfg_dsn;
wire [127:0]                                cfg_err_aer_headerlog;
wire   [4:0]                                cfg_aer_interrupt_msgnum;

wire  [31:0]                                cfg_mgmt_do;
wire  [31:0]                                cfg_mgmt_di;
wire   [3:0]                                cfg_mgmt_byte_en;
wire   [9:0]                                cfg_mgmt_dwaddr;
wire                                        cfg_mgmt_wr_en;
wire                                        cfg_mgmt_rd_en;
wire                                        cfg_mgmt_wr_readonly;


  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

wire                                        pl_directed_link_auton;
wire [1:0]                                  pl_directed_link_change;
wire                                        pl_directed_link_speed;
wire [1:0]                                  pl_directed_link_width;
wire                                        pl_upstream_prefer_deemph;

wire                                        sys_rst_n_c;

// Wires used for external clocking connectivity
wire           PIPE_PCLK_IN;
wire           PIPE_RXUSRCLK_IN;
wire   [0:0]   PIPE_RXOUTCLK_IN;
wire           PIPE_DCLK_IN;
wire           PIPE_USERCLK1_IN;
wire           PIPE_USERCLK2_IN;
wire           PIPE_MMCM_LOCK_IN;

wire                                        PIPE_TXOUTCLK_OUT;
wire [0:0]     PIPE_RXOUTCLK_OUT;

wire [0:0]     PIPE_PCLK_SEL_OUT;
wire                                        PIPE_GEN3_OUT;

wire                                        PIPE_OOBCLK_IN;


// registes/wires

// Control Signals
wire  [1:0]                 c_in_wr_ready;
wire  [1:0]                 c_in_wr_activate;
wire  [23:0]                c_in_wr_size;
wire                        c_in_wr_stb;
wire  [31:0]                c_in_wr_data;

wire                        c_out_rd_stb;
wire                        c_out_rd_ready;
wire                        c_out_rd_activate;
wire  [23:0]                c_out_rd_size;
wire  [31:0]                c_out_rd_data;

//Data
wire                        cfg_interrupt_stb;

wire                        cfg_interrupt_rdy;
wire  [7:0]                 cfg_interrupt_do;

wire  [7:0]                 w_interrupt_msi_value;
wire                        w_interrupt_stb;

//XXX: Configuration Registers this should be read in by the controller
wire  [31:0]                w_write_a_addr;
wire  [31:0]                w_write_b_addr;
wire  [31:0]                w_read_a_addr;
wire  [31:0]                w_read_b_addr;
wire  [31:0]                w_status_addr;
wire  [31:0]                w_buffer_size;
wire  [31:0]                w_ping_value;
wire  [31:0]                w_dev_addr;
wire  [1:0]                 w_update_buf;
wire                        w_update_buf_stb;

//XXX: Control SM Signals
wire  [31:0]                w_control_addr_base;
wire  [31:0]                w_cmd_data_count;
wire  [31:0]                w_cmd_data_address;

wire  [31:0]                o_bar_addr0;
wire  [31:0]                o_bar_addr1;
wire  [31:0]                o_bar_addr2;
wire  [31:0]                o_bar_addr3;
wire  [31:0]                o_bar_addr4;
wire  [31:0]                o_bar_addr5;

assign  w_control_addr_base = o_bar_addr0;


//XXX: These signals are controlled by the buffer controller
//BUFFER Interface
wire                        w_buf_we;
wire  [31:0]                w_buf_addr;
wire  [31:0]                w_buf_dat;

wire                        s_axis_tx_discont;
wire                        s_axis_tx_stream;
wire                        s_axis_tx_err_fwd;
wire                        s_axis_tx_s6_not_used;

wire          [31:0]        cfg_do;
wire                        cfg_rd_wr_done;
wire          [9:0]         cfg_dwaddr;
wire                        cfg_rd_en;

wire                        cfg_enable;

wire  [6:0]                 w_bar_hit;

wire                        w_enable_config_read;
wire                        w_finished_config_read;

wire                        w_reg_write_stb;


//Command Strobe Signals
wire                        w_cmd_rst_stb;
wire                        w_cmd_wr_stb;
wire                        w_cmd_rd_stb;
wire                        w_cmd_ping_stb;
wire                        w_cmd_rd_cfg_stb;
wire                        w_cmd_unknown_stb;

//Command Flag Signals
wire                        w_cmd_flg_fifo_stb;
wire                        w_cmd_flg_sel_per_stb;
wire                        w_cmd_flg_sel_mem_stb;
wire                        w_cmd_flg_sel_dma_stb;

//Egress FIFO Signals
wire                        w_egress_enable;
wire                        w_egress_finished;
wire  [7:0]                 w_egress_tlp_command;
wire  [13:0]                w_egress_tlp_flags;
wire  [31:0]                w_egress_tlp_address;
wire  [15:0]                w_egress_tlp_requester_id;
wire  [7:0]                 w_egress_tag;



/****************************************************************************
 * Egress FIFO Signals
 ****************************************************************************/

wire                        w_ctr_fifo_sel;

wire                        w_egress_fifo_rdy;
wire                        w_egress_fifo_act;
wire  [23:0]                w_egress_fifo_size;
wire  [31:0]                w_egress_fifo_data;
wire                        w_egress_fifo_stb;

wire                        w_e_ctr_fifo_rdy;
wire                        w_e_ctr_fifo_act;
wire  [23:0]                w_e_ctr_fifo_size;
wire  [31:0]                w_e_ctr_fifo_data;
wire                        w_e_ctr_fifo_stb;

wire                        w_e_per_fifo_rdy;
wire                        w_e_per_fifo_act;
wire  [23:0]                w_e_per_fifo_size;
wire  [31:0]                w_e_per_fifo_data;
wire                        w_e_per_fifo_stb;

wire                        w_e_mem_fifo_rdy;
wire                        w_e_mem_fifo_act;
wire  [23:0]                w_e_mem_fifo_size;
wire  [31:0]                w_e_mem_fifo_data;
wire                        w_e_mem_fifo_stb;

wire                        w_e_dma_fifo_rdy;
wire                        w_e_dma_fifo_act;
wire  [23:0]                w_e_dma_fifo_size;
wire  [31:0]                w_e_dma_fifo_data;
wire                        w_e_dma_fifo_stb;



wire  [12:0]                w_ibm_buf_offset;
wire                        w_bb_buf_we;
wire  [10:0]                w_bb_buf_addr;
wire  [31:0]                w_bb_buf_data;
wire  [23:0]                w_bb_data_count;

wire  [1:0]                 w_i_data_fifo_rdy;
wire  [1:0]                 w_o_data_fifo_act;
wire  [23:0]                w_o_data_fifo_size;
wire                        w_i_data_fifo_stb;
wire  [31:0]                w_i_data_fifo_data;


wire                        w_e_data_fifo_rdy;
wire                        w_e_data_fifo_act;
wire  [23:0]                w_e_data_fifo_size;
wire                        w_e_data_fifo_stb;
wire  [31:0]                w_e_data_fifo_data;

wire                        w_egress_inactive;
wire                        w_dat_fifo_sel;

wire  [23:0]                w_buf_max_size;

assign  w_buf_max_size  = 2**DATA_INGRESS_FIFO_DEPTH;


//Credit Manager
wire                        w_rcb_128B_sel;

wire  [2:0]                 fc_sel;
wire  [7:0]                 fc_nph;
wire  [11:0]                fc_npd;
wire  [7:0]                 fc_ph;
wire  [11:0]                fc_pd;
wire  [7:0]                 fc_cplh;
wire  [11:0]                fc_cpld;

wire                        w_pcie_ctr_fc_ready;
wire                        w_pcie_ctr_cmt_stb;
wire  [9:0]                 w_pcie_ctr_dword_req_cnt;

wire                        w_pcie_ing_fc_rcv_stb;
wire  [9:0]                 w_pcie_ing_fc_rcv_cnt;


//Buffer Manager
wire                        w_hst_buf_fin_stb;
wire  [1:0]                 w_hst_buf_fin;

wire                        w_ctr_en;
wire                        w_ctr_mem_rd_req_stb;
wire                        w_ctr_dat_fin;
wire                        w_ctr_tag_rdy;
wire  [7:0]                 w_ctr_tag;
wire  [9:0]                 w_ctr_dword_size;
wire                        w_ctr_buf_sel;
wire                        w_ctr_idle;
wire  [11:0]                w_ctr_start_addr;

wire  [7:0]                 w_ing_cplt_tag;
wire  [6:0]                 w_ing_cplt_lwr_addr;

wire  [1:0]                 w_bld_buf_en;
wire                        w_bld_buf_fin;

wire                        w_wr_fin;
wire                        w_rd_fin;



 IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));


wire PIPE_MMCM_RST_N;
assign  PIPE_MMCM_RST_N = 1'b1;




// Generate External Clock Module if External Clocking is selected
//---------- PIPE Clock Module -------------------------------------------------
pcie_7x_v1_11_0_pipe_clock #
(
    .PCIE_ASYNC_EN                  ("FALSE"                ),     // PCIe async enable
    .PCIE_TXBUF_EN                  ("FALSE"                ),     // PCIe TX buffer enable for Gen1/Gen2 only
    .PCIE_LANE                      (6'h01                  ),     // PCIe number of lanes
    // synthesis translate_off                              
    .PCIE_LINK_SPEED                (2                      ),
    // synthesis translate_on                               
    .PCIE_REFCLK_FREQ               (0                      ),     // PCIe reference clock frequency
    .PCIE_USERCLK1_FREQ             (USER_CLK_FREQ +1       ),     // PCIe user clock 1 frequency
    .PCIE_USERCLK2_FREQ             (USERCLK2_FREQ +1       ),     // PCIe user clock 2 frequency
    .PCIE_DEBUG_MODE                (0                      )
)
pipe_clock_i
(

    //---------- Input ------------------------------------
    .CLK_CLK                        (sys_clk                ),
    .CLK_TXOUTCLK                   (PIPE_TXOUTCLK_OUT      ),     // Reference clock from lane 0
    .CLK_RXOUTCLK_IN                (PIPE_RXOUTCLK_OUT      ),
   // .CLK_RST_N                     ( 1'b1                 ),
    .CLK_RST_N                      (PIPE_MMCM_RST_N        ),
    .CLK_PCLK_SEL                   (PIPE_PCLK_SEL_OUT      ),
    .CLK_GEN3                       (PIPE_GEN3_OUT          ),

    //---------- Output -----------------------------------
    .CLK_PCLK                       (PIPE_PCLK_IN           ),
    .CLK_RXUSRCLK                   (PIPE_RXUSRCLK_IN       ),
    .CLK_RXOUTCLK_OUT               (PIPE_RXOUTCLK_IN       ),
    .CLK_DCLK                       (PIPE_DCLK_IN           ),
    .CLK_OOBCLK                     (PIPE_OOBCLK_IN         ),
    .CLK_USERCLK1                   (PIPE_USERCLK1_IN       ),
    .CLK_USERCLK2                   (PIPE_USERCLK2_IN       ),
    .CLK_MMCM_LOCK                  (PIPE_MMCM_LOCK_IN      ),
    .o_clk_in_stopped               (o_clk_in_stopped       )

);



pcie_7x_v1_11_0 #(
  .PL_FAST_TRAIN                    (PL_FAST_TRAIN                 ),
  .PCIE_EXT_CLK                     ("TRUE"                        )
) pcie_7x_v1_11_0_i
 (

  //--------------------------------------------------------------------------//
  // 1. PCI Express (pci_exp) Interface                                       //
  //--------------------------------------------------------------------------//

  // Tx
  .pci_exp_txn                      (pci_exp_txn                   ),
  .pci_exp_txp                      (pci_exp_txp                   ),
                                                                   
  // Rx                                                            
  .pci_exp_rxn                      (pci_exp_rxn                   ),
  .pci_exp_rxp                      (pci_exp_rxp                   ),

  //--------------------------------------------------------------------------//
  // 2. Clocking Interface                                                    //
  //--------------------------------------------------------------------------//
  .PIPE_PCLK_IN                     (PIPE_PCLK_IN                  ),
  .PIPE_RXUSRCLK_IN                 (PIPE_RXUSRCLK_IN              ),
  .PIPE_RXOUTCLK_IN                 (PIPE_RXOUTCLK_IN              ),
  .PIPE_DCLK_IN                     (PIPE_DCLK_IN                  ),
  .PIPE_USERCLK1_IN                 (PIPE_USERCLK1_IN              ),
  .PIPE_OOBCLK_IN                   (PIPE_OOBCLK_IN                ),
  .PIPE_USERCLK2_IN                 (PIPE_USERCLK2_IN              ),
  .PIPE_MMCM_LOCK_IN                (PIPE_MMCM_LOCK_IN             ),
                                                                   
  .PIPE_TXOUTCLK_OUT                (PIPE_TXOUTCLK_OUT             ),
  .PIPE_RXOUTCLK_OUT                (PIPE_RXOUTCLK_OUT             ),
  .PIPE_PCLK_SEL_OUT                (PIPE_PCLK_SEL_OUT             ),
  .PIPE_GEN3_OUT                    (PIPE_GEN3_OUT                 ),


  //--------------------------------------------------------------------------//
  // 3. AXI-S Interface                                                       //
  //--------------------------------------------------------------------------//

  // Common
  .user_clk_out                     (user_clk                      ),
  .user_reset_out                   (user_reset                    ),
  .user_lnk_up                      (user_lnk_up                   ),

  // TX

  .tx_buf_av                        (                              ),
  .tx_err_drop                      (                              ),
  .tx_cfg_req                       (                              ),
  .s_axis_tx_tready                 (s64_axis_tx_tready            ),
  .s_axis_tx_tdata                  (s64_axis_tx_tdata             ),
  .s_axis_tx_tkeep                  (s64_axis_tx_tkeep             ),
  .s_axis_tx_tuser                  (s_axis_tx_tuser               ),
  .s_axis_tx_tlast                  (s64_axis_tx_tlast             ),
  .s_axis_tx_tvalid                 (s64_axis_tx_tvalid            ),
                                                                   
  .tx_cfg_gnt                       (tx_cfg_gnt                    ),
                                                                   
  // Rx                                                            
  .m_axis_rx_tdata                  (m64_axis_rx_tdata             ),
  .m_axis_rx_tkeep                  (m64_axis_rx_tkeep             ),
  .m_axis_rx_tlast                  (m64_axis_rx_tlast             ),
  .m_axis_rx_tvalid                 (m64_axis_rx_tvalid            ),
  .m_axis_rx_tready                 (m64_axis_rx_tready            ),
  .m_axis_rx_tuser                  (m_axis_rx_tuser               ),
  .rx_np_ok                         (rx_np_ok                      ),
  .rx_np_req                        (rx_np_req                     ),
                                                                   
  // Flow Control                                                  
  .fc_cpld                          (fc_cpld                       ),
  .fc_cplh                          (fc_cplh                       ),
  .fc_npd                           (fc_npd                        ),
  .fc_nph                           (fc_nph                        ),
  .fc_pd                            (fc_pd                         ),
  .fc_ph                            (fc_ph                         ),
  .fc_sel                           (fc_sel                        ),


  //--------------------------------------------------------------------------//
  // 4. Configuration (CFG) Interface                                         //
  //--------------------------------------------------------------------------//

  //--------------------------------------------------------------------------//
  // EP and RP                                                                //
  //--------------------------------------------------------------------------//

  .cfg_status                       (o_cfg_status                  ),
  .cfg_command                      (o_cfg_command                 ),
  .cfg_dstatus                      (o_cfg_dstatus                 ),
  .cfg_lstatus                      (o_cfg_lstatus                 ),
  .cfg_pcie_link_state              (o_cfg_pcie_link_state         ),
  .cfg_dcommand                     (o_cfg_dcommand                ),
  .cfg_lcommand                     (o_cfg_lcommand                ),
  .cfg_dcommand2                    (o_cfg_dcommand2               ),
                                                                   
  .cfg_pmcsr_pme_en                 (                              ),
  .cfg_pmcsr_powerstate             (                              ),
  .cfg_pmcsr_pme_status             (                              ),
  .cfg_received_func_lvl_rst        (                              ),
                                                                   
  // Management Interface                                          
  .cfg_mgmt_do                      (cfg_mgmt_do                   ),
  .cfg_mgmt_rd_wr_done              (cfg_mgmt_rd_wr_done           ),
  .cfg_mgmt_di                      (cfg_mgmt_di                   ),
  .cfg_mgmt_byte_en                 (cfg_mgmt_byte_en              ),
  .cfg_mgmt_dwaddr                  (cfg_mgmt_dwaddr               ),
  .cfg_mgmt_wr_en                   (cfg_mgmt_wr_en                ),
  .cfg_mgmt_rd_en                   (cfg_mgmt_rd_en                ),
  .cfg_mgmt_wr_readonly             (cfg_mgmt_wr_readonly          ),

  // Error Reporting Interface

  .cfg_err_ur                       (cfg_err_ur                    ),
  .cfg_err_cor                      (cfg_err_cor                   ),
  .cfg_err_ecrc                     (cfg_err_ecrc                  ),
  .cfg_err_cpl_timeout              (cfg_err_cpl_timeout           ),
  .cfg_err_cpl_abort                (cfg_err_cpl_abort             ),
  .cfg_err_posted                   (cfg_err_posted                ),
  .cfg_err_locked                   (cfg_err_locked                ),
  .cfg_err_tlp_cpl_header           (cfg_err_tlp_cpl_header        ),



  .cfg_err_cpl_unexpect             (cfg_err_cpl_unexpect          ),
  .cfg_err_atomic_egress_blocked    (cfg_err_atomic_egress_blocked ),
  .cfg_err_internal_cor             (cfg_err_internal_cor          ),
  .cfg_err_malformed                (cfg_err_malformed             ),
  .cfg_err_mc_blocked               (cfg_err_mc_blocked            ),
  .cfg_err_poisoned                 (cfg_err_poisoned              ),
  .cfg_err_norecovery               (cfg_err_norecovery            ),
  .cfg_err_cpl_rdy                  (                              ),
  .cfg_err_acs                      (cfg_err_acs                   ),
  .cfg_err_internal_uncor           (cfg_err_internal_uncor        ),

  .cfg_trn_pending                  (cfg_trn_pending               ),
  .cfg_pm_halt_aspm_l0s             (cfg_pm_halt_aspm_l0s          ),
  .cfg_pm_halt_aspm_l1              (cfg_pm_halt_aspm_l1           ),
  .cfg_pm_force_state_en            (cfg_pm_force_state_en         ),
  .cfg_pm_force_state               (cfg_pm_force_state            ),

  .cfg_dsn                          (cfg_dsn                       ),

  //-----------------------------------------------//
  // EP Only                                       //
  //-----------------------------------------------//
  .cfg_interrupt                    (cfg_interrupt                ),
  .cfg_interrupt_rdy                (cfg_interrupt_rdy            ),
  .cfg_interrupt_assert             (cfg_interrupt_assert         ),
  .cfg_interrupt_di                 (cfg_interrupt_di             ),
  .cfg_interrupt_do                 (                             ),
  .cfg_interrupt_mmenable           (                             ),
  .cfg_interrupt_msienable          (                             ),
  .cfg_interrupt_msixenable         (                             ),
  .cfg_interrupt_msixfm             (                             ),
  .cfg_interrupt_stat               (cfg_interrupt_stat           ),
  .cfg_pciecap_interrupt_msgnum     (cfg_pciecap_interrupt_msgnum ),
  .cfg_to_turnoff                   (cfg_to_turnoff               ),
  .cfg_turnoff_ok                   (cfg_turnoff_ok               ),
  .cfg_bus_number                   (cfg_bus_number               ),
  .cfg_device_number                (cfg_device_number            ),
  .cfg_function_number              (cfg_function_number          ),
  .cfg_pm_wake                      (cfg_pm_wake                  ),

  //-----------------------------------------------//
  // RP Only                                       //
  //-----------------------------------------------//
  .cfg_pm_send_pme_to                         (1'b0                        ),
  .cfg_ds_bus_number                          (8'b0                        ),
  .cfg_ds_device_number                       (5'b0                        ),
  .cfg_ds_function_number                     (3'b0                        ),
  .cfg_mgmt_wr_rw1c_as_rw                     (1'b0                        ),
  .cfg_msg_received                           (                            ),
  .cfg_msg_data                               (                            ),

  .cfg_bridge_serr_en                         (                            ),
  .cfg_slot_control_electromech_il_ctl_pulse  (                            ),
  .cfg_root_control_syserr_corr_err_en        (                            ),
  .cfg_root_control_syserr_non_fatal_err_en   (                            ),
  .cfg_root_control_syserr_fatal_err_en       (                            ),
  .cfg_root_control_pme_int_en                (                            ),
  .cfg_aer_rooterr_corr_err_reporting_en      (                            ),
  .cfg_aer_rooterr_non_fatal_err_reporting_en (                            ),
  .cfg_aer_rooterr_fatal_err_reporting_en     (                            ),
  .cfg_aer_rooterr_corr_err_received          (                            ),
  .cfg_aer_rooterr_non_fatal_err_received     (                            ),
  .cfg_aer_rooterr_fatal_err_received         (                            ),

  .cfg_msg_received_err_cor                   (                            ),
  .cfg_msg_received_err_non_fatal             (                            ),
  .cfg_msg_received_err_fatal                 (                            ),
  .cfg_msg_received_pm_as_nak                 (                            ),
  .cfg_msg_received_pme_to_ack                (                            ),
  .cfg_msg_received_assert_int_a              (                            ),
  .cfg_msg_received_assert_int_b              (                            ),
  .cfg_msg_received_assert_int_c              (                            ),
  .cfg_msg_received_assert_int_d              (                            ),
  .cfg_msg_received_deassert_int_a            (                            ),
  .cfg_msg_received_deassert_int_b            (                            ),
  .cfg_msg_received_deassert_int_c            (                            ),
  .cfg_msg_received_deassert_int_d            (                            ),

   .cfg_msg_received_pm_pme                   (                            ),
   .cfg_msg_received_setslotpowerlimit        (                            ),
  //---------------------------------------------------------------------------------------------------------------//
  // 5. Physical Layer Control and Status (PL) nterface                                                            //
  //---------------------------------------------------------------------------------------------------------------//
  .pl_directed_link_change                    (pl_directed_link_change    ),
  .pl_directed_link_width                     (pl_directed_link_width     ),
  .pl_directed_link_speed                     (pl_directed_link_speed     ),
  .pl_directed_link_auton                     (pl_directed_link_auton     ),
  .pl_upstream_prefer_deemph                  (pl_upstream_prefer_deemph  ),



  .pl_sel_lnk_rate                            (o_pl_sel_lnk_rate          ),
  .pl_sel_lnk_width                           (o_pl_sel_lnk_width         ),
  .pl_ltssm_state                             (o_pl_ltssm_state           ),
  .pl_lane_reversal_mode                      (                           ),

  .pl_phy_lnk_up                              (                           ),
  .pl_tx_pm_state                             (                           ),
  .pl_rx_pm_state                             (                           ),

  .pl_link_upcfg_cap                          (                           ),
  .pl_link_gen2_cap                           (                           ),
  .pl_link_partner_gen2_supported             (                           ),
  .pl_initial_link_width                      (o_pl_initial_link_width    ),

  .pl_directed_change_done                    (                           ),

  //-----------------------------------------------//
  // EP Only                                       //
  //-----------------------------------------------//
  .pl_received_hot_rst                        (                           ),

  //-----------------------------------------------//
  // RP Only                                       //
  //-----------------------------------------------//
  .pl_transmit_hot_rst                        (1'b0                       ),
  .pl_downstream_deemph_source                (1'b0                       ),

  //---------------------------------------------------------------------------------------------------------------//
  // 6. AER Interface                                                                                              //
  //---------------------------------------------------------------------------------------------------------------//

  .cfg_err_aer_headerlog                      (cfg_err_aer_headerlog      ),
  .cfg_aer_interrupt_msgnum                   (cfg_aer_interrupt_msgnum   ),
  .cfg_err_aer_headerlog_set                  (                           ),
  .cfg_aer_ecrc_check_en                      (                           ),
  .cfg_aer_ecrc_gen_en                        (                           ),

  //---------------------------------------------------------------------------------------------------------------//
  // 7. VC interface                                                                                               //
  //---------------------------------------------------------------------------------------------------------------//

  .cfg_vc_tcvc_map                            (                           ),

  //---------------------------------------------------------------------------------------------------------------//
  // 8. System  (SYS) Interface                                                                                    //
  //---------------------------------------------------------------------------------------------------------------//

  .pipe_rx0_status_gt                         (pipe_rx0_status_gt         ),
  .pipe_rx0_phy_status_gt                     (pipe_rx0_phy_status_gt     ),
  .i_tx_diff_ctr                              (i_tx_diff_ctr              ),

  .o_rx_data                                  (o_rx_data                  ),
  .o_rx_data_k                                (o_rx_data_k                ),

  .o_rx_byte_is_comma                         (o_rx_byte_is_comma         ),
  .o_rx_byte_is_aligned                       (o_rx_byte_is_aligned       ),

  .PIPE_MMCM_RST_N                            (PIPE_MMCM_RST_N            ), // Async      | Async
  .sys_clk                                    (sys_clk                    ),
  .sys_rst_n                                  (sys_rst_n_c                )
);

//AXI 64-bit -> 32-bit Ingress Bridge

/*
pcie_64_to_32_axi #(
  .ADDRESS_WIDTH            (6                   )
) axi_ingress_64_32_conv(                                               
  .clk                      (user_clk            ),
  .rst                      (o_sys_rst           ),
                            
                            
  .i_64_data                (m64_axis_rx_tdata   ),
  .i_64_valid               (m64_axis_rx_tvalid  ),
  .i_64_last                (m64_axis_rx_tlast   ),
  .o_64_ready               (m64_axis_rx_tready  ),
                            
  .o_32_data                (m32_axis_rx_tdata   ),
  .o_32_valid               (m32_axis_rx_tvalid  ),
  .o_32_last                (m32_axis_rx_tlast   ),
  .i_32_ready               (m32_axis_rx_tready  )
);
*/

pcie_data_ingress axi_ingress_64_32_conv (
  .ACLK                                       (user_clk                   ), // input ACLK
  .ARESETN                                    (!o_sys_rst                 ), // input ARESETN

  .S00_AXIS_ACLK                              (user_clk                   ), // input S00_AXIS_ACLK
  .S00_AXIS_ARESETN                           (!o_sys_rst                 ), // input S00_AXIS_ARESETN
  .S00_AXIS_TVALID                            (m64_axis_rx_tvalid         ), // input S00_AXIS_TVALID
  .S00_AXIS_TREADY                            (m64_axis_rx_tready         ), // output S00_AXIS_TREADY
  .S00_AXIS_TDATA                             (m64_axis_rx_tdata          ), // input [63 : 0] S00_AXIS_TDATA
  .S00_AXIS_TKEEP                             (m64_axis_rx_tkeep          ), // input [7 : 0] S00_AXIS_TKEEP
  .S00_AXIS_TLAST                             (m64_axis_rx_tlast          ), // input S00_AXIS_TLAST
//  .S00_FIFO_DATA_COUNT                        (                           ), // output [31 : 0] S00_FIFO_DATA_COUNT

  .M00_AXIS_ACLK                              (user_clk                   ), // input M00_AXIS_ACLK
  .M00_AXIS_ARESETN                           (!o_sys_rst                 ), // input M00_AXIS_ARESETN
  .M00_AXIS_TVALID                            (m32_axis_rx_tvalid         ), // output M00_AXIS_TVALID
  .M00_AXIS_TREADY                            (m32_axis_rx_tready         ), // input M00_AXIS_TREADY
  .M00_AXIS_TDATA                             (m32_axis_rx_tdata          ), // output [31 : 0] M00_AXIS_TDATA
  .M00_AXIS_TKEEP                             (m32_axis_rx_tkeep          ), // output [3 : 0] M00_AXIS_TKEEP
  .M00_AXIS_TLAST                             (m32_axis_rx_tlast          )  // output M00_AXIS_TLAST
);

//AXI 32-bit -> 64-bit Ingress Bridge
pcie_data_egress axi_egress_32_64_conv (
  .ACLK                                       (user_clk                   ), // input ACLK
  .ARESETN                                    (!o_sys_rst                 ), // input ARESETN

  .S00_AXIS_ACLK                              (user_clk                   ), // input S00_AXIS_ACLK
  .S00_AXIS_ARESETN                           (!o_sys_rst                 ), // input S00_AXIS_ARESETN
  .S00_AXIS_TVALID                            (s32_axis_tx_tvalid         ), // input S00_AXIS_TVALID
  .S00_AXIS_TREADY                            (s32_axis_tx_tready         ), // output S00_AXIS_TREADY
  .S00_AXIS_TDATA                             (s32_axis_tx_tdata          ), // input [31 : 0] S00_AXIS_TDATA
  .S00_AXIS_TKEEP                             (s32_axis_tx_tkeep          ), // input [3 : 0] S00_AXIS_TKEEP
  .S00_AXIS_TLAST                             (s32_axis_tx_tlast          ), // input S00_AXIS_TLAST
  .S00_FIFO_DATA_COUNT                        (                           ), // output [31 : 0] S00_FIFO_DATA_COUNT

  .M00_AXIS_ACLK                              (user_clk                   ), // input M00_AXIS_ACLK
  .M00_AXIS_ARESETN                           (!o_sys_rst                 ), // input M00_AXIS_ARESETN
  .M00_AXIS_TVALID                            (s64_axis_tx_tvalid         ), // output M00_AXIS_TVALID
  .M00_AXIS_TREADY                            (s64_axis_tx_tready         ), // input M00_AXIS_TREADY
  .M00_AXIS_TDATA                             (s64_axis_tx_tdata          ), // output [63 : 0] M00_AXIS_TDATA
  .M00_AXIS_TKEEP                             (s64_axis_tx_tkeep          ), // output [7 : 0] M00_AXIS_TKEEP
  .M00_AXIS_TLAST                             (s64_axis_tx_tlast          )  // output M00_AXIS_TLAST
);

/****************************************************************************
* Adapted PCIE Controller                                                   *
*                                                                           *
*                                                                           *
*                                                                           *
*                                                                           *
****************************************************************************/

cross_clock_enable rd_fin_en (
  .rst                        (o_sys_rst                   ),
  .in_en                      (i_read_fin                  ),

  .out_clk                    (user_clk                    ),
  .out_en                     (w_rd_fin                    )
);

cross_clock_enable wr_fin_en (
  .rst                        (o_sys_rst                   ),
  .in_en                      (i_write_fin                 ),

  .out_clk                    (user_clk                    ),
  .out_en                     (w_wr_fin                    )
);

/****************************************************************************
 * Read the BAR Addresses from Config Space                                 *
 ****************************************************************************/
config_parser cfg (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  .i_en                       (w_enable_config_read       ),
  .o_finished                 (w_finished_config_read     ),

  .i_cfg_do                   (cfg_mgmt_do                ),
  .i_cfg_rd_wr_done           (cfg_mgmt_rd_wr_done        ),
  .o_cfg_dwaddr               (cfg_mgmt_dwaddr            ),
  .o_cfg_rd_en                (cfg_mgmt_rd_en             ),


  .o_bar_addr0                (o_bar_addr0                ),
  .o_bar_addr1                (o_bar_addr1                ),
  .o_bar_addr2                (o_bar_addr2                ),
  .o_bar_addr3                (o_bar_addr3                ),
  .o_bar_addr4                (o_bar_addr4                ),
  .o_bar_addr5                (o_bar_addr5                )
);

buffer_builder #(
  .MEM_DEPTH                  (11                         ),   //8K Buffer
  .DATA_WIDTH                 (32                         )
) bb (
  .mem_clk                    (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  .i_ppfifo_wr_en             (w_bld_buf_en               ),
  .o_ppfifo_wr_fin            (w_bld_buf_fin              ),

  .i_bram_we                  (w_bb_buf_we                ),
  .i_bram_addr                (w_bb_buf_addr              ),
  .i_bram_din                 (w_bb_buf_data              ),

  .ppfifo_clk                 (user_clk                   ),

  .i_data_count               (w_bb_data_count            ),

  .i_write_ready              (w_i_data_fifo_rdy          ),
  .o_write_activate           (w_o_data_fifo_act          ),
  .i_write_size               (w_o_data_fifo_size         ),
  .o_write_stb                (w_i_data_fifo_stb          ),
  .o_write_data               (w_i_data_fifo_data         )
);


credit_manager cm (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  //Credits
  .o_fc_sel                   (fc_sel                     ),
  .i_rcb_sel                  (w_rcb_128B_sel             ),
  .i_fc_cplh                  (fc_cplh                    ),
  .i_fc_cpld                  (fc_cpld                    ),

  //PCIE Control Interface
  .o_ready                    (w_pcie_ctr_fc_ready        ),
  .i_cmt_stb                  (w_pcie_ctr_cmt_stb         ),
  .i_dword_req_count          (w_pcie_ctr_dword_req_cnt   ),

  //Completion Receive Size
  .i_rcv_stb                  (w_pcie_ing_fc_rcv_stb      ),
  .i_dword_rcv_count          (w_pcie_ing_fc_rcv_cnt      )
);


ingress_buffer_manager buf_man (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  //Host Interface
  .i_hst_buf_rdy_stb          (w_update_buf_stb           ),
  .i_hst_buf_rdy              (w_update_buf               ),
  .o_hst_buf_fin_stb          (w_hst_buf_fin_stb          ),
  .o_hst_buf_fin              (w_hst_buf_fin              ),

  //PCIE Control Interface
  .i_ctr_en                   (w_ctr_en                   ),
  .i_ctr_mem_rd_req_stb       (w_ctr_mem_rd_req_stb       ),
  .i_ctr_dat_fin              (w_ctr_dat_fin              ),
  .o_ctr_tag_rdy              (w_ctr_tag_rdy              ),
  .o_ctr_tag                  (w_ctr_tag                  ),
  .o_ctr_dword_size           (w_ctr_dword_size           ),
  .o_ctr_start_addr           (w_ctr_start_addr           ),
  .o_ctr_buf_sel              (w_ctr_buf_sel              ),
  .o_ctr_idle                 (w_ctr_idle                 ),

  //PCIE Ingress Interface
  .i_ing_cplt_stb             (w_pcie_ing_fc_rcv_stb      ),
  .i_ing_cplt_tag             (w_ing_cplt_tag             ),
  .i_ing_cplt_pkt_cnt         (w_pcie_ing_fc_rcv_cnt      ),
  .i_ing_cplt_lwr_addr        (w_ing_cplt_lwr_addr        ),

  //Buffer Block Interface
  .o_bld_mem_addr             (w_ibm_buf_offset           ),
  .o_bld_buf_en               (w_bld_buf_en               ),
  .i_bld_buf_fin              (w_bld_buf_fin              )

/*
  .o_dbg_tag_ingress_fin      (dbg_tag_ingress_fin        ),
  .o_dbg_tag_en               (dbg_tag_en                 ),
  .o_dbg_reenable_stb         (o_dbg_reenable_stb         ),
  .o_dbg_reenable_nzero_stb   (o_dbg_reenable_nzero_stb   )
*/

);


pcie_control controller (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  //Configuration Values
  .i_pcie_bus_num             (cfg_bus_number             ),
  .i_pcie_dev_num             (cfg_device_number          ),
  .i_pcie_fun_num             (cfg_function_number        ),

  //Ingress Machine Interface
  .i_write_a_addr             (w_write_a_addr             ),
  .i_write_b_addr             (w_write_b_addr             ),
  .i_read_a_addr              (w_read_a_addr              ),
  .i_read_b_addr              (w_read_b_addr              ),
  .i_status_addr              (w_status_addr              ),
  .i_buffer_size              (w_buffer_size              ),
  .i_ping_value               (w_ping_value               ),
  .i_dev_addr                 (w_dev_addr                 ),
  .i_update_buf               (w_update_buf               ),
  .i_update_buf_stb           (w_update_buf_stb           ),

  .i_reg_write_stb            (w_reg_write_stb            ),
  //.i_device_select            (w_device_select            ),

  .i_cmd_rst_stb              (w_cmd_rst_stb              ),
  .i_cmd_wr_stb               (w_cmd_wr_stb               ),
  .i_cmd_rd_stb               (w_cmd_rd_stb               ),
  .i_cmd_ping_stb             (w_cmd_ping_stb             ),
  .i_cmd_rd_cfg_stb           (w_cmd_rd_cfg_stb           ),
  .i_cmd_unknown              (w_cmd_unknown_stb          ),
  .i_cmd_flg_fifo             (w_cmd_flg_fifo_stb         ),
  .i_cmd_flg_sel_periph       (w_cmd_flg_sel_per_stb      ),
  .i_cmd_flg_sel_memory       (w_cmd_flg_sel_mem_stb      ),
  .i_cmd_flg_sel_dma          (w_cmd_flg_sel_dma_stb      ),

  .i_cmd_data_count           (w_cmd_data_count           ),
  .i_cmd_data_address         (w_cmd_data_address         ),

  .o_ctr_sel                  (w_ctr_fifo_sel             ),

  //User Interface
  .o_per_sel                  (o_per_fifo_sel             ),
  .o_mem_sel                  (o_mem_fifo_sel             ),
  .o_dma_sel                  (o_dma_fifo_sel             ),
  .i_write_fin                (w_wr_fin                   ),
  .i_read_fin                 (w_rd_fin & w_egress_inactive     ),

  .o_data_fifo_sel            (w_dat_fifo_sel             ),

  .i_interrupt_stb            (i_usr_interrupt_stb        ),
  .i_interrupt_value          (i_usr_interrupt_value      ),

  .o_data_size                (o_data_size                ),
  .o_data_address             (o_data_address             ),
  .o_data_fifo_flg            (o_data_fifo_flg            ),
  .o_data_read_flg            (o_data_read_flg            ),
  .o_data_write_flg           (o_data_write_flg           ),


  //Peripheral/Memory/DMA Egress FIFO Interface
  .i_e_fifo_rdy               (w_egress_fifo_rdy          ),
  .i_e_fifo_size              (w_egress_fifo_size         ),

  //Egress Controller Interface
  .o_egress_enable            (w_egress_enable            ),
  .i_egress_finished          (w_egress_finished          ),
  .o_egress_tlp_command       (w_egress_tlp_command       ),
  .o_egress_tlp_flags         (w_egress_tlp_flags         ),
  .o_egress_tlp_address       (w_egress_tlp_address       ),
  .o_egress_tlp_requester_id  (w_egress_tlp_requester_id  ),
  .o_egress_tag               (w_egress_tag               ),

  .o_interrupt_msi_value      (w_interrupt_msi_value      ),
//  .o_interrupt_stb            (w_interrupt_stb            ),
  .o_interrupt_send_en        (cfg_interrupt              ),
  .i_interrupt_send_rdy       (cfg_interrupt_rdy          ),

  .o_egress_fifo_rdy          (w_e_ctr_fifo_rdy           ),
  .i_egress_fifo_act          (w_e_ctr_fifo_act           ),
  .o_egress_fifo_size         (w_e_ctr_fifo_size          ),
  .i_egress_fifo_stb          (w_e_ctr_fifo_stb           ),
  .o_egress_fifo_data         (w_e_ctr_fifo_data          ),

  //Ingress Buffer Interface
  .i_ibm_buf_fin_stb          (w_hst_buf_fin_stb          ),
  .i_ibm_buf_fin              (w_hst_buf_fin              ),

  .o_ibm_en                   (w_ctr_en                   ),
  .o_ibm_req_stb              (w_ctr_mem_rd_req_stb       ),
  .o_ibm_dat_fin              (w_ctr_dat_fin              ),
  .i_ibm_tag_rdy              (w_ctr_tag_rdy              ),
  .i_ibm_tag                  (w_ctr_tag                  ),
  .i_ibm_dword_cnt            (w_ctr_dword_size           ),
  .i_ibm_start_addr           (w_ctr_start_addr           ),
  .i_ibm_buf_sel              (w_ctr_buf_sel              ),
  .i_ibm_idle                 (w_ctr_idle                 ),


  .i_buf_max_size             (w_buf_max_size             ),
  .o_buf_data_count           (w_bb_data_count            ),

  //System Interface
  .o_sys_rst                  (o_user_reset_out           ),

  .i_fc_ready                 (w_pcie_ctr_fc_ready        ),
  .o_fc_cmt_stb               (w_pcie_ctr_cmt_stb         ),
  .o_dword_req_cnt            (w_pcie_ctr_dword_req_cnt   ),

  //Configuration Reader Interface
  .o_cfg_read_exec            (o_cfg_read_exec            ),
  .o_cfg_sm_state             (o_cfg_sm_state             ),
  .o_sm_state                 (o_controller_state         )
);


//XXX: Need to think about resets

/****************************************************************************
 * Single IN/OUT FIFO Solution (This Can Change in the future):
 *  Instead of dedicating unique FIFOs for each bus, I can just do one
 *  FIFO. This will reduce the size of the core at the cost of
 *  a certain amount of time it will take to fill up the FIFOs
 ****************************************************************************/

//INGRESS FIFO
ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (DATA_INGRESS_FIFO_DEPTH    ) // 1024 32-bit values (4096 Bytes)
) i_data_fifo (
  .reset                      (o_sys_rst || rst           ),
  //Write Side
  .write_clock                (user_clk                   ),
  .write_ready                (w_i_data_fifo_rdy          ),
  .write_activate             (w_o_data_fifo_act          ),
  .write_fifo_size            (w_o_data_fifo_size         ),
  .write_strobe               (w_i_data_fifo_stb          ),
  .write_data                 (w_i_data_fifo_data         ),

  //Read Side
  .read_clock                 (i_data_clk                 ),
  .read_ready                 (o_ingress_fifo_rdy         ),
  .read_activate              (i_ingress_fifo_act         ),
  .read_count                 (o_ingress_fifo_size        ),
  .read_strobe                (i_ingress_fifo_stb         ),
  .read_data                  (o_ingress_fifo_data        ),
  .inactive                   (o_ingress_fifo_idle        )
);

//EGRESS FIFOs
ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (DATA_EGRESS_FIFO_DEPTH     ) // 64 32-bit values (256 Bytes)
) e_data_fifo (
  .reset                      (o_sys_rst || rst           ),
  //Write Side
  .write_clock                (i_data_clk                 ),
  .write_ready                (o_egress_fifo_rdy          ),
  .write_activate             (i_egress_fifo_act          ),
  .write_fifo_size            (o_egress_fifo_size         ),
  .write_strobe               (i_egress_fifo_stb          ),
  .write_data                 (i_egress_fifo_data         ),

  //Read Side
  .read_clock                 (user_clk                   ),
  .read_ready                 (w_e_data_fifo_rdy          ),
  .read_activate              (w_e_data_fifo_act          ),
  .read_count                 (w_e_data_fifo_size         ),
  .read_strobe                (w_e_data_fifo_stb          ),
  .read_data                  (w_e_data_fifo_data         ),
  .inactive                   (w_egress_inactive          )
);

pcie_ingress ingress (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  //AXI Stream Host 2 Device
  .o_axi_ingress_ready        (m32_axis_rx_tready         ),
  .i_axi_ingress_data         (m32_axis_rx_tdata          ),
  .i_axi_ingress_keep         (m32_axis_rx_tkeep          ),
  .i_axi_ingress_last         (m32_axis_rx_tlast          ),
  .i_axi_ingress_valid        (m32_axis_rx_tvalid         ),

  //Configuration
  .o_reg_write_stb            (w_reg_write_stb            ),  //Strobes when new register data is detected

  //Parsed out Register Values
  .o_write_a_addr             (w_write_a_addr             ),
  .o_write_b_addr             (w_write_b_addr             ),
  .o_read_a_addr              (w_read_a_addr              ),
  .o_read_b_addr              (w_read_b_addr              ),
  .o_status_addr              (w_status_addr              ),
  .o_buffer_size              (w_buffer_size              ),
  .o_ping_value               (w_ping_value               ),
  .o_dev_addr                 (w_dev_addr                 ),
  .o_update_buf               (w_update_buf               ),
  .o_update_buf_stb           (w_update_buf_stb           ),

  //Command Interface
  //.o_device_select            (w_device_select            ),

  .o_cmd_rst_stb              (w_cmd_rst_stb              ),  //Strobe when a reset command is detected
  .o_cmd_wr_stb               (w_cmd_wr_stb               ),  //Strobes when a write request is detected
  .o_cmd_rd_stb               (w_cmd_rd_stb               ),  //Strobes when a read request is detected
  .o_cmd_ping_stb             (w_cmd_ping_stb             ),  //Strobes when a ping request is detected
  .o_cmd_rd_cfg_stb           (w_cmd_rd_cfg_stb           ),  //Strobes when a read configuration id detected
  .o_cmd_unknown_stb          (w_cmd_unknown_stb          ),

  .o_cmd_flg_fifo_stb         (w_cmd_flg_fifo_stb         ),  //Flag indicating that transfer shouldn't auto increment addr
  .o_cmd_flg_sel_per_stb      (w_cmd_flg_sel_per_stb      ),
  .o_cmd_flg_sel_mem_stb      (w_cmd_flg_sel_mem_stb      ),
  .o_cmd_flg_sel_dma_stb      (w_cmd_flg_sel_dma_stb      ),

  //Input Configuration Registers from either PCIE_A1 or controller
  .i_bar_hit                  (o_bar_hit                  ),
  //Local Address of where BAR0 is located (Used to do address translation)
  .i_control_addr_base        (w_control_addr_base        ),
  .o_enable_config_read       (w_enable_config_read       ),
  .i_finished_config_read     (w_finished_config_read     ),

  //When a command is detected the size of the transaction is reported here
  .o_cmd_data_count           (w_cmd_data_count           ),
  .o_cmd_data_address         (w_cmd_data_address         ),

  //Flow Control
  .o_cplt_pkt_stb             (w_pcie_ing_fc_rcv_stb      ),
  .o_cplt_pkt_cnt             (w_pcie_ing_fc_rcv_cnt      ),
  .o_cplt_sts                 (o_cplt_sts                 ),
  .o_unknown_tlp_stb          (o_unknown_tlp_stb          ),
  .o_unexpected_end_stb       (o_unexpected_end_stb       ),

  .o_cplt_pkt_tag             (w_ing_cplt_tag             ),
  .o_cplt_pkt_lwr_addr        (w_ing_cplt_lwr_addr        ),

  //Buffer interface, the buffer controller will manage this
  .i_buf_offset               (w_ibm_buf_offset           ),
  .o_buf_we                   (w_bb_buf_we                ),
  .o_buf_addr                 (w_bb_buf_addr              ),
  .o_buf_data                 (w_bb_buf_data              ),
  .o_state                    (o_ingress_state            ),
  .o_ingress_count            (o_ingress_count            ),
  .o_ingress_ri_count         (o_ingress_ri_count         ),
  .o_ingress_ci_count         (o_ingress_ci_count         ),
  .o_ingress_cmplt_count      (o_ingress_cmplt_count      ),
  .o_ingress_addr             (o_ingress_addr             )
);

pcie_egress egress (
  .clk                        (user_clk                   ),
  .rst                        (o_sys_rst                  ),

  .i_enable                   (w_egress_enable            ),
  .o_finished                 (w_egress_finished          ),
  .i_command                  (w_egress_tlp_command       ),
  .i_flags                    (w_egress_tlp_flags         ),
  .i_address                  (w_egress_tlp_address       ),
  .i_requester_id             (w_egress_tlp_requester_id  ),
  .i_tag                      (w_egress_tag               ),

  .i_req_dword_cnt            (w_pcie_ctr_dword_req_cnt   ),

  //AXI Interface
  .i_axi_egress_ready         (s32_axis_tx_tready         ),
  .o_axi_egress_data          (s32_axis_tx_tdata          ),
  .o_axi_egress_keep          (s32_axis_tx_tkeep          ),
  .o_axi_egress_last          (s32_axis_tx_tlast          ),
  .o_axi_egress_valid         (s32_axis_tx_tvalid         ),

  //Data FIFO Interface
  .i_fifo_rdy                 (w_egress_fifo_rdy          ),
  .o_fifo_act                 (w_egress_fifo_act          ),
  .i_fifo_size                (w_egress_fifo_size         ),
  .i_fifo_data                (w_egress_fifo_data         ),
  .o_fifo_stb                 (w_egress_fifo_stb          ),
  .dbg_ready_drop             (dbg_ready_drop             )
);

/****************************************************************************
 * FIFO Multiplexer
 ****************************************************************************/
assign  w_egress_fifo_rdy           = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_rdy:
                                      (w_dat_fifo_sel)      ? w_e_data_fifo_rdy:
                                      1'b0;

assign  w_egress_fifo_size          = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_size:
                                      (w_dat_fifo_sel)      ? w_e_data_fifo_size:
                                      24'h0;

assign  w_egress_fifo_data          = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_data:
                                      (w_dat_fifo_sel)      ? w_e_data_fifo_data:
                                      32'h00;

assign  w_e_ctr_fifo_act            = (w_ctr_fifo_sel)      ? w_egress_fifo_act:
                                       1'b0;
assign  w_e_ctr_fifo_stb            = (w_ctr_fifo_sel)      ? w_egress_fifo_stb:
                                       1'b0;

assign  w_e_data_fifo_act           = (w_dat_fifo_sel)      ? w_egress_fifo_act:
                                       1'b0;
assign  w_e_data_fifo_stb           = (w_dat_fifo_sel)      ? w_egress_fifo_stb:
                                       1'b0;

/****************************************************************************
 * Temporary Debug Signals
 ****************************************************************************/

//This used to go to the wishbone slave device
//Need to create a flow controller
/****************************************************************************
 * AXI Signals from the user to the PCIE_A1 Core
 ****************************************************************************/
assign s_axis_tx_discont            = 0;
assign s_axis_tx_stream             = 0;  // Error forward packet
assign s_axis_tx_err_fwd            = 0;  // Stream packet
assign s_axis_tx_s6_not_used        = 0;  // Unused for V6

assign s_axis_tx_tuser              = {s_axis_tx_discont,
                                        s_axis_tx_stream,
                                        s_axis_tx_err_fwd,
                                        s_axis_tx_s6_not_used};

//Use this BAR Hist because it is buffered with the AXI transaction
assign o_bar_hit                    = m_axis_rx_tuser[8:2];
assign dbg_rerrfwd                  = m_axis_rx_tuser[1];


/****************************************************************************
 * Ingress Buffer Manager
 ****************************************************************************/

assign cfg_interrupt_di             = w_interrupt_msi_value;
assign w_rcb_128B_sel               = o_cfg_lcommand[3];


assign rx_np_ok                      = 1'b1;     // Allow Reception of Non-posted Traffic
assign rx_np_req                     = 1'b1;     // Always request Non-posted Traffic if available

assign tx_cfg_gnt                    = 1'b1;     // Always allow transmission of Config traffic within block

assign cfg_err_cor                   = 1'b0;     // Never report Correctable Error
assign cfg_err_ur                    = 1'b0;     // Never report UR
assign cfg_err_ecrc                  = 1'b0;     // Never report ECRC Error
assign cfg_err_cpl_timeout           = 1'b0;     // Never report Completion Timeout
assign cfg_err_cpl_abort             = 1'b0;     // Never report Completion Abort
assign cfg_err_cpl_unexpect          = 1'b0;     // Never report unexpected completion
assign cfg_err_posted                = 1'b0;     // Never qualify cfg_err_* inputs
assign cfg_err_locked                = 1'b0;     // Never qualify cfg_err_ur or cfg_err_cpl_abort
assign cfg_pm_wake                   = 1'b0;     // Never direct the core to send a PM_PME Message
assign cfg_trn_pending               = 1'b0;     // Never set the transaction pending bit in the Device Status Register
assign cfg_err_atomic_egress_blocked = 1'b0;     // Never report Atomic TLP blocked
assign cfg_err_internal_cor          = 1'b0;     // Never report internal error occurred
assign cfg_err_malformed             = 1'b0;     // Never report malformed error
assign cfg_err_mc_blocked            = 1'b0;     // Never report multi-cast TLP blocked
assign cfg_err_poisoned              = 1'b0;     // Never report poisoned TLP received
assign cfg_err_norecovery            = 1'b0;     // Never qualify cfg_err_poisoned or cfg_err_cpl_timeout
assign cfg_err_acs                   = 1'b0;     // Never report an ACS violation
assign cfg_err_internal_uncor        = 1'b0;     // Never report internal uncorrectable error
assign cfg_pm_halt_aspm_l0s          = 1'b0;     // Allow entry into L0s
assign cfg_pm_halt_aspm_l1           = 1'b0;     // Allow entry into L1
assign cfg_pm_force_state_en         = 1'b0;     // Do not qualify cfg_pm_force_state
assign cfg_pm_force_state            = 2'b00;    // Do not move force core into specific PM state

assign cfg_err_aer_headerlog         = 128'h0;   // Zero out the AER Header Log
assign cfg_aer_interrupt_msgnum      = 5'b00000; // Zero out the AER Root Error Status Register

assign cfg_interrupt_stat            = 1'b0;     // Never set the Interrupt Status bit
assign cfg_pciecap_interrupt_msgnum  = 5'b00000; // Zero out Interrupt Message Number

assign cfg_interrupt_assert          = 1'b0;     // Always drive interrupt de-assert
//assign cfg_interrupt                 = 1'b0;     // Never drive interrupt by qualifying cfg_interrupt_assert

assign pl_directed_link_change       = 2'b00;    // Never initiate link change
assign pl_directed_link_width        = 2'b00;    // Zero out directed link width
assign pl_directed_link_speed        = 1'b0;     // Zero out directed link speed
assign pl_directed_link_auton        = 1'b0;     // Zero out link autonomous input
assign pl_upstream_prefer_deemph     = 1'b1;     // Zero out preferred de-emphasis of upstream port

assign cfg_err_tlp_cpl_header        = 48'h0;    // Zero out the header information

assign cfg_mgmt_di                   = 32'h0;    // Zero out CFG MGMT input data bus
assign cfg_mgmt_byte_en              = 4'h0;     // Zero out CFG MGMT byte enables
assign cfg_mgmt_wr_en                = 1'b0;     // Do not write CFG space
assign cfg_mgmt_wr_readonly          = 1'b0;     // Never treat RO bit as RW
assign cfg_turnoff_ok                = 1'b0;






/****************************************************************************
 * Interrupt State Machine
 ****************************************************************************/
//asynchronous logic
//synchronous logic


assign  o_pcie_clkreq                   = 1'b0;
assign  o_user_link_up                  = user_lnk_up;
//assign  o_user_reset_out                = user_reset;
assign  o_sys_rst                       = user_reset;

assign  o_pcie_exp_tx_p                 = pci_exp_txp;
assign  o_pcie_exp_tx_n                 = pci_exp_txn;

assign  pci_exp_rxp                     = i_pcie_exp_rx_p;
assign  pci_exp_rxn                     = i_pcie_exp_rx_n;

assign  cfg_dsn                         = SERIAL_NUMBER;

//assign  sys_rst_n                       = i_pcie_reset_n;
assign  sys_rst_n_c                     = i_pcie_reset_n;
assign  sys_clk_p                       = i_pcie_clk_p;
assign  sys_clk_n                       = i_pcie_clk_n;

assign  o_clock_locked                  = PIPE_MMCM_LOCK_IN;
assign  o_lax_clk                       = PIPE_RXUSRCLK_IN;

endmodule
