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
  parameter SERIAL_NUMBER = 64'h000000000000C594
)(
  input                     clk,
  input                     rst,

  //High Speed PCIE Phy Interface
  // Tx
  output        [3:0]       o_pci_exp_tx_p,
  output        [3:0]       o_pci_exp_tx_n,

  // Rx
  input         [3:0]       i_pci_exp_rx_p,
  input         [3:0]       i_pci_exp_rx_n,

  // Clock
  input                     i_pcie_clk_p,
  input                     i_pcie_clk_n,

  // PCIE Control
  input                     i_pcie_reset_n,
  output                    o_pcie_wake_n
);
//local parameters
//registes/wires

wire              w_sys_clk;

wire              w_user_clk_out;
wire              w_user_reset_out;
wire              w_user_link_up;


//Not Used
wire  [5:0]       w_tx_buf_av;
wire              w_tx_err_drop;

wire              w_pl_sel_lnk_rate;
wire  [1:0]       w_pl_sel_lnk_width;
wire  [5:0]       w_pl_ltssm_state;
wire  [1:0]       w_pl_lane_reversal_mode;
wire              w_pl_phy_lnk_up;
wire  [2:0]       w_pl_tx_pm_state;
wire  [1:0]       w_pl_rx_pm_state;
wire              w_pl_link_upcfg_cap;
wire              w_pl_link_gen2_cap;
wire              w_pl_link_partner_gen2_supported;
wire  [2:0]       w_pl_initial_link_width;
wire              w_pl_directed_change_done;
wire              w_pl_received_hot_rst;

//End Not Used

wire              w_tx_cfg_req;
wire              w_tx_cfg_gnt;

wire              w_s_axis_tx_tready;
wire  [63:0]      w_s_axis_tx_tdata;
wire  [7:0]       w_s_axis_tx_tkeep;
wire  [3:0]       w_s_axis_tx_tuser;
wire              w_s_axis_tx_tlast;
wire              w_s_axis_tx_tvalid;

wire  [63:0]      w_m_axis_rx_tdata;
wire  [7:0]       w_m_axis_rx_tkeep;
wire              w_m_axis_rx_tlast;
wire              w_m_axis_rx_tvalid;
wire              w_m_axis_rx_tready;
wire  [21:0]      w_m_axis_rx_tuser;
wire              w_rx_np_ok;
wire              w_rx_np_req;

wire  [11:0]      w_fc_cpld;
wire  [7:0]       w_fc_cplh;
wire  [11:0]      w_fc_npd;
wire  [7:0]       w_fc_nph;
wire  [11:0]      w_fc_pd;
wire  [7:0]       w_fc_ph;
wire  [2:0]       w_fc_sel;

wire  [15:0]      w_cfg_status;
wire  [15:0]      w_cfg_command;
wire  [15:0]      w_cfg_dstatus;
wire  [15:0]      w_cfg_dcommand;
wire  [15:0]      w_cfg_lstatus;
wire  [15:0]      w_cfg_lcommand;
wire  [15:0]      w_cfg_dcommand2;

wire              w_rcb_138B_sel;

wire  [2:0]       w_cfg_pcie_link_state;

wire              w_cfg_pmcsr_pme_en;
wire  [1:0]       w_cfg_pmcsr_powerstate;
wire              w_cfg_pmcsr_pme_status;
wire              w_cfg_received_func_lvl_rst;




//MGMT Configuration
wire  [31:0]      w_cfg_mgmt_do;
wire              w_cfg_mgmt_rd_wr_done;

wire  [31:0]      w_cfg_mgmt_di;
wire  [3:0]       w_cfg_mgmt_byte_en;
wire  [9:0]       w_cfg_mgmt_dwaddr;
wire              w_cfg_mgmt_wr_en;
wire              w_cfg_mgmt_rd_en;
wire              w_cfg_mgmt_wr_readonly;

