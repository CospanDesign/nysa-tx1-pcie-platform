//-------------------------------------------------------------------
//
//  COPYRIGHT (C) 2012, red_digital_cinema
//
//  THIS FILE MAY NOT BE MODIFIED OR REDISTRIBUTED WITHOUT THE
//  EXPRESSED WRITTEN CONSENT OF red_digital_cinema
//
//  red_digital_cinema                   http://www.red.com
//  325 e. hillcrest drive              info@red_digital_cinema.com
//  suite 100                           805 795-9925
//  thousand oaks, ca 91360
//-------------------------------------------------------------------
// Title       : ddr3_api.v
// Author      : fred mccoy
// Created     : 12/09/2012
// Description : Simulates Xilinx DDR3 API with 4096x64 DDR3 memory
//
// $Id$
//-------------------------------------------------------------------

`timescale 1ns / 1ps

/* STYLE_NOTES begin
  *
  * */
module ddr3_ui_sim #(
  parameter          BUF_DEPTH       = 10,
  parameter          MEM_ADDR_DEPTH  = 28
)
(
  input                               ui_clk,
                                      
  output                              o_app_phy_init_done,
  output                              o_app_rdy,
  output                              o_app_wdf_rdy,
  input                               i_app_en,
  input       [2:0]                   i_app_cmd,
  input       [MEM_ADDR_DEPTH - 1:0]  i_app_addr,
  input                               i_app_wdf_wren,
  input                               i_app_wdf_end,
  input       [31:0]                  i_app_wdf_data,
  output reg                          o_app_rd_data_valid,
  output reg                          o_app_rd_data_end,
  output      [31:0]                  o_app_rd_data,

  input                               rst
);


localparam ST_IDLE       = 2'h0;
localparam ST_DDR3_READ  = 2'h1;
localparam ST_DDR3_WRITE = 2'h2;

reg [15:0] r_en_count;
reg [15:0] r_ddr3_addr;
reg [15:0] r_ddr3_addra;
reg [31:0] r_ddr3_dina;
reg        r_ddr3_wea;
reg  [2:0] r_state;

assign o_app_phy_init_done = 1;
assign o_app_rdy           = 1;
assign o_app_wdf_rdy       = 1;


always @(posedge ui_clk or posedge rst)
if (rst) begin
    o_app_rd_data_valid <= 0;
    o_app_rd_data_end   <= 0;
    r_en_count          <= 0;
    r_ddr3_addr         <= 0;
    r_ddr3_addra        <= 0;
    r_ddr3_dina         <= 0;
    r_ddr3_wea          <= 0;
    r_state             <= ST_IDLE;
end
else begin

    if (i_app_en) begin
        r_en_count <= r_en_count + 2;
    end

    case (r_state)

    ST_IDLE: begin // 00
        o_app_rd_data_valid <= 0;
        o_app_rd_data_end   <= 0;
        r_ddr3_addr  <= i_app_addr[18:3];
        r_ddr3_addra <= i_app_addr[18:3];
        r_en_count   <= 2;
        if (i_app_en) begin
            if (i_app_cmd) begin
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
            o_app_rd_data_valid <= 1;
            if (o_app_rd_data_valid) begin
                o_app_rd_data_end <= ~o_app_rd_data_end;
            end
        end else begin
            o_app_rd_data_valid <= 0;
            o_app_rd_data_end   <= 0;
            r_state <= ST_IDLE;
        end
    end

    ST_DDR3_WRITE: begin // 02
        if (r_ddr3_addr < r_en_count) begin
            if (i_app_wdf_wren) begin
                r_ddr3_addr  <= r_ddr3_addr + 1;
                r_ddr3_addra <= r_ddr3_addr;
                r_ddr3_dina  <= i_app_wdf_data;
                r_ddr3_wea   <= 1;
            end
        end else begin
            if (!i_app_wdf_wren) begin
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
    .doutb                       (o_app_rd_data)
);                               

endmodule

