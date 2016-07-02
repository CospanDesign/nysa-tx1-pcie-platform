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

`define STS_BIT_LINKUP      0
`define STS_BIT_USR_RST     1
`define STS_BIT_PCIE_RST_N  2
`define STS_BIT_PHY_RDY_N   3
`define STS_PLL_LOCKED      4
`define STS_CLK_IN_STOPPED  5


module wb_tx1_pcie (
  input               clk,
  input               rst,

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


  // Tx
  output      [3:0]   o_pcie_exp_tx_p,
  output      [3:0]   o_pcie_exp_tx_n,

  // Rx
  input       [3:0]   i_pcie_exp_rx_p,
  input       [3:0]   i_pcie_exp_rx_n,

  input               i_pcie_clk_p,
  input               i_pcie_clk_n,

  //PCIE Control
  input               i_pcie_reset_n,
  output              o_pcie_wake_n,
  output              o_lax_clk,
  output      [31:0]  o_debug,
  output              o_pcie_clkreq,


  //This interrupt can be controlled from this module or a submodule
  output  reg         o_wbs_int
);

//Local Parameters
localparam     CONTROL             = 32'h00000000;
localparam     STATUS              = 32'h00000001;
localparam     CONFIG_COMMAND      = 32'h00000002;
localparam     CONFIG_STATUS       = 32'h00000003;
localparam     CONFIG_DCOMMAND     = 32'h00000004;
localparam     CONFIG_DCOMMAND2    = 32'h00000005;
localparam     CONFIG_DSTATUS      = 32'h00000006;
localparam     CONFIG_LCOMMAND     = 32'h00000007;
localparam     CONFIG_LSTATUS      = 32'h00000008;
localparam     CONFIG_LINK_STATE   = 32'h00000009;
localparam     RX_ELEC_IDLE        = 32'h0000000A;
localparam     LTSSM_STATE         = 32'h0000000B;
localparam     GTX_PLL_LOCK        = 32'h0000000C;
localparam     TX_DIFF_CTR         = 32'h0000000D;

//Local Registers/Wires

wire  w_user_link_up;
wire  w_user_reset_out;
wire  w_phy_rdy_n;


wire        [15:0]      w_cfg_status;
wire        [15:0]      w_cfg_command;
wire        [15:0]      w_cfg_dstatus;
wire        [15:0]      w_cfg_dcommand;
wire        [15:0]      w_cfg_lstatus;
wire        [15:0]      w_cfg_lcommand;
wire        [15:0]      w_cfg_dcommand2;
wire        [2:0]       w_cfg_pcie_link_state;
wire        [7:0]       w_pcie_rx_elec_idle;
wire        [5:0]       w_pl_ltssm_state;

wire        [3:0]       w_plllkdet;
wire                    w_clock_locked;
wire                    o_clk_in_stopped;

wire        [2:0]       pipe_rx0_status_gt;
wire                    pipe_rx0_phy_status_gt;
reg         [3:0]       r_tx_diff_ctr;


wire                    w_pl_sel_lnk_rate;
wire        [1:0]       w_pl_sel_lnk_width;
wire        [2:0]       w_pl_initial_link_width;

wire        [15:0]      w_rx_data;
wire        [1:0]       w_rx_data_k;

wire        [1:0]       w_rx_byte_is_comma;
wire                    w_rx_byte_is_aligned;



wire                    w_lax_clk;



//Submodules
tx1_pcie_adapter pcie_adapter (
  .clk                      (clk                   ),
  .rst                      (rst                   ),

  .o_user_link_up           (w_user_link_up        ),
  .o_user_reset_out         (w_user_reset_out      ),
  .o_phy_rdy_n              (w_phy_rdy_n           ),
  .o_pcie_rx_elec_idle      (w_pcie_rx_elec_idle   ),
  .o_pl_ltssm_state         (w_pl_ltssm_state      ),
  .pipe_rx0_status_gt       (pipe_rx0_status_gt    ),
  .pipe_rx0_phy_status_gt   (pipe_rx0_phy_status_gt  ),

  .o_clock_locked           (w_clock_locked         ),
  .o_plllkdet               (w_plllkdet             ),
  .o_clk_in_stopped         (o_clk_in_stopped       ),

  .i_tx_diff_ctr            (r_tx_diff_ctr          ),

  .o_pl_sel_lnk_rate        (w_pl_sel_lnk_rate      ),
  .o_pl_sel_lnk_width       (w_pl_sel_lnk_width     ),
  .o_pl_initial_link_width  (w_pl_initial_link_width),

  .o_cfg_status             (w_cfg_status           ),
  .o_cfg_command            (w_cfg_command          ),
  .o_cfg_dstatus            (w_cfg_dstatus          ),
  .o_cfg_dcommand           (w_cfg_dcommand         ),
  .o_cfg_lstatus            (w_cfg_lstatus          ),
  .o_cfg_lcommand           (w_cfg_lcommand         ),
  .o_cfg_dcommand2          (w_cfg_dcommand2        ),
  .o_cfg_pcie_link_state    (w_cfg_pcie_link_state  ),

  // Tx
  .o_pcie_exp_tx_p          (o_pcie_exp_tx_p        ),
  .o_pcie_exp_tx_n          (o_pcie_exp_tx_n        ),

  // Rx
  .i_pcie_exp_rx_p          (i_pcie_exp_rx_p        ),
  .i_pcie_exp_rx_n          (i_pcie_exp_rx_n        ),

  .i_pcie_clk_p             (i_pcie_clk_p           ),
  .i_pcie_clk_n             (i_pcie_clk_n           ),

  .o_rx_data                (w_rx_data              ),
  .o_rx_data_k              (w_rx_data_k            ),

  .o_rx_byte_is_comma       (w_rx_byte_is_comma     ),
  .o_rx_byte_is_aligned     (w_rx_byte_is_aligned   ),

  .o_lax_clk                (w_lax_clk              ),

  //PCIE Control control
  .i_pcie_reset_n           (i_pcie_reset_n         ),
  .o_pcie_wake_n            (o_pcie_wake_n          ),
  .o_pcie_clkreq            (o_pcie_clkreq          )

);


