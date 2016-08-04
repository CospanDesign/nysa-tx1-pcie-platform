`timescale 1ns / 1ps

module tx1_ddr3_sim #(
  parameter          BUF_DEPTH       = 10,
  parameter          MEM_ADDR_DEPTH  = 28
)
(

  // Inouts
  inout [7:0]                                  ddr3_dq,
  inout                                        ddr3_dqs_n,
  inout                                        ddr3_dqs_p,

  // Outputs
  output [13:0]                                ddr3_addr,
  output [2:0]                                 ddr3_ba,
  output                                       ddr3_ras_n,
  output                                       ddr3_cas_n,
  output                                       ddr3_we_n,
  output                                       ddr3_reset_n,
  output                                       ddr3_ck_p,
  output                                       ddr3_ck_n,
  output                                       ddr3_cke,
  output                                       ddr3_cs_n,
  output                                       ddr3_dm,
  output                                       ddr3_odt,


  input                                        sys_clk_i,
  // user interface signals
  input   [MEM_ADDR_DEPTH-1:0]                 app_addr,
  input   [2:0]                                app_cmd,
  input                                        app_en,
  input   [31:0]                               app_wdf_data,
  input                                        app_wdf_end,
  input   [3:0]                                app_wdf_mask,
  input                                        app_wdf_wren,
  output  [31:0]                               app_rd_data,
  output  reg                                  app_rd_data_end,
  output  reg                                  app_rd_data_valid,
  output                                       app_rdy,
  output                                       app_wdf_rdy,
  input                                        app_sr_req,
  output                                       app_sr_active,
  input                                        app_ref_req,
  output                                       app_ref_ack,
  input                                        app_zq_req,
  output                                       app_zq_ack,
  output  reg                                  ui_clk,
  output  reg                                  ui_clk_sync_rst = 0,

  output  reg                                  init_calib_complete,

  output                                       pll_locked,

  // System reset - Default polarity of sys_rst pin is Active Low.
  // System reset polarity will change based on the option
  // selected in GUI.
  input                                        sys_rst
);


localparam ST_IDLE       = 2'h0;
localparam ST_DDR3_READ  = 2'h1;
localparam ST_DDR3_WRITE = 2'h2;

localparam  RST_COUNT           = 10;
localparam  INIT_CALIB_TIMEOUT  = 50;
localparam  RESET_TIMEOUT       = 100;


reg         rst;
reg [15:0]  r_en_count;
reg [15:0]  r_ddr3_addr;
reg [15:0]  r_ddr3_addra;
reg [31:0]  r_ddr3_dina;
reg         r_ddr3_wea;
reg  [2:0]  r_state;

wire        sim_ui_clk;


//Submodules


assign app_rdy              = 1;
assign app_wdf_rdy          = 1;
assign pll_locked           = 1;


reg [31:0]  init_count;
reg [31:0]  ui_reset_count;
reg [31:0]  rst_count       = 0;

always @ (posedge ui_clk) begin
  rst     <=  0;
  if (rst_count < RST_COUNT) begin
    rst_count               <=  rst_count + 1;
    rst                     <=  1;
  end
end


always @ (posedge ui_clk) begin
  ui_clk_sync_rst           <=  0;
  if (rst) begin
    init_calib_complete     <=  0;
    init_count              <=  0;

    ui_reset_count          <=  0;
  end
  else begin
    if (init_count < INIT_CALIB_TIMEOUT) begin
      init_count            <=  init_count + 1;
    end
    else begin
      init_calib_complete   <=  1;
    end

    if (ui_reset_count < RESET_TIMEOUT) begin
      ui_reset_count        <=  ui_reset_count + 1;
      ui_clk_sync_rst       <=  1;
    end
  end
end

always @ (*)  ui_clk  = sim_ui_clk;


always @(posedge ui_clk) begin

  if (rst) begin
    app_rd_data_valid <= 0;
    app_rd_data_end   <= 0;
    r_en_count          <= 0;
    r_ddr3_addr         <= 0;
    r_ddr3_addra        <= 0;
    r_ddr3_dina         <= 0;
    r_ddr3_wea          <= 0;
    r_state             <= ST_IDLE;
  end
  else begin
    if (app_en) begin
        r_en_count <= r_en_count + 2;
    end
    case (r_state)
      ST_IDLE: begin // 00
        app_rd_data_valid <= 0;
        app_rd_data_end   <= 0;
        r_ddr3_addr  <= app_addr[18:3];
        r_ddr3_addra <= app_addr[18:3];
        r_en_count   <= 2;
        if (app_en) begin
          if (app_cmd) begin
            r_state  <= ST_DDR3_READ;
          end else begin
            r_state  <= ST_DDR3_WRITE;
          end
        end
      end
      ST_DDR3_READ: begin // 01
        if (r_ddr3_addra < r_en_count) begin
          r_ddr3_addr  <= r_ddr3_addr + 1;
          r_ddr3_addra <= r_ddr3_addr;
          app_rd_data_valid <= 1;
          if (app_rd_data_valid) begin
            app_rd_data_end <= ~app_rd_data_end;
          end
        end else begin
          app_rd_data_valid <= 0;
          app_rd_data_end   <= 0;
          r_state <= ST_IDLE;
        end
      end
      ST_DDR3_WRITE: begin // 02
        if (r_ddr3_addr < r_en_count) begin
          if (app_wdf_wren) begin
            r_ddr3_addr  <= r_ddr3_addr + 1;
            r_ddr3_addra <= r_ddr3_addr;
            r_ddr3_dina  <= app_wdf_data;
            r_ddr3_wea   <= 1;
          end
        end
        else begin
          if (!app_wdf_wren) begin
            r_ddr3_wea <= 0;
            r_state    <= ST_IDLE;
          end
        end
      end
      default: begin
          r_state <= ST_IDLE;
      end
    endcase
  end
end

blk_mem #
(
  .DATA_WIDTH                    (32),
  .ADDRESS_WIDTH                 (16)
)
u_ddr3
(
    .clka                        (ui_clk),
    .addra                       (r_ddr3_addra),
    .dina                        (r_ddr3_dina),
    .wea                         (r_ddr3_wea),

    .clkb                        (ui_clk),
    .addrb                       (r_ddr3_addr),
    .doutb                       (app_rd_data)
);

endmodule

