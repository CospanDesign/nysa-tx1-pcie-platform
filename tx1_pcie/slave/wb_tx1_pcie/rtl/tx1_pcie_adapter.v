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
  parameter SERIAL_NUMBER     = 64'h000000000000C594,
  parameter PL_FAST_TRAIN     = "FALSE", // Simulation Speedup
  parameter PCIE_EXT_CLK      = "TRUE",  // Use External Clocking Module
  parameter C_DATA_WIDTH      = 64, // RX/TX interface data width
  parameter KEEP_WIDTH        = C_DATA_WIDTH / 8 // TSTRB width

)(
  input                     clk,
  input                     rst,
  output                    o_lax_clk,


  output                    o_user_link_up,
  output                    o_user_reset_out,
  output                    o_phy_rdy_n,
  output        [7:0]       o_pcie_rx_elec_idle,

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


  //High Speed PCIE Phy Interface
  // Tx
  output                    o_pcie_exp_tx_p,
  output                    o_pcie_exp_tx_n,

  // Rx
  input                     i_pcie_exp_rx_p,
  input                     i_pcie_exp_rx_n,

  // Clock
  input                     i_pcie_clk_p,
  input                     i_pcie_clk_n,

  output                    o_plllkdet,
  output                    o_clock_locked,

  // PCIE Control
  output        [15:0]      o_rx_data,
  output        [1:0]       o_rx_data_k,

  output        [1:0]       o_rx_byte_is_comma,
  output                    o_rx_byte_is_aligned,



  input                     i_pcie_reset_n,
  output                    o_pcie_wake_n,
  output                    o_pcie_clkreq
);


//local parameters
localparam                                    TCQ = 1;
//registes/wires

//  wire                                        sys_rst_n;
  wire                                        pci_exp_txp;
  wire                                        pci_exp_txn;
  wire                                        pci_exp_rxp;
  wire                                        pci_exp_rxn;

  wire                                        sys_clk_p;
  wire                                        sys_clk_n;

  (* KEEP *) wire                                        sys_clk;


  wire                                        user_clk;
  wire                                        user_reset;
  wire                                        user_lnk_up;


  // Tx
//  wire [5:0]                                  tx_buf_av;
//  wire                                        tx_cfg_req;
//  wire                                        tx_err_drop;
  wire                                        tx_cfg_gnt;
  wire                                        s_axis_tx_tready;
  wire [3:0]                                  s_axis_tx_tuser;
  wire [C_DATA_WIDTH-1:0]                     s_axis_tx_tdata;
  wire [KEEP_WIDTH-1:0]                       s_axis_tx_tkeep;
  wire                                        s_axis_tx_tlast;
  wire                                        s_axis_tx_tvalid;


  // Rx
  wire [C_DATA_WIDTH-1:0]                     m_axis_rx_tdata;
  wire [KEEP_WIDTH-1:0]                       m_axis_rx_tkeep;
  wire                                        m_axis_rx_tlast;
  wire                                        m_axis_rx_tvalid;
  wire                                        m_axis_rx_tready;
  wire  [21:0]                                m_axis_rx_tuser;
  wire                                        rx_np_ok;
  wire                                        rx_np_req;

  // Flow Control
//  wire [11:0]                                 fc_cpld;
//  wire [7:0]                                  fc_cplh;
//  wire [11:0]                                 fc_npd;
//  wire [7:0]                                  fc_nph;
//  wire [11:0]                                 fc_pd;
//  wire [7:0]                                  fc_ph;
  wire [2:0]                                  fc_sel;


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
//  wire                                        cfg_err_cpl_rdy;
  wire                                        cfg_interrupt;
//  wire                                        cfg_interrupt_rdy;
  wire                                        cfg_interrupt_assert;
  wire   [7:0]                                cfg_interrupt_di;
//  wire   [7:0]                                cfg_interrupt_do;
//  wire   [2:0]                                cfg_interrupt_mmenable;
//  wire                                        cfg_interrupt_msienable;
//  wire                                        cfg_interrupt_msixenable;
//  wire                                        cfg_interrupt_msixfm;
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
//  wire  [15:0]                                cfg_status;
//  wire  [15:0]                                cfg_command;
//  wire  [15:0]                                cfg_dcommand;
//  wire  [15:0]                                cfg_lcommand;
//  wire  [15:0]                                cfg_dcommand2;
  wire  [63:0]                                cfg_dsn;
  wire [127:0]                                cfg_err_aer_headerlog;
  wire   [4:0]                                cfg_aer_interrupt_msgnum;