assign  o_lax_clk   = w_lax_clk;

/*
BUFGMUX_CTRL clk_mux (
.O          (o_lax_clk    ), // 1-bit output: Clock output
.I0         (clk          ),  // 1-bit input: Clock input (S=0)
.I1         (w_lax_clk    ),  // 1-bit input: Clock input (S=1)
.S          (w_clk_locked )   // 1-bit input: Clock select
);
*/
/*
BUFGCTRL lax_clk_sel (
  .O                        (o_lax_clk            ),
  .CE0                      (1'b1                 ),
  .CE1                      (1'b1                 ),
  .I0                       (w_lax_clk            ),
  .I1                       (clk                  ),
  .IGNORE0                  (1'b0                 ),
  .IGNORE1                  (1'b0                 ),
  .S0                       (w_clk_locked         ),
  .S1                       (!w_clk_locked        )
);
*/

/*
clk_wiz_v3_6_0 clk_gen (
  .CLK_IN1              (clk                    ),
  .CLK_OUT1             (o_lax_clk              ),
  .RESET                (rst                    )
  //.LOCKED               (lax_clk_locked         )
);
*/
//assign o_lax_clk       = clk;

//Asynchronous Logic
//Synchronous Logic
assign  o_debug[15:0]   = w_rx_data;
assign  o_debug[17:16]  = w_rx_data_k;
assign  o_debug[20:18]  = pipe_rx0_status_gt;
assign  o_debug[21]     = pipe_rx0_phy_status_gt;
assign  o_debug[23:22]  = w_rx_byte_is_comma;
assign  o_debug[29:24]  = w_pl_ltssm_state;
//assign  o_debug[31:30]  = w_rx_byte_is_aligned;
assign  o_debug[30]  = w_rx_byte_is_aligned;
assign  o_debug[31]  = w_clock_locked;
/*
assign  o_debug[0]     = i_pcie_reset_n;
assign  o_debug[1]     = w_clock_locked;
assign  o_debug[3:2]   = w_cfg_pcie_link_state;
assign  o_debug[9:4]   = w_pl_ltssm_state;
assign  o_debug[11:10] = w_pl_sel_lnk_width;
assign  o_debug[14:12] = pipe_rx0_status_gt;
assign  o_debug[15]    = w_pl_sel_lnk_rate;
assign  o_debug[19:16] = r_tx_diff_ctr;
assign  o_debug[23:20] = w_pl_initial_link_width;
assign  o_debug[23:20] = w_pl_initial_link_width;
assign  o_debug[24]    = pipe_rx0_phy_status_gt;
assign  o_debug[31:25] = 0;
*/


always @ (posedge clk) begin
  if (rst) begin
    o_wbs_dat     <= 32'h0;
    o_wbs_ack     <= 0;
    o_wbs_int     <= 0;
    r_tx_diff_ctr <=  4'hC;
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
            TX_DIFF_CTR: begin
              r_tx_diff_ctr   <=  i_wbs_dat[3:0];
            end
            //add as many ADDR_X you need here
            default: begin
            end
          endcase
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              $display("user read %h", CONTROL);
              o_wbs_dat <= CONTROL;
            end
            STATUS: begin
              o_wbs_dat <=  0;
              o_wbs_dat[`STS_BIT_LINKUP]        <=  w_user_link_up;
              o_wbs_dat[`STS_BIT_USR_RST]       <=  w_user_reset_out;
              o_wbs_dat[`STS_BIT_PCIE_RST_N]    <=  i_pcie_reset_n;
              o_wbs_dat[`STS_BIT_PHY_RDY_N]     <=  w_phy_rdy_n;
              o_wbs_dat[`STS_PLL_LOCKED]        <=  w_clock_locked;
              o_wbs_dat[`STS_CLK_IN_STOPPED]    <=  o_clk_in_stopped;
            end
            CONFIG_COMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_command};
            end
            CONFIG_STATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_status};
            end
            CONFIG_DSTATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_dstatus};
            end
            CONFIG_DCOMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_dcommand};
            end
            CONFIG_DCOMMAND2: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_dcommand2};
            end
            CONFIG_LSTATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_lstatus};
            end
            CONFIG_LCOMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {16'h0000, w_cfg_lcommand};
            end
            CONFIG_LINK_STATE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {30'h0000, w_cfg_pcie_link_state};
            end
            RX_ELEC_IDLE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {24'h000000, w_pcie_rx_elec_idle};
            end
            LTSSM_STATE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {26'h0, w_pl_ltssm_state};
            end
            GTX_PLL_LOCK: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=                  {28'h0, w_plllkdet};
            end
            TX_DIFF_CTR: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[3:0]  <=                  r_tx_diff_ctr;
            end

            //add as many ADDR_X you need here
            default: begin
            end
          endcase
        end
      o_wbs_ack <= 1;
    end
    end
  end
end

endmodule
