`timescale 1ns/1ps

`include "dma_defines.v"

module tb_cocotb (

//Virtual Host Interface Signals
input             in_clk,
input             rst,
output            master_ready,
input             in_ready,
input   [31:0]    in_command,
input   [31:0]    in_address,
input   [31:0]    in_data,
input   [27:0]    in_data_count,

input             out_ready,
output            out_en,
output  [31:0]    out_status,
output  [31:0]    out_address,
output  [31:0]    out_data,
output  [27:0]    out_data_count,
input   [31:0]    test_id,

input             ih_reset,
output            device_interrupt
);


//Parameters
//Registers/Wires
reg               clk;
reg               r_rst;
reg               r_in_ready;
reg   [31:0]      r_in_command;
reg   [31:0]      r_in_address;
reg   [31:0]      r_in_data;
reg   [27:0]      r_in_data_count;
reg               r_out_ready;
reg               r_ih_reset;

//There is a bug in COCOTB when stiumlating a signal, sometimes it can be corrupted if not registered
always @ (*) clk             = in_clk;
always @ (*) r_rst           = rst;
always @ (*) r_in_ready      = in_ready;
always @ (*) r_in_command    = in_command;
always @ (*) r_in_address    = in_address;
always @ (*) r_in_data       = in_data;
always @ (*) r_in_data_count = in_data_count;
always @ (*) r_out_ready     = out_ready;
always @ (*) r_ih_reset      = ih_reset;

//wishbone signals
wire              w_wbp_we;
wire              w_wbp_cyc;
wire              w_wbp_stb;
wire [3:0]        w_wbp_sel;
wire [31:0]       w_wbp_adr;
wire [31:0]       w_wbp_dat_o;
wire [31:0]       w_wbp_dat_i;
wire              w_wbp_ack;
wire              w_wbp_int;



//Wishbone Slave 0 (SDB) signals
wire              w_wbs0_we;
wire              w_wbs0_cyc;
wire  [31:0]      w_wbs0_dat_o;
wire              w_wbs0_stb;
wire  [3:0]       w_wbs0_sel;
wire              w_wbs0_ack;
wire  [31:0]      w_wbs0_dat_i;
wire  [31:0]      w_wbs0_adr;
wire              w_wbs0_int;

//mem slave 0
wire              w_sm0_i_wbs_we;
wire              w_sm0_i_wbs_cyc;
wire  [31:0]      w_sm0_i_wbs_dat;
wire  [31:0]      w_sm0_o_wbs_dat;
wire  [31:0]      w_sm0_i_wbs_adr;
wire              w_sm0_i_wbs_stb;
wire  [3:0]       w_sm0_i_wbs_sel;
wire              w_sm0_o_wbs_ack;
wire              w_sm0_o_wbs_int;

//wishbone slave 1 (Unit Under Test) signals
wire              w_wbs1_we;
wire              w_wbs1_cyc;
wire              w_wbs1_stb;
wire  [3:0]       w_wbs1_sel;
wire              w_wbs1_ack;
wire  [31:0]      w_wbs1_dat_i;
wire  [31:0]      w_wbs1_dat_o;
wire  [31:0]      w_wbs1_adr;
wire              w_wbs1_int;

reg               execute_command;
reg               command_finished;
reg               request_more_data;
reg               request_more_data_ack;
reg     [27:0]    data_write_count;
reg     [27:0]    data_read_count;

wire              write_enable    [3:0];
wire    [63:0]    write_addr      [3:0];
wire              write_addr_inc  [3:0];
wire              write_addr_dec  [3:0];
wire              write_finished  [3:0];
wire    [23:0]    write_data_count[3:0];
wire              write_flush     [3:0];

wire    [1:0]     write_ready     [3:0];
wire    [1:0]     write_activate  [3:0];
wire    [23:0]    write_size      [3:0];
wire              write_strobe    [3:0];
wire    [31:0]    write_data      [3:0];


wire              read_enable     [3:0];
wire    [63:0]    read_addr       [3:0];
wire              read_addr_inc   [3:0];
wire              read_addr_dec   [3:0];
wire              read_busy       [3:0];
wire              read_error      [3:0];
wire    [23:0]    read_data_count [3:0];
wire              read_flush      [3:0];