//Error Output
wire              w_cfg_err_ecrc;
wire              w_cfg_err_ur;
wire              w_cfg_err_cpl_timeout;
wire              w_cfg_err_cpl_unexpect;
wire              w_cfg_err_cpl_abort;
wire              w_cfg_err_posted;
wire              w_cfg_err_cor;
wire              w_cfg_err_atomic_egress_blocked;
wire              w_cfg_err_internal_cor;
wire              w_cfg_err_malformed;
wire              w_cfg_err_mc_blocked;
wire              w_cfg_err_poisoned;
wire              w_cfg_err_norecovery;
wire              w_cfg_err_locked;
wire              w_cfg_err_acs;
wire              w_cfg_err_internal_uncor;

wire              w_cfg_err_cpl_rdy;
wire  [47:0]      w_cfg_err_tlp_cpl_header;

wire              w_cfg_trn_pending;
wire              w_cfg_pm_halt_aspm_l0s;
wire              w_cfg_pm_halt_aspm_l1;
wire              w_cfg_pm_force_state_en;
wire  [1:0]       w_cfg_pm_force_state;
wire  [63:0]      w_cfg_dsn;

wire              w_cfg_interrupt;
wire              w_cfg_interrupt_rdy;
wire              w_cfg_interrupt_assert;
wire  [7:0]       w_cfg_interrupt_di;
wire  [7:0]       w_cfg_interrupt_do;
wire  [2:0]       w_cfg_interrupt_mmenable;
wire              w_cfg_interrupt_msienable;
wire              w_cfg_interrupt_msixenable;
wire              w_cfg_interrupt_msixfm;
wire              w_cfg_interrupt_stat;
wire  [4:0]       w_cfg_pciecap_interrupt_msgnum;



wire  [7:0]       w_interrupt_msi_value;


wire              w_cfg_to_turnoff;
wire              w_cfg_turnoff_ok;

wire  [7:0]       w_cfg_bus_number;
wire  [4:0]       w_cfg_device_number;
wire  [2:0]       w_cfg_function_number;
wire              w_cfg_pm_wake;




wire              w_cfg_pm_send_pme_to;
wire  [7:0]       w_cfg_ds_bus_number;
wire  [4:0]       w_cfg_ds_device_number;
wire  [2:0]       w_cfg_ds_function_number;


wire              w_cfg_mgmt_wr_rw1c_as_rw;
wire              w_cfg_msg_received;
wire  [15:0]      w_cfg_msg_data;



wire              w_cfg_bridge_serr_en;



wire              w_cfg_slot_control_electromech_il_ctl_pulse;
wire              w_cfg_root_control_syserr_corr_err_en;
wire              w_cfg_root_control_syserr_non_fatal_err_en;
wire              w_cfg_root_control_syserr_fatal_err_en;
wire              w_cfg_root_control_pme_int_en;
wire              w_cfg_aer_rooterr_corr_err_reporting_en;
wire              w_cfg_aer_rooterr_non_fatal_err_reporting_en;
wire              w_cfg_aer_rooterr_fatal_err_reporting_en;
wire              w_cfg_aer_rooterr_corr_err_received;
wire              w_cfg_aer_rooterr_non_fatal_err_received;
wire              w_cfg_aer_rooterr_fatal_err_received;
wire              w_cfg_msg_received_err_cor;
wire              w_cfg_msg_received_err_non_fatal;
wire              w_cfg_msg_received_err_fatal;
wire              w_cfg_msg_received_pm_as_nak;
wire              w_cfg_msg_received_pm_pme;
wire              w_cfg_msg_received_pme_to_ack;
wire              w_cfg_msg_received_assert_int_a;
wire              w_cfg_msg_received_assert_int_b;
wire              w_cfg_msg_received_assert_int_c;
wire              w_cfg_msg_received_assert_int_d;
wire              w_cfg_msg_received_deassert_int_a;
wire              w_cfg_msg_received_deassert_int_b;
wire              w_cfg_msg_received_deassert_int_c;
wire              w_cfg_msg_received_deassert_int_d;
wire              w_cfg_msg_received_setslotpowerlimit;





