//wb_tx1_ddr3.v
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
  SDB_NAME:wb_tx1_ddr3

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x06

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0x03

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
  SDB_SIZE:0x8000000
*/


module wb_tx1_ddr3 #(
  parameter          BUF_DEPTH       = 10,
  parameter          MEM_ADDR_DEPTH  = 28
)(
  input               clk,
  input               rst,

  // Inouts
  inout    [7:0]      ddr3_dq,
  inout               ddr3_dqs_n,
  inout               ddr3_dqs_p,

  // Outputs
  output    [13:0]    ddr3_addr,
  output    [2:0]     ddr3_ba,
  output              ddr3_ras_n,
  output              ddr3_cas_n,
  output              ddr3_we_n,
  output              ddr3_reset_n,
  output              ddr3_ck_p,
  output              ddr3_ck_n,
  output              ddr3_cke,
  output              ddr3_cs_n,
  output              ddr3_dm,
  output              ddr3_odt,

//  output              ref_clk_out,
//  input               ref_clk_in,

  //Wishbone Bus Signals
  input               i_wbs_we,
  input               i_wbs_cyc,
  input       [3:0]   i_wbs_sel,
  input       [31:0]  i_wbs_dat,
  input               i_wbs_stb,
  output  reg         o_wbs_ack,
  output  reg [31:0]  o_wbs_dat,
  input       [31:0]  i_wbs_adr,

  //DMA In Interface
  input               i_idma0_enable,
  output              o_idma0_finished,
  input       [31:0]  i_idma0_addr,
  input               i_idma0_busy,
  input       [23:0]  i_idma0_count,
  input               i_idma0_flush,

  input               i_idma0_strobe,
  output      [1:0]   o_idma0_ready,
  input       [1:0]   i_idma0_activate,
  output      [23:0]  o_idma0_size,
  input       [31:0]  i_idma0_data,

  //DMA Out Interface
  input               i_odma0_enable,
  input      [31:0]   i_odma0_address,
  input      [23:0]   i_odma0_count,
  input               i_odma0_flush,

  input               i_odma0_strobe,
  output      [31:0]  o_odma0_data,
  output              o_odma0_ready,
  input               i_odma0_activate,
  output      [23:0]  o_odma0_size,


  output      [31:0]  o_debug,
  //This interrupt can be controlled from this module or a submodule
  output  reg         o_wbs_int
  //output              o_wbs_int
);

//Local Registers/Wires


reg     [31:0]              r_address;
(* keep = "true" *) wire    sys_clk_i;
//wire                        clk_ref_i;

wire                        app_zq_req;  //Set to 0
wire                        app_zq_ack;

wire    [27:0]              app_addr;
wire    [2:0]               app_cmd;
wire                        app_en;
wire                        app_rdy;

wire    [31:0]              app_wdf_data;
wire                        app_wdf_end;
wire    [3:0]               app_wdf_mask;
wire                        app_wdf_wren;
wire                        app_wdf_rdy;

wire    [31:0]              app_rd_data;
wire                        app_rd_data_end;
wire                        app_rd_data_valid;

wire                        app_sr_req;
wire                        app_sr_active;
wire                        app_ref_req;
wire                        app_ref_ack;

wire                        ui_clk_sync_rst;

wire                        init_calib_complete;


//Memory Controller Interface
reg                         write_en; //set high to initiate a write transaction

reg     [23:0]              write_count;
reg     [23:0]              read_count;

//Local Registers/Wires
//Submodules
//wire                        clk_locked;

//PPFIFO Interface
reg                         if_write_strobe;
wire    [1:0]               if_write_ready;
reg     [1:0]               if_write_activate;
wire    [23:0]              if_write_size;
wire                        if_starved;

reg                         of_read_strobe;
wire                        of_read_ready;
reg                         of_read_activate;
wire    [23:0]              of_read_size;
wire    [31:0]              of_read_data;

wire                            w_ibuf_go;
wire                            w_ibuf_bsy;
wire                            w_ibuf_ddr3_fault;
wire    [BUF_DEPTH - 1:0]       w_ibuf_count;
wire    [BUF_DEPTH - 1:0]       w_ibuf_start_addrb;
wire    [BUF_DEPTH - 1:0]       w_ibuf_addrb;
wire    [31:0]                  w_ibuf_doutb;
wire    [MEM_ADDR_DEPTH - 1:0]  w_ibuf_ddr3_addrb;