wire              read_ready      [3:0];
wire              read_activate   [3:0];
wire    [23:0]    read_size       [3:0];
wire    [31:0]    read_data       [3:0];
wire              read_strobe     [3:0];


//Memory Interface
wire              w_mem_we_o;
wire              w_mem_cyc_o;
wire              w_mem_stb_o;
wire  [3:0]       w_mem_sel_o;
wire  [31:0]      w_mem_adr_o;
wire  [31:0]      w_mem_dat_i;
wire  [31:0]      w_mem_dat_o;
wire              w_mem_ack_i;
wire              w_mem_int_i;

wire              w_arb0_i_wbs_stb;
wire              w_arb0_i_wbs_cyc;
wire              w_arb0_i_wbs_we;
wire  [3:0]       w_arb0_i_wbs_sel;
wire  [31:0]      w_arb0_i_wbs_dat;
wire  [31:0]      w_arb0_o_wbs_dat;
wire  [31:0]      w_arb0_i_wbs_adr;
wire              w_arb0_o_wbs_ack;
wire              w_arb0_o_wbs_int;


wire              mem_o_we;
wire              mem_o_stb;
wire              mem_o_cyc;
wire  [3:0]       mem_o_sel;
wire  [31:0]      mem_o_adr;
wire  [31:0]      mem_o_dat;
wire  [31:0]      mem_i_dat;
wire              mem_i_ack;
wire              mem_i_int;


//DMA In Interface
wire                w_idma0_enable;
wire                w_idma0_finished;
wire        [31:0]  w_idma0_addr;
wire                w_idma0_busy;
wire        [23:0]  w_idma0_count;
wire                w_idma0_flush;

wire                w_idma0_strobe;
wire        [1:0]   w_idma0_ready;
wire        [1:0]   w_idma0_activate;
wire        [23:0]  w_idma0_size;
wire        [31:0]  w_idma0_data;

//DMA Out Interface
wire                w_odma0_enable;
wire       [31:0]   w_odma0_address;
wire       [23:0]   w_odma0_count;
wire                w_odma0_flush;

wire                w_odma0_strobe;
wire        [31:0]  w_odma0_data;
wire                w_odma0_ready;
wire                w_odma0_activate;
wire        [23:0]  w_odma0_size;


//Submodules
wishbone_master wm (
  .clk            (clk            ),
  .rst            (r_rst          ),

  .i_ih_rst       (r_ih_reset     ),
  .i_ready        (r_in_ready     ),
  .i_command      (r_in_command   ),
  .i_address      (r_in_address   ),
  .i_data         (r_in_data      ),
  .i_data_count   (r_in_data_count),
  .i_out_ready    (r_out_ready    ),
  .o_en           (out_en         ),
  .o_status       (out_status     ),
  .o_address      (out_address    ),
  .o_data         (out_data       ),
  .o_data_count   (out_data_count ),
  .o_master_ready (master_ready   ),

  .o_per_we       (w_wbp_we         ),
  .o_per_adr      (w_wbp_adr        ),
  .o_per_dat      (w_wbp_dat_i      ),
  .i_per_dat      (w_wbp_dat_o      ),
  .o_per_stb      (w_wbp_stb        ),
  .o_per_cyc      (w_wbp_cyc        ),
  .o_per_msk      (w_wbp_msk        ),
  .o_per_sel      (w_wbp_sel        ),
  .i_per_ack      (w_wbp_ack        ),
  .i_per_int      (w_wbp_int        ),

  //memory interconnect signals
  .o_mem_we       (w_mem_we_o       ),
  .o_mem_adr      (w_mem_adr_o      ),
  .o_mem_dat      (w_mem_dat_o      ),
  .i_mem_dat      (w_mem_dat_i      ),
  .o_mem_stb      (w_mem_stb_o      ),
  .o_mem_cyc      (w_mem_cyc_o      ),
  .o_mem_sel      (w_mem_sel_o      ),
  .i_mem_ack      (w_mem_ack_i      ),
  .i_mem_int      (w_mem_int_i      )

);