//  wire                                        cfg_err_aer_headerlog_set;
//  wire                                        cfg_aer_ecrc_check_en;
//  wire                                        cfg_aer_ecrc_gen_en;

  wire  [31:0]                                cfg_mgmt_di;
  wire   [3:0]                                cfg_mgmt_byte_en;
  wire   [9:0]                                cfg_mgmt_dwaddr;
  wire                                        cfg_mgmt_wr_en;
  wire                                        cfg_mgmt_rd_en;
  wire                                        cfg_mgmt_wr_readonly;


  //-------------------------------------------------------
  // 4. Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------

//  wire [2:0]                                  pl_initial_link_width;
//  wire [1:0]                                  pl_lane_reversal_mode;
//  wire                                        pl_link_gen2_cap;
//  wire                                        pl_link_partner_gen2_supported;
//  wire                                        pl_link_upcfg_cap;
//  wire                                        pl_received_hot_rst;
//  wire                                        pl_sel_lnk_rate;
//  wire [1:0]                                  pl_sel_lnk_width;
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


  localparam USER_CLK_FREQ = 1;
  localparam USER_CLK2_DIV2 = "FALSE";
  localparam USERCLK2_FREQ = (USER_CLK2_DIV2 == "TRUE") ?
                             (USER_CLK_FREQ == 4) ? 3 :
                             (USER_CLK_FREQ == 3) ? 2 : USER_CLK_FREQ :
                             USER_CLK_FREQ;
  //-------------------------------------------------------
  //IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));

   IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));


  reg user_reset_q;
  reg user_lnk_up_q;
  reg PIPE_MMCM_RST_N = 1'b1;

  always @(posedge user_clk) begin
    user_reset_q  <= user_reset;
    user_lnk_up_q <= user_lnk_up;
  end




  // Generate External Clock Module if External Clocking is selected
  generate
    if (PCIE_EXT_CLK == "TRUE") begin : ext_clk

      //---------- PIPE Clock Module -------------------------------------------------
      pcie_7x_v1_11_0_pipe_clock #
      (
          .PCIE_ASYNC_EN                  ( "FALSE" ),     // PCIe async enable
          .PCIE_TXBUF_EN                  ( "FALSE" ),     // PCIe TX buffer enable for Gen1/Gen2 only
          .PCIE_LANE                      ( 6'h01 ),     // PCIe number of lanes
          // synthesis translate_off
          .PCIE_LINK_SPEED                ( 2 ),
          // synthesis translate_on
          .PCIE_REFCLK_FREQ               ( 0 ),     // PCIe reference clock frequency
          .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ +1 ),     // PCIe user clock 1 frequency
          .PCIE_USERCLK2_FREQ             ( USERCLK2_FREQ +1 ),     // PCIe user clock 2 frequency
          .PCIE_DEBUG_MODE                ( 0 )
      )
      pipe_clock_i
      (

          //---------- Input -------------------------------------
          .CLK_CLK                        ( sys_clk ),
          .CLK_TXOUTCLK                   ( PIPE_TXOUTCLK_OUT ),     // Reference clock from lane 0
          .CLK_RXOUTCLK_IN                ( PIPE_RXOUTCLK_OUT ),
         // .CLK_RST_N                      ( 1'b1 ),
          .CLK_RST_N                      ( PIPE_MMCM_RST_N ),
          .CLK_PCLK_SEL                   ( PIPE_PCLK_SEL_OUT ),
          .CLK_GEN3                       ( PIPE_GEN3_OUT ),

          //---------- Output ------------------------------------
          .CLK_PCLK                       ( PIPE_PCLK_IN ),
          .CLK_RXUSRCLK                   ( PIPE_RXUSRCLK_IN ),
          .CLK_RXOUTCLK_OUT               ( PIPE_RXOUTCLK_IN ),
          .CLK_DCLK                       ( PIPE_DCLK_IN ),
          .CLK_OOBCLK                     ( PIPE_OOBCLK_IN ),
          .CLK_USERCLK1                   ( PIPE_USERCLK1_IN ),
          .CLK_USERCLK2                   ( PIPE_USERCLK2_IN ),
          .CLK_MMCM_LOCK                  ( PIPE_MMCM_LOCK_IN ),
          .o_clk_in_stopped               ( o_clk_in_stopped)

      );
    end  else begin
      assign pipe_pclk_in      = 1'b0;
      assign pipe_rxusrclk_in  = 1'b0;
      assign pipe_rxoutclk_in  = 0;
      assign pipe_dclk_in      = 1'b0;
      assign pipe_userclk1_in  = 1'b0;
      assign pipe_userclk2_in  = 1'b0;
      assign pipe_mmcm_lock_in = 1'b0;
      assign pipe_oobclk_in    = 1'b0;
    end

  endgenerate