wire                            w_obuf_go;
wire                            w_obuf_bsy;
wire                            w_obuf_ddr3_fault;
wire    [BUF_DEPTH - 1:0]       w_obuf_count;
wire    [BUF_DEPTH - 1:0]       w_obuf_start_addra;
wire    [BUF_DEPTH - 1:0]       w_obuf_addra;
reg     [31:0]                  r_buf_count;
wire    [31:0]                  w_obuf_dina;
wire                            w_obuf_wea;
wire    [MEM_ADDR_DEPTH - 1:0]  w_obuf_ddr3_addra;

wire                            w_ingress_en;
wire                            w_egress_en;

reg                             r_prev_cyc;
wire                            w_read_address_en;
wire                            pll_locked;

wire      [1:0]                 w_ing_enable;
wire      [1:0]                 w_egr_enable;
wire      [1:0]                 w_inout_enable;
wire      [3:0]                 w_dac_state;

//Comment for normal operation, uncomment for simulation
//`define SIM

/*
`ifdef SIM
reg                         ui_clk;
always @ (*)  ui_clk = clk;
assign      ui_clk_sync_rst = rst;
ddr3_ui_sim sim (
  .ui_clk              (ui_clk                ),
  .rst                 (rst                   ),

  .o_app_phy_init_done (init_calib_complete   ),

  .i_app_en            (app_en                ),
  .i_app_cmd           (app_cmd               ),
  .i_app_addr          (app_addr              ),
  .o_app_rdy           (app_rdy               ),

  .i_app_wdf_data      (app_wdf_data          ),
  .i_app_wdf_end       (app_wdf_end           ),
  .o_app_wdf_rdy       (app_wdf_rdy           ),
  .i_app_wdf_wren      (app_wdf_wren          ),

  .o_app_rd_data       (app_rd_data           ),
  .o_app_rd_data_end   (app_rd_data_end       ),
  .o_app_rd_data_valid (app_rd_data_valid     )
);

`else
*/
wire                        ui_clk;
wire                        ref_clk_in;
ddr3_pll pll(
  .CLK_IN1             (clk                  ),
  .CLK_OUT1            (ref_clk_in           ),

//  .RESET               (rst                  ),
  .LOCKED              (clk_locked           )
);

tx1_ddr3 ddr3_if(
  .ddr3_dq             (ddr3_dq              ),
  .ddr3_dqs_n          (ddr3_dqs_n           ),
  .ddr3_dqs_p          (ddr3_dqs_p           ),


  .ddr3_addr           (ddr3_addr            ),
  .ddr3_ba             (ddr3_ba              ),
  .ddr3_ras_n          (ddr3_ras_n           ),
  .ddr3_cas_n          (ddr3_cas_n           ),
  .ddr3_we_n           (ddr3_we_n            ),
  .ddr3_reset_n        (ddr3_reset_n         ),
  .ddr3_ck_p           (ddr3_ck_p            ),
  .ddr3_ck_n           (ddr3_ck_n            ),
  .ddr3_cke            (ddr3_cke             ),
  .ddr3_cs_n           (ddr3_cs_n            ),
  .ddr3_dm             (ddr3_dm              ),
  .ddr3_odt            (ddr3_odt             ),

//  .sys_clk_i           (sys_clk_i            ),
  .sys_clk_i           (ref_clk_in           ),
//  .clk_ref_i           (ref_clk_in           ),

  .app_zq_req          (app_zq_req           ),
  .app_zq_ack          (app_zq_ack           ),


  .app_addr            (app_addr             ),
  .app_cmd             (app_cmd              ),
  .app_en              (app_en               ),
  .app_rdy             (app_rdy              ),

  .app_wdf_data        (app_wdf_data         ),
  .app_wdf_end         (app_wdf_end          ),
  .app_wdf_mask        (app_wdf_mask         ),
  .app_wdf_wren        (app_wdf_wren         ),
  .app_wdf_rdy         (app_wdf_rdy          ),

  .app_rd_data         (app_rd_data          ),
  .app_rd_data_end     (app_rd_data_end      ),
  .app_rd_data_valid   (app_rd_data_valid    ),

  .app_sr_req          (app_sr_req           ),
  .app_sr_active       (app_sr_active        ),
  .app_ref_req         (app_ref_req          ),
  .app_ref_ack         (app_ref_ack          ),

  .ui_clk              (ui_clk               ),
  .ui_clk_sync_rst     (ui_clk_sync_rst      ),

  .pll_locked          (pll_locked           ),
  .init_calib_complete (init_calib_complete  ),
  .sys_rst             (!clk_locked          )
  //.sys_rst             (rst                  )
);