//slave 1
wb_dma s1 (

  .clk                    (clk                 ),
  .rst                    (rst                 ),

  .i_wbs_we               (w_wbs1_we           ),
  .i_wbs_cyc              (w_wbs1_cyc          ),
  .i_wbs_dat              (w_wbs1_dat_i        ),
  .i_wbs_stb              (w_wbs1_stb          ),
  .o_wbs_ack              (w_wbs1_ack          ),
  .o_wbs_dat              (w_wbs1_dat_o        ),
  .i_wbs_adr              (w_wbs1_adr          ),
  .o_wbs_int              (w_wbs1_int          ),

  //Source 0
  .o_src0_enable          (read_enable[0]      ),
  .o_src0_address         (read_addr[0]        ),
  .o_src0_count           (read_data_count[0]  ),
  .o_src0_addr_inc        (read_addr_inc[0]    ),
  .o_src0_addr_dec        (read_addr_dec[0]    ),
  .o_src0_flush           (read_flush[0]       ),

  .o_src0_if_strobe       (read_strobe[0]      ),
  .i_src0_if_data         (read_data[0]        ),
  .i_src0_if_ready        (read_ready[0]       ),
  .o_src0_if_activate     (read_activate[0]    ),
  .i_src0_if_size         (read_size[0]        ),

  //Source 1
  .o_src1_enable          (read_enable[1]      ),
  .o_src1_address         (read_addr[1]        ),
  .o_src1_count           (read_data_count[1]  ),
  .o_src1_addr_inc        (read_addr_inc[1]    ),
  .o_src1_addr_dec        (read_addr_dec[1]    ),
  .o_src1_flush           (read_flush[1]       ),

  .o_src1_if_strobe       (read_strobe[1]      ),
  .i_src1_if_data         (read_data[1]        ),
  .i_src1_if_ready        (read_ready[1]       ),
  .o_src1_if_activate     (read_activate[1]    ),
  .i_src1_if_size         (read_size[1]        ),

  //Source 2
  .o_src2_enable          (read_enable[2]      ),
  .o_src2_address         (read_addr[2]        ),
  .o_src2_count           (read_data_count[2]  ),
  .o_src2_addr_inc        (read_addr_inc[2]    ),
  .o_src2_addr_dec        (read_addr_dec[2]    ),
  .o_src2_flush           (read_flush[2]       ),

  .o_src2_if_strobe       (read_strobe[2]      ),
  .i_src2_if_data         (read_data[2]        ),
  .i_src2_if_ready        (read_ready[2]       ),
  .o_src2_if_activate     (read_activate[2]    ),
  .i_src2_if_size         (read_size[2]        ),

  //Source 3
  .o_src3_enable          (read_enable[3]      ),
  .o_src3_address         (read_addr[3]        ),
  .o_src3_count           (read_data_count[3]  ),
  .o_src3_addr_inc        (read_addr_inc[3]    ),
  .o_src3_addr_dec        (read_addr_dec[3]    ),
  .o_src3_flush           (read_flush[3]       ),

  .o_src3_if_strobe       (read_strobe[3]      ),
  .i_src3_if_data         (read_data[3]        ),
  .i_src3_if_ready        (read_ready[3]       ),
  .o_src3_if_activate     (read_activate[3]    ),
  .i_src3_if_size         (read_size[3]        ),

  //Sink 0
  .o_snk0_write_enable    (write_enable[0]     ),
  .i_snk0_write_finished  (write_finished[0]   ),
  .o_snk0_write_addr      (write_addr[0]       ),
  .o_snk0_write_addr_inc  (write_addr_inc[0]   ),
  .o_snk0_write_addr_dec  (write_addr_dec[0]   ),
  .o_snk0_write_count     (write_data_count[0] ),
  .o_snk0_flush           (write_flush[0]      ),

  .o_snk0_strobe          (write_strobe[0]     ),
  .i_snk0_ready           (write_ready[0]      ),
  .o_snk0_activate        (write_activate[0]   ),
  .i_snk0_size            (write_size[0]       ),
  .o_snk0_data            (write_data[0]       ),

  //Sink 1
  .o_snk1_write_enable    (write_enable[1]     ),
  .i_snk1_write_finished  (write_finished[1]   ),
  .o_snk1_write_addr      (write_addr[1]       ),
  .o_snk1_write_addr_inc  (write_addr_inc[1]   ),
  .o_snk1_write_addr_dec  (write_addr_dec[1]   ),
  .o_snk1_write_count     (write_data_count[1] ),
  .o_snk1_flush           (write_flush[1]      ),

  .o_snk1_strobe          (write_strobe[1]     ),
  .i_snk1_ready           (write_ready[1]      ),
  .o_snk1_activate        (write_activate[1]   ),
  .i_snk1_size            (write_size[1]       ),
  .o_snk1_data            (write_data[1]       ),

  //Sink 2
  .o_snk2_write_enable    (write_enable[2]     ),
  .i_snk2_write_finished  (write_finished[2]   ),
  .o_snk2_write_addr      (write_addr[2]       ),
  .o_snk2_write_addr_inc  (write_addr_inc[2]   ),
  .o_snk2_write_addr_dec  (write_addr_dec[2]   ),
  .o_snk2_write_count     (write_data_count[2] ),
  .o_snk2_flush           (write_flush[2]      ),

  .o_snk2_strobe          (write_strobe[2]     ),
  .i_snk2_ready           (write_ready[2]      ),
  .o_snk2_activate        (write_activate[2]   ),
  .i_snk2_size            (write_size[2]       ),
  .o_snk2_data            (write_data[2]       ),

  //Sink 3
  .o_snk3_write_enable    (write_enable[3]     ),
  .i_snk3_write_finished  (write_finished[3]   ),
  .o_snk3_write_addr      (write_addr[3]       ),
  .o_snk3_write_addr_inc  (write_addr_inc[3]   ),
  .o_snk3_write_addr_dec  (write_addr_dec[3]   ),
  .o_snk3_write_count     (write_data_count[3] ),
  .o_snk3_flush           (write_flush[3]      ),

  .o_snk3_strobe          (write_strobe[3]     ),
  .i_snk3_ready           (write_ready[3]      ),
  .o_snk3_activate        (write_activate[3]   ),
  .i_snk3_size            (write_size[3]       ),
  .o_snk3_data            (write_data[3]       )
);