pcie_7x_v1_11_0 #(
  .PL_FAST_TRAIN      ( PL_FAST_TRAIN ),
  .PCIE_EXT_CLK       ( PCIE_EXT_CLK )
) pcie_7x_v1_11_0_i
 (

  //----------------------------------------------------------------------------------------------------------------//
  // 1. PCI Express (pci_exp) Interface                                                                             //
  //----------------------------------------------------------------------------------------------------------------//

  // Tx
  .pci_exp_txn                                ( pci_exp_txn ),
  .pci_exp_txp                                ( pci_exp_txp ),

  // Rx
  .pci_exp_rxn                                ( pci_exp_rxn ),
  .pci_exp_rxp                                ( pci_exp_rxp ),

  //----------------------------------------------------------------------------------------------------------------//
  // 2. Clocking Interface                                                                                          //
  //----------------------------------------------------------------------------------------------------------------//
  .PIPE_PCLK_IN                              ( PIPE_PCLK_IN ),
  .PIPE_RXUSRCLK_IN                          ( PIPE_RXUSRCLK_IN ),
  .PIPE_RXOUTCLK_IN                          ( PIPE_RXOUTCLK_IN ),
  .PIPE_DCLK_IN                              ( PIPE_DCLK_IN ),
  .PIPE_USERCLK1_IN                          ( PIPE_USERCLK1_IN ),
  .PIPE_OOBCLK_IN                            ( PIPE_OOBCLK_IN ),
  .PIPE_USERCLK2_IN                          ( PIPE_USERCLK2_IN ),
  .PIPE_MMCM_LOCK_IN                         ( PIPE_MMCM_LOCK_IN ),

  .PIPE_TXOUTCLK_OUT                         ( PIPE_TXOUTCLK_OUT ),
  .PIPE_RXOUTCLK_OUT                         ( PIPE_RXOUTCLK_OUT ),
  .PIPE_PCLK_SEL_OUT                         ( PIPE_PCLK_SEL_OUT ),
  .PIPE_GEN3_OUT                             ( PIPE_GEN3_OUT ),


  //----------------------------------------------------------------------------------------------------------------//
  // 3. AXI-S Interface                                                                                             //
  //----------------------------------------------------------------------------------------------------------------//

  // Common
  .user_clk_out                               ( user_clk ),
  .user_reset_out                             ( user_reset ),
  .user_lnk_up                                ( user_lnk_up ),

  // TX

  .tx_buf_av                                  ( ),
  .tx_err_drop                                ( ),
  .tx_cfg_req                                 ( ),
  .s_axis_tx_tready                           ( s_axis_tx_tready ),
  .s_axis_tx_tdata                            ( s_axis_tx_tdata ),
  .s_axis_tx_tkeep                            ( s_axis_tx_tkeep ),
  .s_axis_tx_tuser                            ( s_axis_tx_tuser ),
  .s_axis_tx_tlast                            ( s_axis_tx_tlast ),
  .s_axis_tx_tvalid                           ( s_axis_tx_tvalid ),

  .tx_cfg_gnt                                 ( tx_cfg_gnt ),

  // Rx
  .m_axis_rx_tdata                            ( m_axis_rx_tdata ),
  .m_axis_rx_tkeep                            ( m_axis_rx_tkeep ),
  .m_axis_rx_tlast                            ( m_axis_rx_tlast ),
  .m_axis_rx_tvalid                           ( m_axis_rx_tvalid ),
  .m_axis_rx_tready                           ( m_axis_rx_tready ),
  .m_axis_rx_tuser                            ( m_axis_rx_tuser ),
  .rx_np_ok                                   ( rx_np_ok ),
  .rx_np_req                                  ( rx_np_req ),

  // Flow Control
  .fc_cpld                                    ( ),
  .fc_cplh                                    ( ),
  .fc_npd                                     ( ),
  .fc_nph                                     ( ),
  .fc_pd                                      ( ),
  .fc_ph                                      ( ),
  .fc_sel                                     ( fc_sel ),


  //----------------------------------------------------------------------------------------------------------------//
  // 4. Configuration (CFG) Interface                                                                               //
  //----------------------------------------------------------------------------------------------------------------//

  //------------------------------------------------//
  // EP and RP                                      //
  //------------------------------------------------//
  .cfg_mgmt_do                                ( ),
  .cfg_mgmt_rd_wr_done                        ( ),

  .cfg_status                                 ( o_cfg_status ),
  .cfg_command                                ( o_cfg_command ),
  .cfg_dstatus                                ( o_cfg_dstatus ),
  .cfg_lstatus                                ( o_cfg_lstatus ),
  .cfg_pcie_link_state                        ( o_cfg_pcie_link_state ),
  .cfg_dcommand                               ( o_cfg_dcommand ),
  .cfg_lcommand                               ( o_cfg_lcommand ),
  .cfg_dcommand2                              ( o_cfg_dcommand2 ),

  .cfg_pmcsr_pme_en                           ( ),
  .cfg_pmcsr_powerstate                       ( ),
  .cfg_pmcsr_pme_status                       ( ),
  .cfg_received_func_lvl_rst                  ( ),

  // Management Interface
  .cfg_mgmt_di                                ( cfg_mgmt_di ),
  .cfg_mgmt_byte_en                           ( cfg_mgmt_byte_en ),
  .cfg_mgmt_dwaddr                            ( cfg_mgmt_dwaddr ),
  .cfg_mgmt_wr_en                             ( cfg_mgmt_wr_en ),
  .cfg_mgmt_rd_en                             ( cfg_mgmt_rd_en ),
  .cfg_mgmt_wr_readonly                       ( cfg_mgmt_wr_readonly ),

  // Error Reporting Interface
  .cfg_err_ecrc                               ( cfg_err_ecrc ),
  .cfg_err_ur                                 ( cfg_err_ur ),
  .cfg_err_cpl_timeout                        ( cfg_err_cpl_timeout ),
  .cfg_err_cpl_unexpect                       ( cfg_err_cpl_unexpect ),
  .cfg_err_cpl_abort                          ( cfg_err_cpl_abort ),
  .cfg_err_posted                             ( cfg_err_posted ),
  .cfg_err_cor                                ( cfg_err_cor ),
  .cfg_err_atomic_egress_blocked              ( cfg_err_atomic_egress_blocked ),
  .cfg_err_internal_cor                       ( cfg_err_internal_cor ),
  .cfg_err_malformed                          ( cfg_err_malformed ),
  .cfg_err_mc_blocked                         ( cfg_err_mc_blocked ),
  .cfg_err_poisoned                           ( cfg_err_poisoned ),
  .cfg_err_norecovery                         ( cfg_err_norecovery ),
  .cfg_err_tlp_cpl_header                     ( cfg_err_tlp_cpl_header ),
  .cfg_err_cpl_rdy                            (  ),
  .cfg_err_locked                             ( cfg_err_locked ),
  .cfg_err_acs                                ( cfg_err_acs ),
  .cfg_err_internal_uncor                     ( cfg_err_internal_uncor ),

  .cfg_trn_pending                            ( cfg_trn_pending ),
  .cfg_pm_halt_aspm_l0s                       ( cfg_pm_halt_aspm_l0s ),
  .cfg_pm_halt_aspm_l1                        ( cfg_pm_halt_aspm_l1 ),
  .cfg_pm_force_state_en                      ( cfg_pm_force_state_en ),
  .cfg_pm_force_state                         ( cfg_pm_force_state ),

  .cfg_dsn                                    ( cfg_dsn ),

  //------------------------------------------------//
  // EP Only                                        //
  //------------------------------------------------//
  .cfg_interrupt                              ( cfg_interrupt ),
  .cfg_interrupt_rdy                          (  ),
  .cfg_interrupt_assert                       ( cfg_interrupt_assert ),
  .cfg_interrupt_di                           ( cfg_interrupt_di ),
  .cfg_interrupt_do                           ( ),
  .cfg_interrupt_mmenable                     ( ),
  .cfg_interrupt_msienable                    ( ),
  .cfg_interrupt_msixenable                   ( ),
  .cfg_interrupt_msixfm                       ( ),
  .cfg_interrupt_stat                         ( cfg_interrupt_stat ),
  .cfg_pciecap_interrupt_msgnum               ( cfg_pciecap_interrupt_msgnum ),
  .cfg_to_turnoff                             ( cfg_to_turnoff ),
  .cfg_turnoff_ok                             ( cfg_turnoff_ok ),
  .cfg_bus_number                             ( cfg_bus_number ),
  .cfg_device_number                          ( cfg_device_number ),
  .cfg_function_number                        ( cfg_function_number ),
  .cfg_pm_wake                                ( cfg_pm_wake ),

  //------------------------------------------------//
  // RP Only                                        //
  //------------------------------------------------//
  .cfg_pm_send_pme_to                         ( 1'b0 ),
  .cfg_ds_bus_number                          ( 8'b0 ),
  .cfg_ds_device_number                       ( 5'b0 ),
  .cfg_ds_function_number                     ( 3'b0 ),
  .cfg_mgmt_wr_rw1c_as_rw                     ( 1'b0 ),
  .cfg_msg_received                           ( ),
  .cfg_msg_data                               ( ),

  .cfg_bridge_serr_en                         ( ),
  .cfg_slot_control_electromech_il_ctl_pulse  ( ),
  .cfg_root_control_syserr_corr_err_en        ( ),
  .cfg_root_control_syserr_non_fatal_err_en   ( ),
  .cfg_root_control_syserr_fatal_err_en       ( ),
  .cfg_root_control_pme_int_en                ( ),
  .cfg_aer_rooterr_corr_err_reporting_en      ( ),
  .cfg_aer_rooterr_non_fatal_err_reporting_en ( ),
  .cfg_aer_rooterr_fatal_err_reporting_en     ( ),
  .cfg_aer_rooterr_corr_err_received          ( ),
  .cfg_aer_rooterr_non_fatal_err_received     ( ),
  .cfg_aer_rooterr_fatal_err_received         ( ),

  .cfg_msg_received_err_cor                   ( ),
  .cfg_msg_received_err_non_fatal             ( ),
  .cfg_msg_received_err_fatal                 ( ),
  .cfg_msg_received_pm_as_nak                 ( ),
  .cfg_msg_received_pme_to_ack                ( ),
  .cfg_msg_received_assert_int_a              ( ),
  .cfg_msg_received_assert_int_b              ( ),
  .cfg_msg_received_assert_int_c              ( ),
  .cfg_msg_received_assert_int_d              ( ),
  .cfg_msg_received_deassert_int_a            ( ),
  .cfg_msg_received_deassert_int_b            ( ),
  .cfg_msg_received_deassert_int_c            ( ),
  .cfg_msg_received_deassert_int_d            ( ),

   .cfg_msg_received_pm_pme                   ( ),
   .cfg_msg_received_setslotpowerlimit        ( ),
  //----------------------------------------------------------------------------------------------------------------//
  // 5. Physical Layer Control and Status (PL) Interface                                                            //
  //----------------------------------------------------------------------------------------------------------------//
  .pl_directed_link_change                    ( pl_directed_link_change ),
  .pl_directed_link_width                     ( pl_directed_link_width ),
  .pl_directed_link_speed                     ( pl_directed_link_speed ),
  .pl_directed_link_auton                     ( pl_directed_link_auton ),
  .pl_upstream_prefer_deemph                  ( pl_upstream_prefer_deemph ),



  .pl_sel_lnk_rate                            ( o_pl_sel_lnk_rate         ),
  .pl_sel_lnk_width                           ( o_pl_sel_lnk_width        ),
  .pl_ltssm_state                             ( o_pl_ltssm_state          ),
  .pl_lane_reversal_mode                      (  ),

  .pl_phy_lnk_up                              ( ),
  .pl_tx_pm_state                             ( ),
  .pl_rx_pm_state                             ( ),

  .pl_link_upcfg_cap                          (  ),
  .pl_link_gen2_cap                           (  ),
  .pl_link_partner_gen2_supported             (  ),
  .pl_initial_link_width                      ( o_pl_initial_link_width ),

  .pl_directed_change_done                    ( ),

  //------------------------------------------------//
  // EP Only                                        //
  //------------------------------------------------//
  .pl_received_hot_rst                        ( ),

  //------------------------------------------------//
  // RP Only                                        //
  //------------------------------------------------//
  .pl_transmit_hot_rst                        ( 1'b0 ),
  .pl_downstream_deemph_source                ( 1'b0 ),

  //----------------------------------------------------------------------------------------------------------------//
  // 6. AER Interface                                                                                               //
  //----------------------------------------------------------------------------------------------------------------//

  .cfg_err_aer_headerlog                      ( cfg_err_aer_headerlog ),
  .cfg_aer_interrupt_msgnum                   ( cfg_aer_interrupt_msgnum ),
  .cfg_err_aer_headerlog_set                  ( ),
  .cfg_aer_ecrc_check_en                      ( ),
  .cfg_aer_ecrc_gen_en                        ( ),

  //----------------------------------------------------------------------------------------------------------------//
  // 7. VC interface                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  .cfg_vc_tcvc_map                            ( ),

  //----------------------------------------------------------------------------------------------------------------//
  // 8. System  (SYS) Interface                                                                                     //
  //----------------------------------------------------------------------------------------------------------------//

  .pipe_rx0_status_gt                         ( pipe_rx0_status_gt   ),
  .pipe_rx0_phy_status_gt                     ( pipe_rx0_phy_status_gt  ),
  .i_tx_diff_ctr                              ( i_tx_diff_ctr       ),

  .o_rx_data                                  ( o_rx_data           ),
  .o_rx_data_k                                ( o_rx_data_k         ),

  .o_rx_byte_is_comma                         ( o_rx_byte_is_comma   ),
  .o_rx_byte_is_aligned                       ( o_rx_byte_is_aligned ),



  .PIPE_MMCM_RST_N                            ( PIPE_MMCM_RST_N     ),        // Async      | Async
  .sys_clk                                    ( sys_clk             ),
  .sys_rst_n                                  ( sys_rst_n_c         )
);


//----------------------------------------------------------------------------------------------------------------//
// User App                                                                                                       //
//----------------------------------------------------------------------------------------------------------------//
pcie_app_7x  #(
  .C_DATA_WIDTH( C_DATA_WIDTH ),
  .TCQ( TCQ )

) app (

  //----------------------------------------------------------------------------------------------------------------//
  // 1. AXI-S Interface                                                                                             //
  //----------------------------------------------------------------------------------------------------------------//

  // Common
  .user_clk                       ( user_clk ),
  .user_reset                     ( user_reset_q ),
  .user_lnk_up                    ( user_lnk_up_q ),

  // Tx
//  .tx_buf_av                      ( tx_buf_av ),
//  .tx_cfg_req                     ( tx_cfg_req ),
//  .tx_err_drop                    ( tx_err_drop ),
  .s_axis_tx_tready               ( s_axis_tx_tready ),
  .s_axis_tx_tdata                ( s_axis_tx_tdata ),
  .s_axis_tx_tkeep                ( s_axis_tx_tkeep ),
  .s_axis_tx_tuser                ( s_axis_tx_tuser ),
  .s_axis_tx_tlast                ( s_axis_tx_tlast ),
  .s_axis_tx_tvalid               ( s_axis_tx_tvalid ),
  .tx_cfg_gnt                     ( tx_cfg_gnt ),

  // Rx
  .m_axis_rx_tdata                ( m_axis_rx_tdata ),
  .m_axis_rx_tkeep                ( m_axis_rx_tkeep ),
  .m_axis_rx_tlast                ( m_axis_rx_tlast ),
  .m_axis_rx_tvalid               ( m_axis_rx_tvalid ),
  .m_axis_rx_tready               ( m_axis_rx_tready ),
  .m_axis_rx_tuser                ( m_axis_rx_tuser ),
  .rx_np_ok                       ( rx_np_ok ),
  .rx_np_req                      ( rx_np_req ),

  // Flow Control
//  .fc_cpld                        ( fc_cpld ),
//  .fc_cplh                        ( fc_cplh ),
//  .fc_npd                         ( fc_npd ),
//  .fc_nph                         ( fc_nph ),
//  .fc_pd                          ( fc_pd ),
//  .fc_ph                          ( fc_ph ),
  .fc_sel                         ( fc_sel ),

  //----------------------------------------------------------------------------------------------------------------//
  // 2. Configuration (CFG) Interface                                                                               //
  //----------------------------------------------------------------------------------------------------------------//
  .cfg_err_cor                    ( cfg_err_cor ),
  .cfg_err_atomic_egress_blocked  ( cfg_err_atomic_egress_blocked ),
  .cfg_err_internal_cor           ( cfg_err_internal_cor ),
  .cfg_err_malformed              ( cfg_err_malformed ),
  .cfg_err_mc_blocked             ( cfg_err_mc_blocked ),
  .cfg_err_poisoned               ( cfg_err_poisoned ),
  .cfg_err_norecovery             ( cfg_err_norecovery ),
  .cfg_err_ur                     ( cfg_err_ur ),
  .cfg_err_ecrc                   ( cfg_err_ecrc ),
  .cfg_err_cpl_timeout            ( cfg_err_cpl_timeout ),
  .cfg_err_cpl_abort              ( cfg_err_cpl_abort ),
  .cfg_err_cpl_unexpect           ( cfg_err_cpl_unexpect ),
  .cfg_err_posted                 ( cfg_err_posted ),
  .cfg_err_locked                 ( cfg_err_locked ),
  .cfg_err_acs                    ( cfg_err_acs ), //1'b0 ),
  .cfg_err_internal_uncor         ( cfg_err_internal_uncor ), //1'b0 ),
  .cfg_err_tlp_cpl_header         ( cfg_err_tlp_cpl_header ),
//  .cfg_err_cpl_rdy                ( cfg_err_cpl_rdy ),
  .cfg_interrupt                  ( cfg_interrupt ),
//  .cfg_interrupt_rdy              ( cfg_interrupt_rdy ),
  .cfg_interrupt_assert           ( cfg_interrupt_assert ),
  .cfg_interrupt_di               ( cfg_interrupt_di ),
//  .cfg_interrupt_do               ( cfg_interrupt_do ),
//  .cfg_interrupt_mmenable         ( cfg_interrupt_mmenable ),
//  .cfg_interrupt_msienable        ( cfg_interrupt_msienable ),
//  .cfg_interrupt_msixenable       ( cfg_interrupt_msixenable ),
//  .cfg_interrupt_msixfm           ( cfg_interrupt_msixfm ),
  .cfg_interrupt_stat             ( cfg_interrupt_stat ),
  .cfg_pciecap_interrupt_msgnum   ( cfg_pciecap_interrupt_msgnum ),
  .cfg_turnoff_ok                 ( cfg_turnoff_ok ),
  .cfg_to_turnoff                 ( cfg_to_turnoff ),

  .cfg_trn_pending                ( cfg_trn_pending ),
  .cfg_pm_halt_aspm_l0s           ( cfg_pm_halt_aspm_l0s ),
  .cfg_pm_halt_aspm_l1            ( cfg_pm_halt_aspm_l1 ),
  .cfg_pm_force_state_en          ( cfg_pm_force_state_en ),
  .cfg_pm_force_state             ( cfg_pm_force_state ),

  .cfg_pm_wake                    ( cfg_pm_wake ),
  .cfg_bus_number                 ( cfg_bus_number ),
  .cfg_device_number              ( cfg_device_number ),
  .cfg_function_number            ( cfg_function_number ),
//  .cfg_status                     ( cfg_status ),
//  .cfg_command                    ( cfg_command ),
//  .cfg_dstatus                    ( cfg_dstatus ),
//  .cfg_dcommand                   ( cfg_dcommand ),
//  .cfg_lstatus                    ( cfg_lstatus ),
//  .cfg_lcommand                   ( cfg_lcommand ),
//  .cfg_dcommand2                  ( cfg_dcommand2 ),
//  .cfg_pcie_link_state            ( cfg_pcie_link_state ),
  .cfg_dsn                        ( cfg_dsn ),

  //----------------------------------------------------------------------------------------------------------------//
  // 3. Management (MGMT) Interface                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//
  .cfg_mgmt_di                    ( cfg_mgmt_di ),
  .cfg_mgmt_byte_en               ( cfg_mgmt_byte_en ),
  .cfg_mgmt_dwaddr                ( cfg_mgmt_dwaddr ),
  .cfg_mgmt_wr_en                 ( cfg_mgmt_wr_en ),
  .cfg_mgmt_rd_en                 ( cfg_mgmt_rd_en ),
  .cfg_mgmt_wr_readonly           ( cfg_mgmt_wr_readonly ),

  //----------------------------------------------------------------------------------------------------------------//
  // 3. Advanced Error Reporting (AER) Interface                                                                    //
  //----------------------------------------------------------------------------------------------------------------//
  .cfg_err_aer_headerlog          ( cfg_err_aer_headerlog ),
  .cfg_aer_interrupt_msgnum       ( cfg_aer_interrupt_msgnum ),
//  .cfg_err_aer_headerlog_set      ( cfg_err_aer_headerlog_set ),
//  .cfg_aer_ecrc_check_en          ( cfg_aer_ecrc_check_en ),
//  .cfg_aer_ecrc_gen_en            ( cfg_aer_ecrc_gen_en ),

  //----------------------------------------------------------------------------------------------------------------//
  // 4. Physical Layer Control and Status (PL) Interface                                                            //
  //----------------------------------------------------------------------------------------------------------------//
//  .pl_initial_link_width          ( pl_initial_link_width ),
//  .pl_lane_reversal_mode          ( pl_lane_reversal_mode ),
//  .pl_link_gen2_cap               ( pl_link_gen2_cap ),
//  .pl_link_partner_gen2_supported ( pl_link_partner_gen2_supported ),
//  .pl_link_upcfg_cap              ( pl_link_upcfg_cap ),
//  .pl_ltssm_state                 ( pl_ltssm_state ),
//  .pl_received_hot_rst            ( pl_received_hot_rst ),
//  .pl_sel_lnk_rate                ( pl_sel_lnk_rate ),
//  .pl_sel_lnk_width               ( pl_sel_lnk_width ),
  .pl_directed_link_auton         ( pl_directed_link_auton ),
  .pl_directed_link_change        ( pl_directed_link_change ),
  .pl_directed_link_speed         ( pl_directed_link_speed ),
  .pl_directed_link_width         ( pl_directed_link_width ),
  .pl_upstream_prefer_deemph      ( pl_upstream_prefer_deemph )

);


assign  o_pcie_clkreq                   = 1'b0;
assign  o_user_link_up                  = user_lnk_up;
assign  o_user_reset_out                = user_reset;

assign  o_pcie_exp_tx_p                 = pci_exp_txp;
assign  o_pcie_exp_tx_n                 = pci_exp_txn;

assign  pci_exp_rxp                     = i_pcie_exp_rx_p;
assign  pci_exp_rxn                     = i_pcie_exp_rx_n;

assign  o_phy_rd_n                      = 0;
assign  o_pcie_rx_elec_idle             = 0;


//assign  sys_rst_n                       = i_pcie_reset_n;
assign  sys_rst_n_c                     = i_pcie_reset_n;
assign  sys_clk_p                       = i_pcie_clk_p;
assign  sys_clk_n                       = i_pcie_clk_n;

assign  o_clock_locked                  = PIPE_MMCM_LOCK_IN;
assign  o_lax_clk                       = PIPE_RXUSRCLK_IN;

endmodule