//`endif

ddr3_ui #(
  .BUF_DEPTH          (BUF_DEPTH              ),
  .MEM_ADDR_DEPTH     (MEM_ADDR_DEPTH         )
)ui(
  .ui_clk              (ui_clk                ),
  .rst                 (rst || ui_clk_sync_rst),

  .i_app_phy_init_done (init_calib_complete   ),

  .o_app_en            (app_en                ),
  .o_app_cmd           (app_cmd               ),
  .o_app_addr          (app_addr              ),
  .i_app_rdy           (app_rdy               ),

  .o_app_wdf_data      (app_wdf_data          ),
  .o_app_wdf_end       (app_wdf_end           ),
  .i_app_wdf_rdy       (app_wdf_rdy           ),
  .o_app_wdf_wren      (app_wdf_wren          ),

  .i_app_rd_data       (app_rd_data           ),
  .i_app_rd_data_end   (app_rd_data_end       ),
  .i_app_rd_data_valid (app_rd_data_valid     ),

  .i_ibuf_go           (w_ibuf_go             ),
  .o_ibuf_bsy          (w_ibuf_bsy            ),
  .o_ibuf_ddr3_fault   (w_ibuf_ddr3_fault     ),
  .i_ibuf_count        (w_ibuf_count          ),
  .i_ibuf_start_addrb  (w_ibuf_start_addrb    ),
  .o_ibuf_addrb        (w_ibuf_addrb          ),
  .i_ibuf_doutb        (w_ibuf_doutb          ),
  .i_ibuf_ddr3_addrb   (w_ibuf_ddr3_addrb     ),

  .i_obuf_go           (w_obuf_go             ),
  .o_obuf_bsy          (w_obuf_bsy            ),
  .o_obuf_ddr3_fault   (w_obuf_ddr3_fault     ),
  .i_obuf_count        (w_obuf_count          ),
  .i_obuf_start_addra  (w_obuf_start_addra    ),
  .o_obuf_addra        (w_obuf_addra          ),
  .o_obuf_dina         (w_obuf_dina           ),
  .o_obuf_wea          (w_obuf_wea            ),
  .i_obuf_ddr3_addra   (w_obuf_ddr3_addra     )
);