//slave 1
wb_tx1_ppfifo_ddr3 m1 (

  .clk                  (clk                  ),
  .rst                  (r_rst                ),

  .i_wbs_we             (w_arb0_i_wbs_we      ),
  .i_wbs_sel            (4'b1111              ),
  .i_wbs_cyc            (w_arb0_i_wbs_cyc     ),
  .i_wbs_dat            (w_arb0_i_wbs_dat     ),
  .i_wbs_stb            (w_arb0_i_wbs_stb     ),
  .o_wbs_ack            (w_arb0_o_wbs_ack     ),
  .o_wbs_dat            (w_arb0_o_wbs_dat     ),
  .i_wbs_adr            (w_arb0_i_wbs_adr     ),
  .o_wbs_int            (w_arb0_o_wbs_int     ),


  //DMA In Interface
  .i_idma0_enable       (write_enable[2]      ),
  .o_idma0_finished     (write_finished[2]    ),
  .i_idma0_addr         (write_addr[2]        ),
  .i_idma0_busy         (                     ),
  .i_idma0_count        (write_data_count[2]  ),
  .i_idma0_flush        (write_flush[2]       ),

  .i_idma0_strobe       (write_strobe[2]      ),
  .o_idma0_ready        (write_ready[2]       ),
  .i_idma0_activate     (write_activate[2]    ),
  .o_idma0_size         (write_size[2]        ),
  .i_idma0_data         (write_data[2]        ),

  //DMA Out Interface
  .i_odma0_enable       (read_enable[2]       ),
  .i_odma0_address      (read_addr[2]         ),
  .i_odma0_count        (read_data_count[2]   ),
  .i_odma0_flush        (read_flush[2]        ),

  .i_odma0_strobe       (read_strobe[2]       ),
  .o_odma0_data         (read_data[2]         ),
  .o_odma0_ready        (read_ready[2]        ),
  .i_odma0_activate     (read_activate[2]     ),
  .o_odma0_size         (read_size[2]         )

);

wishbone_interconnect wi (
  .clk        (clk                  ),
  .rst        (r_rst                ),

  .i_m_we     (w_wbp_we             ),
  .i_m_cyc    (w_wbp_cyc            ),
  .i_m_stb    (w_wbp_stb            ),
  .o_m_ack    (w_wbp_ack            ),
  .i_m_dat    (w_wbp_dat_i          ),
  .o_m_dat    (w_wbp_dat_o          ),
  .i_m_adr    (w_wbp_adr            ),
  .o_m_int    (w_wbp_int            ),

  .o_s0_we    (w_wbs0_we            ),
  .o_s0_cyc   (w_wbs0_cyc           ),
  .o_s0_stb   (w_wbs0_stb           ),
  .i_s0_ack   (w_wbs0_ack           ),
  .o_s0_dat   (w_wbs0_dat_i         ),
  .i_s0_dat   (w_wbs0_dat_o         ),
  .o_s0_adr   (w_wbs0_adr           ),
  .i_s0_int   (w_wbs0_int           ),

  .o_s1_we    (w_wbs1_we            ),
  .o_s1_cyc   (w_wbs1_cyc           ),
  .o_s1_stb   (w_wbs1_stb           ),
  .i_s1_ack   (w_wbs1_ack           ),
  .o_s1_dat   (w_wbs1_dat_i         ),
  .i_s1_dat   (w_wbs1_dat_o         ),
  .o_s1_adr   (w_wbs1_adr           ),
  .i_s1_int   (w_wbs1_int           )
);

localparam AWIDTH0 = 8;
localparam AWIDTH1 = 8;
localparam AWIDTH2 = 8;
localparam AWIDTH3 = 8;

localparam READ_FIFO_SIZE0      = 8;
localparam WRITE_FIFO_SIZE0     = 8;

localparam READ_FIFO_SIZE1      = 8;
localparam WRITE_FIFO_SIZE1     = 8;

localparam READ_FIFO_SIZE2      = 6;
localparam WRITE_FIFO_SIZE2     = 6;

localparam READ_FIFO_SIZE3      = 8;
localparam WRITE_FIFO_SIZE3     = 8;



//1st Device
wb_test_dma_mem #(
  //.READ_FIFO_SIZE     ( READ_FIFO_SIZE0    ),
  //.WRITE_FIFO_SIZE    ( WRITE_FIFO_SIZE0   ),
  //.ADDR_WIDTH         (           AWIDTH0  )
)tdm0(
  .clk                (clk                 ),
  .rst                (rst                 ),

  .i_wbs_we           (1'b0                ),
  .i_wbs_stb          (1'b0                ),
  .i_wbs_cyc          (1'b0                ),
  .i_wbs_sel          (1'b0                ),
  .i_wbs_adr          (32'h0               ),
  .i_wbs_dat          (32'h0               ),
  .o_wbs_dat          (                    ),
  .o_wbs_ack          (                    ),
  .o_wbs_int          (                    ),

  .i_write_enable     (write_enable[0]     ),
  .i_write_addr       (write_addr[0]       ),
  .i_write_addr_inc   (write_addr_inc[0]   ),
  .i_write_addr_dec   (write_addr_dec[0]   ),
  .o_write_finished   (write_finished[0]   ),
  .i_write_count      (write_data_count[0] ),
  .i_write_flush      (write_flush[0]      ),

  .o_write_ready      (write_ready[0]      ),
  .i_write_activate   (write_activate[0]   ),
  .o_write_size       (write_size[0]       ),
  .i_write_strobe     (write_strobe[0]     ),
  .i_write_data       (write_data[0]       ),


  .i_read_enable      (read_enable[0]      ),
  .i_read_addr        (read_addr[0]        ),
  .i_read_addr_inc    (read_addr_inc[0]    ),
  .i_read_addr_dec    (read_addr_dec[0]    ),
  .o_read_busy        (read_busy[0]        ),
  .o_read_error       (read_error[0]       ),
  .i_read_count       (read_data_count[0]  ),
  .i_read_flush       (read_flush[0]       ),

  .o_read_ready       (read_ready[0]       ),
  .i_read_activate    (read_activate[0]    ),
  .o_read_size        (read_size[0]        ),
  .o_read_data        (read_data[0]        ),
  .i_read_strobe      (read_strobe[0]      )
);

//2nd Device
wb_test_dma_mem #(
    //.READ_FIFO_SIZE   ( READ_FIFO_SIZE1    ),
    //.WRITE_FIFO_SIZE  ( WRITE_FIFO_SIZE1   ),
    //.ADDR_WIDTH       (           AWIDTH1  )
)tdm1(
  .clk                (clk                 ),
  .rst                (rst                 ),

  .i_wbs_we           (0                   ),
  .i_wbs_stb          (0                   ),
  .i_wbs_cyc          (0                   ),
  .i_wbs_sel          (0                   ),
  .i_wbs_adr          (0                   ),
  .i_wbs_dat          (0                   ),
  .o_wbs_dat          (                    ),
  .o_wbs_ack          (                    ),
  .o_wbs_int          (                    ),


  .i_write_enable     (write_enable[1]     ),
  .i_write_addr       (write_addr[1]       ),
  .i_write_addr_inc   (write_addr_inc[1]   ),
  .i_write_addr_dec   (write_addr_dec[1]   ),
  .o_write_finished   (write_finished[1]   ),
  .i_write_count      (write_data_count[1] ),
  .i_write_flush      (write_flush[1]      ),

  .o_write_ready      (write_ready[1]      ),
  .i_write_activate   (write_activate[1]   ),
  .o_write_size       (write_size[1]       ),
  .i_write_strobe     (write_strobe[1]     ),
  .i_write_data       (write_data[1]       ),


  .i_read_enable      (read_enable[1]      ),
  .i_read_addr        (read_addr[1]        ),
  .i_read_addr_inc    (read_addr_inc[1]    ),
  .i_read_addr_dec    (read_addr_dec[1]    ),
  .o_read_busy        (read_busy[1]        ),
  .o_read_error       (read_error[1]       ),
  .i_read_count       (read_data_count[1]  ),
  .i_read_flush       (read_flush[1]       ),

  .o_read_ready       (read_ready[1]       ),
  .i_read_activate    (read_activate[1]    ),
  .o_read_size        (read_size[1]        ),
  .o_read_data        (read_data[1]        ),
  .i_read_strobe      (read_strobe[1]      )
);

/*
//3rd Device
wb_test_dma_mem #(
    //.READ_FIFO_SIZE   (  READ_FIFO_SIZE2   ),
    //.WRITE_FIFO_SIZE  (  WRITE_FIFO_SIZE2  ),
    //.ADDR_WIDTH       (           AWIDTH2  )
)tdm2(
  .clk                (clk                 ),
  .rst                (rst                 ),

  .i_wbs_we           (0                   ),
  .i_wbs_stb          (0                   ),
  .i_wbs_cyc          (0                   ),
  .i_wbs_sel          (0                   ),
  .i_wbs_adr          (0                   ),
  .i_wbs_dat          (0                   ),
  .o_wbs_dat          (                    ),
  .o_wbs_ack          (                    ),
  .o_wbs_int          (                    ),


  .i_write_enable     (write_enable[2]     ),
  .i_write_addr       (write_addr[2]       ),
  .i_write_addr_inc   (write_addr_inc[2]   ),
  .i_write_addr_dec   (write_addr_dec[2]   ),
  .o_write_finished   (write_finished[2]   ),
  .i_write_count      (write_data_count[2] ),
  .i_write_flush      (write_flush[2]      ),

  .o_write_ready      (write_ready[2]      ),
  .i_write_activate   (write_activate[2]   ),
  .o_write_size       (write_size[2]       ),
  .i_write_strobe     (write_strobe[2]     ),
  .i_write_data       (write_data[2]       ),


  .i_read_enable      (read_enable[2]      ),
  .i_read_addr        (read_addr[2]        ),
  .i_read_addr_inc    (read_addr_inc[2]    ),
  .i_read_addr_dec    (read_addr_dec[2]    ),
  .o_read_busy        (read_busy[2]        ),
  .o_read_error       (read_error[2]       ),
  .i_read_count       (read_data_count[2]  ),
  .i_read_flush       (read_flush [2]      ),

  .o_read_ready       (read_ready[2]       ),
  .i_read_activate    (read_activate[2]    ),
  .o_read_size        (read_size[2]        ),
  .o_read_data        (read_data[2]        ),
  .i_read_strobe      (read_strobe[2]      )
);
*/

//4th Device
wb_test_dma_mem #(
    //.READ_FIFO_SIZE   (  READ_FIFO_SIZE3   ),
    //.WRITE_FIFO_SIZE  (  WRITE_FIFO_SIZE3  ),
    //.ADDR_WIDTH       (           AWIDTH3  )
)tdm3(
  .clk                (clk                 ),
  .rst                (rst                 ),

  .i_wbs_we           (0                   ),
  .i_wbs_stb          (0                   ),
  .i_wbs_cyc          (0                   ),
  .i_wbs_sel          (0                   ),
  .i_wbs_adr          (0                   ),
  .i_wbs_dat          (0                   ),
  .o_wbs_dat          (                    ),
  .o_wbs_ack          (                    ),
  .o_wbs_int          (                    ),

  .i_write_enable     (write_enable[3]     ),
  .i_write_addr       (write_addr[3]       ),
  .i_write_addr_inc   (write_addr_inc[3]   ),
  .i_write_addr_dec   (write_addr_dec[3]   ),
  .o_write_finished   (write_finished[3]   ),
  .i_write_count      (write_data_count[3] ),
  .i_write_flush      (write_flush[3]      ),

  .o_write_ready      (write_ready[3]      ),
  .i_write_activate   (write_activate[3]   ),
  .o_write_size       (write_size[3]       ),
  .i_write_strobe     (write_strobe[3]     ),
  .i_write_data       (write_data[3]       ),


  .i_read_enable      (read_enable[3]      ),
  .i_read_addr        (read_addr[3]        ),
  .i_read_addr_inc    (read_addr_inc[3]    ),
  .i_read_addr_dec    (read_addr_dec[3]    ),
  .o_read_busy        (read_busy[3]        ),
  .o_read_error       (read_error[3]       ),
  .i_read_count       (read_data_count[3]  ),
  .i_read_flush       (read_flush [3]      ),

  .o_read_ready       (read_ready[3]       ),
  .i_read_activate    (read_activate[3]    ),
  .o_read_size        (read_size[3]        ),
  .o_read_data        (read_data[3]        ),
  .i_read_strobe      (read_strobe[3]      )
);


assign  w_wbs0_ack              = 0;
assign  w_wbs0_dat_o            = 0;
assign  start                   = 1;




wishbone_mem_interconnect wmi (
  .clk        (clk                  ),
  .rst        (r_rst                ),

  //master
  .i_m_we     (w_mem_we_o           ),
  .i_m_cyc    (w_mem_cyc_o          ),
  .i_m_stb    (w_mem_stb_o          ),
  .i_m_sel    (w_mem_sel_o          ),
  .o_m_ack    (w_mem_ack_i          ),
  .i_m_dat    (w_mem_dat_o          ),
  .o_m_dat    (w_mem_dat_i          ),
  .i_m_adr    (w_mem_adr_o          ),
  .o_m_int    (w_mem_int_i          ),

  //slave 0
  .o_s0_we    (w_sm0_i_wbs_we       ),
  .o_s0_cyc   (w_sm0_i_wbs_cyc      ),
  .o_s0_stb   (w_sm0_i_wbs_stb      ),
  .o_s0_sel   (w_sm0_i_wbs_sel      ),
  .i_s0_ack   (w_sm0_o_wbs_ack      ),
  .o_s0_dat   (w_sm0_i_wbs_dat      ),
  .i_s0_dat   (w_sm0_o_wbs_dat      ),
  .o_s0_adr   (w_sm0_i_wbs_adr      ),
  .i_s0_int   (w_sm0_o_wbs_int      )
);

arbiter_2_masters arb0 (
  .clk        (clk                  ),
  .rst        (r_rst                ),

  //masters
  .i_m1_we    (mem_o_we             ),
  .i_m1_stb   (mem_o_stb            ),
  .i_m1_cyc   (mem_o_cyc            ),
  .i_m1_sel   (mem_o_sel            ),
  .i_m1_dat   (mem_o_dat            ),
  .i_m1_adr   (mem_o_adr            ),
  .o_m1_dat   (mem_i_dat            ),
  .o_m1_ack   (mem_i_ack            ),
  .o_m1_int   (mem_i_int            ),


  .i_m0_we    (w_sm0_i_wbs_we       ),
  .i_m0_stb   (w_sm0_i_wbs_stb      ),
  .i_m0_cyc   (w_sm0_i_wbs_cyc      ),
  .i_m0_sel   (w_sm0_i_wbs_sel      ),
  .i_m0_dat   (w_sm0_i_wbs_dat      ),
  .i_m0_adr   (w_sm0_i_wbs_adr      ),
  .o_m0_dat   (w_sm0_o_wbs_dat      ),
  .o_m0_ack   (w_sm0_o_wbs_ack      ),
  .o_m0_int   (w_sm0_o_wbs_int      ),

  //slave
  .o_s_we     (w_arb0_i_wbs_we      ),
  .o_s_stb    (w_arb0_i_wbs_stb     ),
  .o_s_cyc    (w_arb0_i_wbs_cyc     ),
  .o_s_sel    (w_arb0_i_wbs_sel     ),
  .o_s_dat    (w_arb0_i_wbs_dat     ),
  .o_s_adr    (w_arb0_i_wbs_adr     ),
  .i_s_dat    (w_arb0_o_wbs_dat     ),
  .i_s_ack    (w_arb0_o_wbs_ack     ),
  .i_s_int    (w_arb0_o_wbs_int     )
);

/*
wb_bram #(
  .DATA_WIDTH (32                   ),
  .ADDR_WIDTH (10                   )
)bram(
  .clk        (clk                  ),
  .rst        (r_rst                ),

  .i_wbs_we   (w_arb0_i_wbs_we      ),
  .i_wbs_sel  (w_arb0_i_wbs_sel     ),
  .i_wbs_cyc  (w_arb0_i_wbs_cyc     ),
  .i_wbs_dat  (w_arb0_i_wbs_dat     ),
  .i_wbs_stb  (w_arb0_i_wbs_stb     ),
  .i_wbs_adr  (w_arb0_i_wbs_adr     ),
  .o_wbs_dat  (w_arb0_o_wbs_dat     ),
  .o_wbs_ack  (w_arb0_o_wbs_ack     ),
  .o_wbs_int  (w_arb0_o_wbs_int     )
);
*/

//Disable Slave 0
assign  w_wbs0_int              = 0;
assign  w_wbs0_ack              = 0;
assign  w_wbs0_dat_o            = 0;
assign  device_interrupt        = w_wbp_int;

/*
  READ ME IF YOUR MODULE WILL INTERFACE WITH MEMORY

  If you want to talk to memory over the wishbone bus directly, your module must control the following signals:

  (Your module will be a wishbone master)
    mem_o_we
    mem_o_stb
    mem_o_cyc
    mem_o_sel
    mem_o_adr
    mem_o_dat
    mem_i_dat
    mem_i_ack
    mem_i_int

  Currently this bus is disabled so if will not interface with memory these signals can be left

  For a reference check out wb_sd_host

*/
assign  mem_o_we                = 0;
assign  mem_o_stb               = 0;
assign  mem_o_cyc               = 0;
assign  mem_o_sel               = 0;
assign  mem_o_adr               = 0;
assign  mem_o_dat               = 0;


assign  w_idma0_enable          = 0;
assign  w_idma0_addr            = 0;
assign  w_idma0_busy            = 0;
assign  w_idma0_count           = 0;
assign  w_idma0_flush           = 0;

assign  w_idma0_strobe          = 0;
assign  w_idma0_activate        = 0;
assign  w_idma0_data            = 0;

assign  w_odma0_enable          = 0;
assign  w_odma0_address         = 0;
assign  w_odma0_count           = 0;
assign  w_odma0_flush           = 0;

assign  w_odma0_strobe          = 0;
assign  w_odma0_activate        = 0;



//Submodules
//Asynchronous Logic
//Synchronous Logic
//Simulation Control
initial begin
  $dumpfile ("design.vcd");
  $dumpvars(0, tb_cocotb);
end

endmodule