wire              w_cfg_err_aer_headerlog_set;
wire              w_cfg_aer_ecrc_check_en;
wire              w_cfg_aer_ecrc_gen_en;
wire  [6:0]       w_cfg_vc_tcvc_map;




//Used
wire  [1:0]       w_pl_directed_link_change;
wire  [1:0]       w_pl_directed_link_width;
wire              w_pl_directed_link_speed;
wire              w_pl_directed_link_auton;
wire              w_pl_upstream_prefer_deemph;

wire              w_pl_transmit_hot_rst;
wire              w_pl_downstream_deemph_source;


wire [127:0]      w_cfg_err_aer_headerlog;
wire   [4:0]      w_cfg_aer_interrupt_msgnum;
wire              w_cfg_err_aer_headerlog_set;
wire              w_cfg_aer_ecrc_check_en;
wire              w_cfg_aer_ecrc_gen_en;

//submodules

PCIEBus #(
//PCIEBUS_sim #(
  .PCIE_EXT_CLK                   ("FALSE"                        ) //Allow the PCIE Bus to handle pipelining internally

)sys_pcie (
//PCIEBUS_sim sys_pcie (


  // Tx
  .pci_exp_txp                    (o_pcie_tx_p                    ),
  .pci_exp_txn                    (o_pcie_tx_n                    ),

  // Rx
  .pci_exp_rxp                    (i_pcie_rx_p                    ),
  .pci_exp_rxn                    (i_pcie_rx_n                    ),

  .PIPE_PCLK_IN                   (1'b0                           ),
  .PIPE_RXUSRCLK_IN               (1'b0                           ),
  .PIPE_RXOUTCLK_IN               (1'b0                           ),
  .PIPE_DCLK_IN                   (1'b0                           ),
  .PIPE_USERCLK1_IN               (1'b0                           ),
  .PIPE_USERCLK2_IN               (1'b0                           ),
  .PIPE_OOBCLK_IN                 (1'b0                           ),
  .PIPE_MMCM_LOCK_IN              (1'b0                           ),
  .PIPE_MMCM_RST_N                (1'b1                           ),

  .PIPE_TXOUTCLK_OUT              (                               ),
  .PIPE_RXOUTCLK_OUT              (                               ),

  .PIPE_PCLK_SEL_OUT              (                               ),
  .PIPE_GEN3_OUT                  (                               ),

  // Common
  .user_clk_out                   (w_user_clk_out                 ),
  .user_reset_out                 (w_user_reset_out               ),
  .user_lnk_up                    (w_user_link_up                 ),

  // Tx
  .tx_buf_av                      (w_tx_buf_av                    ),
  .tx_err_drop                    (w_tx_err_drop                  ),
  .tx_cfg_req                     (w_tx_cfg_req                   ),
  .s_axis_tx_tready               (w_s_axis_tx_tready             ),
  .s_axis_tx_tdata                (w_s_axis_tx_tdata              ),
  .s_axis_tx_tkeep                (w_s_axis_tx_tkeep              ),
  .s_axis_tx_tuser                (w_s_axis_tx_tuser              ),
  .s_axis_tx_tlast                (w_s_axis_tx_tlast              ),
  .s_axis_tx_tvalid               (w_s_axis_tx_tvalid             ),
  .tx_cfg_gnt                     (w_tx_cfg_gnt                   ),

  // Rx
  .m_axis_rx_tdata                (w_m_axis_rx_tdata              ),
  .m_axis_rx_tkeep                (w_m_axis_rx_tkeep              ),
  .m_axis_rx_tlast                (w_m_axis_rx_tlast              ),
  .m_axis_rx_tvalid               (w_m_axis_rx_tvalid             ),
  .m_axis_rx_tready               (w_m_axis_rx_tready             ),
  .m_axis_rx_tuser                (w_m_axis_rx_tuser              ),
  .rx_np_ok                       (w_rx_np_ok                     ),
  .rx_np_req                      (w_rx_np_req                    ),

  // Flow Control
  .fc_cpld                        (w_fc_cpld                      ),
  .fc_cplh                        (w_fc_cplh                      ),
  .fc_npd                         (w_fc_npd                       ),
  .fc_nph                         (w_fc_nph                       ),
  .fc_pd                          (w_fc_pd                        ),
  .fc_ph                          (w_fc_ph                        ),
  .fc_sel                         (w_fc_sel                       ),

  .cfg_mgmt_do                    (w_cfg_mgmt_do                   ),
  .cfg_mgmt_rd_wr_done            (w_cfg_mgmt_rd_wr_done           ),

  .cfg_status                     (w_cfg_status                    ),
  .cfg_command                    (w_cfg_command                   ),
  .cfg_dstatus                    (w_cfg_dstatus                   ),
  .cfg_dcommand                   (w_cfg_dcommand                  ),
  .cfg_lstatus                    (w_cfg_lstatus                   ),
  .cfg_lcommand                   (w_cfg_lcommand                  ),
  .cfg_dcommand2                  (w_cfg_dcommand2                 ),
  .cfg_pcie_link_state            (w_cfg_pcie_link_state           ),

  .cfg_pmcsr_pme_en               (w_cfg_pmcsr_pme_en              ),
  .cfg_pmcsr_powerstate           (w_cfg_pmcsr_powerstate          ),
  .cfg_pmcsr_pme_status           (w_cfg_pmcsr_pme_status          ),
  .cfg_received_func_lvl_rst      (w_cfg_received_func_lvl_rst     ),


  .cfg_mgmt_di                    (w_cfg_mgmt_di                   ),
  .cfg_mgmt_byte_en               (w_cfg_mgmt_byte_en              ),
  .cfg_mgmt_dwaddr                (w_cfg_mgmt_dwaddr               ),
  .cfg_mgmt_wr_en                 (w_cfg_mgmt_wr_en                ),
  .cfg_mgmt_rd_en                 (w_cfg_mgmt_rd_en                ),
  .cfg_mgmt_wr_readonly           (w_cfg_mgmt_wr_readonly          ),


  .cfg_err_ecrc                   (w_cfg_err_ecrc                  ),
  .cfg_err_ur                     (w_cfg_err_ur                    ),
  .cfg_err_cpl_timeout            (w_cfg_err_cpl_timeout           ),
  .cfg_err_cpl_unexpect           (w_cfg_err_cpl_unexpect          ),
  .cfg_err_cpl_abort              (w_cfg_err_cpl_abort             ),
  .cfg_err_posted                 (w_cfg_err_posted                ),
  .cfg_err_cor                    (w_cfg_err_cor                   ),
  .cfg_err_atomic_egress_blocked  (w_cfg_err_atomic_egress_blocked ),
  .cfg_err_internal_cor           (w_cfg_err_internal_cor          ),
  .cfg_err_malformed              (w_cfg_err_malformed             ),
  .cfg_err_mc_blocked             (w_cfg_err_mc_blocked            ),
  .cfg_err_poisoned               (w_cfg_err_poisoned              ),
  .cfg_err_norecovery             (w_cfg_err_norecovery            ),
  .cfg_err_tlp_cpl_header         (w_cfg_err_tlp_cpl_header        ),
  .cfg_err_cpl_rdy                (w_cfg_err_cpl_rdy               ),
  .cfg_err_locked                 (w_cfg_err_locked                ),
  .cfg_err_acs                    (w_cfg_err_acs                   ),
  .cfg_err_internal_uncor         (w_cfg_err_internal_uncor        ),

  .cfg_trn_pending                (w_cfg_trn_pending               ),
  .cfg_pm_halt_aspm_l0s           (w_cfg_pm_halt_aspm_l0s          ),
  .cfg_pm_halt_aspm_l1            (w_cfg_pm_halt_aspm_l1           ),
  .cfg_pm_force_state_en          (w_cfg_pm_force_state_en         ),
  .cfg_pm_force_state             (w_cfg_pm_force_state            ),

  .cfg_dsn                        (w_cfg_dsn                       ),

  .cfg_interrupt                  (w_cfg_interrupt                 ),
  .cfg_interrupt_rdy              (w_cfg_interrupt_rdy             ),
  .cfg_interrupt_assert           (w_cfg_interrupt_assert          ),
  .cfg_interrupt_di               (w_cfg_interrupt_di              ),
  .cfg_interrupt_do               (w_cfg_interrupt_do              ),
  .cfg_interrupt_mmenable         (w_cfg_interrupt_mmenable        ),
  .cfg_interrupt_msienable        (w_cfg_interrupt_msienable       ),
  .cfg_interrupt_msixenable       (w_cfg_interrupt_msixenable      ),
  .cfg_interrupt_msixfm           (w_cfg_interrupt_msixfm          ),
  .cfg_interrupt_stat             (w_cfg_interrupt_stat            ),
  .cfg_pciecap_interrupt_msgnum   (w_cfg_pciecap_interrupt_msgnum  ),


  .cfg_to_turnoff                 (w_cfg_to_turnoff                ),
  .cfg_turnoff_ok                 (w_cfg_turnoff_ok                ),
  .cfg_bus_number                 (w_cfg_bus_number                ),
  .cfg_device_number              (w_cfg_device_number             ),
  .cfg_function_number            (w_cfg_function_number           ),
  .cfg_pm_wake                    (w_cfg_pm_wake                   ),

  .cfg_pm_send_pme_to             (w_cfg_pm_send_pme_to            ),
  .cfg_ds_bus_number              (w_cfg_ds_bus_number             ),
  .cfg_ds_device_number           (w_cfg_ds_device_number          ),
  .cfg_ds_function_number         (w_cfg_ds_function_number        ),

  .cfg_mgmt_wr_rw1c_as_rw         (w_cfg_mgmt_wr_rw1c_as_rw        ),
  .cfg_msg_received               (w_cfg_msg_received              ),
  .cfg_msg_data                   (w_cfg_msg_data                  ),

  .pl_directed_link_change        (w_pl_directed_link_change        ),
  .pl_directed_link_width         (w_pl_directed_link_width         ),
  .pl_directed_link_speed         (w_pl_directed_link_speed         ),
  .pl_directed_link_auton         (w_pl_directed_link_auton         ),
  .pl_upstream_prefer_deemph      (w_pl_upstream_prefer_deemph      ),

  .pl_sel_lnk_rate                (w_pl_sel_lnk_rate                ),
  .pl_sel_lnk_width               (w_pl_sel_lnk_width               ),
  .pl_ltssm_state                 (w_pl_ltssm_state                 ),
  .pl_lane_reversal_mode          (w_pl_lane_reversal_mode          ),

  .pl_phy_lnk_up                  (w_pl_phy_lnk_up                  ),
  .pl_tx_pm_state                 (w_pl_tx_pm_state                 ),
  .pl_rx_pm_state                 (w_pl_rx_pm_state                 ),

  .pl_link_upcfg_cap              (w_pl_link_upcfg_cap              ),
  .pl_link_gen2_cap               (w_pl_link_gen2_cap               ),
  .pl_link_partner_gen2_supported (w_pl_link_partner_gen2_supported ),
  .pl_initial_link_width          (w_pl_initial_link_width          ),
  .pl_directed_change_done        (w_pl_directed_change_done        ),
  .pl_received_hot_rst            (w_pl_received_hot_rst            ),
  .pl_transmit_hot_rst            (w_pl_transmit_hot_rst            ),
  .pl_downstream_deemph_source    (w_pl_downstream_deemph_source    ),

  .cfg_err_aer_headerlog          (w_cfg_err_aer_headerlog          ),
  .cfg_aer_interrupt_msgnum       (w_cfg_aer_interrupt_msgnum       ),
  .cfg_err_aer_headerlog_set      (w_cfg_err_aer_headerlog_set      ),
  .cfg_aer_ecrc_check_en          (w_cfg_aer_ecrc_check_en          ),
  .cfg_aer_ecrc_gen_en            (w_cfg_aer_ecrc_gen_en            ),
  .cfg_vc_tcvc_map                (w_cfg_vc_tcvc_map                ),

  .cfg_bridge_serr_en                         (w_cfg_bridge_serr_en                         ),
  .cfg_slot_control_electromech_il_ctl_pulse  (w_cfg_slot_control_electromech_il_ctl_pulse  ),
  .cfg_root_control_syserr_corr_err_en        (w_cfg_root_control_syserr_corr_err_en        ),
  .cfg_root_control_syserr_non_fatal_err_en   (w_cfg_root_control_syserr_non_fatal_err_en   ),
  .cfg_root_control_syserr_fatal_err_en       (w_cfg_root_control_syserr_fatal_err_en       ),
  .cfg_root_control_pme_int_en                (w_cfg_root_control_pme_int_en                ),
  .cfg_aer_rooterr_corr_err_reporting_en      (w_cfg_aer_rooterr_corr_err_reporting_en      ),
  .cfg_aer_rooterr_non_fatal_err_reporting_en (w_cfg_aer_rooterr_non_fatal_err_reporting_en ),
  .cfg_aer_rooterr_fatal_err_reporting_en     (w_cfg_aer_rooterr_fatal_err_reporting_en     ),
  .cfg_aer_rooterr_corr_err_received          (w_cfg_aer_rooterr_corr_err_received          ),
  .cfg_aer_rooterr_non_fatal_err_received     (w_cfg_aer_rooterr_non_fatal_err_received     ),
  .cfg_aer_rooterr_fatal_err_received         (w_cfg_aer_rooterr_fatal_err_received         ),

  .cfg_msg_received_err_cor                   (w_cfg_msg_received_err_cor                   ),
  .cfg_msg_received_err_non_fatal             (w_cfg_msg_received_err_non_fatal             ),
  .cfg_msg_received_err_fatal                 (w_cfg_msg_received_err_fatal                 ),
  .cfg_msg_received_pm_as_nak                 (w_cfg_msg_received_pm_as_nak                 ),
  .cfg_msg_received_pm_pme                    (w_cfg_msg_received_pm_pme                    ),
  .cfg_msg_received_pme_to_ack                (w_cfg_msg_received_pme_to_ack                ),
  .cfg_msg_received_assert_int_a              (w_cfg_msg_received_assert_int_a              ),
  .cfg_msg_received_assert_int_b              (w_cfg_msg_received_assert_int_b              ),
  .cfg_msg_received_assert_int_c              (w_cfg_msg_received_assert_int_c              ),
  .cfg_msg_received_assert_int_d              (w_cfg_msg_received_assert_int_d              ),
  .cfg_msg_received_deassert_int_a            (w_cfg_msg_received_deassert_int_a            ),
  .cfg_msg_received_deassert_int_b            (w_cfg_msg_received_deassert_int_b            ),
  .cfg_msg_received_deassert_int_c            (w_cfg_msg_received_deassert_int_c            ),
  .cfg_msg_received_deassert_int_d            (w_cfg_msg_received_deassert_int_d            ),
  .cfg_msg_received_setslotpowerlimit         (w_cfg_msg_received_setslotpowerlimit         ),

  .sys_clk                        (w_sys_clk                        ),
  .sys_rst_n                      (i_pcie_reset_n                   )

);

ibufds pcie_clk_buf (
  .I                      (i_pcie_clk_p   ),
  .IB                     (i_pcie_clk_n   ),
  .O                      (w_sys_clk      ),
);


//asynchronous logic

assign cfg_dsn                          = SERIAL_NUMBER;

assign o_pcie_wake_n                    = 1'b1;
assign w_pl_transmit_hot_rst            = 1'b0;
assign w_pl_downstream_deemph_source    = 1'b0;


assign w_pl_directed_link_change        = 2'b00;
assign w_pl_directed_link_width         = 2'b00;
assign w_pl_directed_link_speed         = 1'b0;
assign w_pl_directed_link_auton         = 1'b0;
assign w_pl_upstream_prefer_deemph      = 1'b0;
assign w_tx_cfg_gnt                     = 1'b1;
assign w_rx_np_ok                       = 1'b1;


//Select between 64 or 128bit RCB boundary
assign  w_rcb_128B_sel                  = w_cfg_lcommand[3];



assign w_cfg_err_ecrc                   = 1'b0;
assign w_cfg_err_ur                     = 1'b0;
assign w_cfg_err_cpl_timeout            = 1'b0;
assign w_cfg_err_cpl_unexpect           = 1'b0;
assign w_cfg_err_cpl_abort              = 1'b0;
assign w_cfg_err_posted                 = 1'b0;
assign w_cfg_err_cor                    = 1'b0;
assign w_cfg_err_atomic_egress_blocked  = 1'b0;
assign w_cfg_err_internal_cor           = 1'b0;
assign w_cfg_err_malformed              = 1'b0;
assign w_cfg_err_mc_blocked             = 1'b0;
assign w_cfg_err_poisoned               = 1'b0;
assign w_cfg_err_norecovery             = 1'b0;
assign w_cfg_err_locked                 = 1'b0;
assign w_cfg_err_acs                    = 1'b0;
assign w_cfg_err_internal_uncor         = 1'b0;
assign w_cfg_err_tlp_cpl_header         = 48'h0;
//assign w_cfg_err_cpl_rdy                = 0;

assign w_cfg_trn_pending                = 1'b0;
//synchronous logic
assign w_cfg_pm_halt_aspm_l0s           = 1'b0;
assign w_cfg_pm_halt_aspm_l1            = 1'b0;
assign w_cfg_pm_force_state_en          = 1'b0;
assign w_cfg_pm_force_state             = 1'b0;


assign  w_cfg_interrupt_stat            = 1'b0; //XXX: ???
assign  w_cfg_interrupt_assert          = 1'b0; //XXX: ???
assign  w_cfg_pciecap_interrupt_msgnum  = 5'h0; //XXX: ???


assign  w_cfg_turnoff_ok                = 1'b0;
assign  w_cfg_pm_wake                   = 1'b0;

//Map these to PCIE Control
//wire              w_cfg_interrupt;
//wire              w_cfg_interrupt_rdy;
//wire  [7:0]       w_cfg_bus_number;
//wire  [4:0]       w_cfg_device_number;
//wire  [2:0]       w_cfg_function_number;


assign  w_cfg_interrupt_di              = w_interrupt_msi_value;

assign  w_cfg_pm_send_pme_to            = 1'b0;
assign  w_cfg_ds_bus_number             = 8'h0;
assign  w_cfg_ds_device_number          = 5'h0;
assign  w_cfg_ds_function_number        = 3'b000;


assign  w_cfg_mgmt_wr_rw1c_as_rw        = 1'b0;
assign  w_cfg_msg_received              = 1'b0;
assign  w_cfg_msg_data                  = 16'h0;
assign  w_cfg_err_aer_headerlog         = 128'h0;
assign  w_cfg_aer_interrupt_msgnum      = 5'h0;

//XXX Temporary
assign  w_s_axis_tx_tdata               = 64'h0;
assign  w_s_axis_tx_tkeep               = 8'h0;
assign  w_s_axis_tx_tuser               = 4'h0;
assign  w_s_axis_tx_tlast               = 1'b0;
assign  w_s_axis_tx_tvalid              = 1'b0;
                                        
assign  w_m_axis_rx_tready              = 1'b0;

endmodule