ddr3_arbiter_controller #(
  .BUF_DEPTH          (BUF_DEPTH          ),
  .MEM_ADDR_DEPTH     (MEM_ADDR_DEPTH     )
)controller(
  .clk                (clk                 ),
  .rst                (rst                 ),

  .ui_clk             (ui_clk              ),
  .ui_rst             (ui_clk_sync_rst     ),

  //DMA In Interface 0 (DMA Ingress)
  .i_idma0_enable     (i_idma0_enable      ),
  .o_idma0_finished   (o_idma0_finished    ),
  .i_idma0_addr       (i_idma0_addr        ),
  .i_idma0_busy       (i_idma0_busy        ),
  .i_idma0_count      (i_idma0_count       ),
  .i_idma0_flush      (i_idma0_flush       ),

  .i_idma0_strobe     (i_idma0_strobe      ),
  .o_idma0_ready      (o_idma0_ready       ),
  .i_idma0_activate   (i_idma0_activate    ),
  .o_idma0_size       (o_idma0_size        ),
  .i_idma0_data       (i_idma0_data        ),

  //DMA In Interface 1 (Wishbone Ingress)
  .i_idma1_enable     (w_ingress_en        ),
  .o_idma1_finished   (                    ),
  .i_idma1_addr       (r_address           ),
  .i_idma1_busy       (1'b0                ), //Doesn't matter
  .i_idma1_count      (24'b0               ), //Count doesn't matter, wait for the enable to go low to figure out when done
  .i_idma1_flush      (1'b0                ),

  .i_idma1_strobe     (if_write_strobe     ),
  .o_idma1_ready      (if_write_ready      ),
  .i_idma1_activate   (if_write_activate   ),
  .o_idma1_size       (if_write_size       ),
  .i_idma1_data       (i_wbs_dat           ),

  //DMA Out Interface 0 (DMA Egress)
  .i_odma0_enable     (i_odma0_enable      ),
  .i_odma0_address    (i_odma0_address     ),
  .i_odma0_count      (i_odma0_count       ),
  .i_odma0_flush      (i_odma0_flush       ),

  .i_odma0_strobe     (i_odma0_strobe      ),
  .o_odma0_data       (o_odma0_data        ),
  .o_odma0_ready      (o_odma0_ready       ),
  .i_odma0_activate   (i_odma0_activate    ),
  .o_odma0_size       (o_odma0_size        ),

  //DMA Out Interface 1 (Wishbone Egress)
  .i_odma1_enable     (w_egress_en         ),
  .i_odma1_address    (r_address           ),
  .i_odma1_count      (24'h400             ),
  .i_odma1_flush      (1'b0                ), //Not used

  .i_odma1_strobe     (of_read_strobe      ),
  .o_odma1_data       (of_read_data        ),
  .o_odma1_ready      (of_read_ready       ),
  .i_odma1_activate   (of_read_activate    ),
  .o_odma1_size       (of_read_size        ),

  //BRAM Interface
  .o_ibuf_go          (w_ibuf_go           ),
  .i_ibuf_bsy         (w_ibuf_bsy          ),
  .i_ibuf_ddr3_fault  (w_ibuf_ddr3_fault   ),
  .o_ibuf_count       (w_ibuf_count        ),
  .o_ibuf_start_addrb (w_ibuf_start_addrb  ),
  .i_ibuf_addrb       (w_ibuf_addrb        ),
  .o_ibuf_doutb       (w_ibuf_doutb        ),
  .o_ibuf_ddr3_addrb  (w_ibuf_ddr3_addrb   ),

  .o_obuf_go          (w_obuf_go           ),
  .i_obuf_bsy         (w_obuf_bsy          ),
  .i_obuf_ddr3_fault  (w_obuf_ddr3_fault   ),
  .o_obuf_count       (w_obuf_count        ),
  .o_obuf_start_addra (w_obuf_start_addra  ),
  .i_obuf_addra       (w_obuf_addra        ),
  .i_obuf_dina        (w_obuf_dina         ),
  .i_obuf_wea         (w_obuf_wea          ),
  .o_obuf_ddr3_addra  (w_obuf_ddr3_addra   ),


  .o_ing_enable       (w_ing_enable        ),
  .o_egr_enable       (w_egr_enable        ),
  .o_inout_enable     (w_inout_enable      ),
  .o_state            (w_dac_state         )
);


assign  w_ingress_en      = (i_wbs_cyc & i_wbs_we);
assign  w_egress_en       = (i_wbs_cyc & !i_wbs_we);

assign  w_read_address_en  = i_wbs_cyc && !r_prev_cyc; //Only read address on cycle edge

//Asynchronous Logic
assign  app_zq_req        = 0;  //Set to 0
assign  app_sr_req        = 0; //Reserved, set to zero
assign  app_ref_req       = 0; //Core Manages Refresh Requests
assign  app_wdf_mask      = 4'h0;




assign  o_debug[3:0]      = w_dac_state;

assign  o_debug[5:4]      = if_write_ready;
assign  o_debug[7:6]      = if_write_activate;
assign  o_debug[8]        = if_write_strobe;
assign  o_debug[9]        = write_en;
//assign  o_debug[10]       = clk_locked;
assign  o_debug[10]       = pll_locked;
//assign  o_debug[10]       = 1'b0;
assign  o_debug[11]       = ui_clk_sync_rst;
assign  o_debug[12]       = of_read_ready;
assign  o_debug[13]       = of_read_activate;
assign  o_debug[14]       = of_read_strobe;
assign  o_debug[15]       = init_calib_complete;
assign  o_debug[16]       = w_ingress_en;
assign  o_debug[17]       = w_egress_en;
assign  o_debug[18]       = w_ibuf_go;
assign  o_debug[19]       = w_ibuf_bsy;
assign  o_debug[20]       = w_obuf_go;
assign  o_debug[21]       = w_obuf_bsy;
assign  o_debug[22]       = app_en;

assign  o_debug[25:24]    = w_ing_enable;
assign  o_debug[27:26]    = w_egr_enable;
assign  o_debug[29:28]    = w_inout_enable;

assign  o_debug[31:30]    = app_cmd;
/*
assign  o_debug[24:23]    = app_cmd;
assign  o_debug[25]       = app_rdy;
assign  o_debug[26]       = app_wdf_wren;
assign  o_debug[27]       = app_wdf_rdy;
assign  o_debug[28]       = app_wdf_end;
assign  o_debug[29]       = app_rd_data_valid;
assign  o_debug[30]       = app_rd_data_end;
assign  o_debug[31]       = 1'b0;
*/

//Synchronous Logic
always @ (posedge clk) begin
  //Deasserts Strobes
  if_write_strobe            <= 0;
  of_read_strobe             <= 0;
  if (rst) begin
    o_wbs_dat                <= 32'h0;
    o_wbs_ack                <= 0;
    o_wbs_int                <= 0;

    write_en                 <= 0;

    if_write_strobe          <= 0;
    if_write_activate        <= 0;

    of_read_strobe           <= 0;
    of_read_activate         <= 0;

    write_count              <= 0;
    read_count               <= 0;
    r_address                <= 0;
    r_prev_cyc               <= 0;
  end
  else begin
    //Get the address when cycle goes high
    if (w_read_address_en) begin
      r_address               <=  i_wbs_adr;
    end

    //Get a Ping Pong FIFO Writer
    if ((if_write_ready > 0) && (if_write_activate == 0)) begin
      write_count             <=  0;
      if (if_write_ready[0]) begin
        if_write_activate[0]  <=  1;
      end
      else begin
        if_write_activate[1]  <=  1;
      end
    end

    //Get the Ping Pong FIFO Reader
    if (of_read_ready && !of_read_activate) begin
      read_count              <=  0;
      of_read_activate        <=  1;
    end

    //when the master acks our ack, then put our ack down
    if (o_wbs_ack && ~i_wbs_stb)begin
      o_wbs_ack <= 0;
    end


    //A transaction has starting
    if (i_wbs_cyc) begin
      if (i_wbs_we) begin
        write_en              <=  1;
      end
    end
    else begin
      write_en                <=  0;
      //A transaction has ended
      //Close any FIFO that is open
      if_write_activate       <=  0;
      of_read_activate        <=  0;
    end



/*
//XXX: Remove optimization for simultion purposes
    if ((if_write_activate > 0) && (write_count > 0)&& (if_write_ready > 0)) begin
      //Other side is idle, give it something to do
      if_write_activate       <= 0;
    end
    //Strobe
    else if (i_wbs_stb && i_wbs_cyc && !o_wbs_ack) begin
*/
    if (i_wbs_stb && i_wbs_cyc && !o_wbs_ack) begin
      //master is requesting something
      if (write_en) begin
        //write request
        if (if_write_activate > 0) begin
          if (write_count < if_write_size) begin
            if_write_strobe   <=  1;
            o_wbs_ack         <=  1;
            write_count       <=  write_count + 24'h1;
          end
          else begin
            if_write_activate <=  0;
          end
        end
      end
      else begin
        //read request
        if (of_read_activate) begin
          if (read_count < of_read_size) begin
            read_count        <=  read_count + 1;
            o_wbs_dat         <=  of_read_data;
            o_wbs_ack         <=  1;
            of_read_strobe    <=  1;
          end
          else begin
            of_read_activate  <=  0;
          end
        end
      end
    end
    r_prev_cyc                <=  i_wbs_cyc;
  end
end
endmodule



