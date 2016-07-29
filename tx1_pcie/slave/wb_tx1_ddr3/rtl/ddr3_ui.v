//-------------------------------------------------------------------
//
//  COPYRIGHT (C) 2012, red_digital_cinema
//
//  THIS FILE MAY NOT BE MODIFIED OR REDISTRIBUTED WITHOUT THE
//  EXPRESSED WRITTEN CONSENT OF red_digital_cinema
//
//  red_digital_cinema
//  326 e. hillcrest drive              info@red_digital_cinema.com
//  suite 100
//  thousand oaks, ca 91360
//-------------------------------------------------------------------
// Title   : ddr3_ui.v
// Author  : fred mccoy
// Created : 01/04/2012
// Description:
// writes rbuf data into ddr3 memory
// reads ddr3 memory into tbuf
//
// $Id$
//-------------------------------------------------------------------

`timescale 1ns / 1ps

/* STYLE_NOTES begin
  *
  * */
module ddr3_ui #(
  parameter          BUF_DEPTH       = 10,
  parameter          MEM_ADDR_DEPTH  = 28
)(
  input              ui_clk,

  input              i_app_phy_init_done,
  input              i_app_rdy,
  input              i_app_wdf_rdy,
  output reg         o_app_en,
  output reg   [2:0] o_app_cmd,
  output reg  [MEM_ADDR_DEPTH - 1:0] o_app_addr,
  output reg         o_app_wdf_wren,
  output reg         o_app_wdf_end,
  output      [31:0] o_app_wdf_data,
  input              i_app_rd_data_valid,
  input              i_app_rd_data_end,
  input       [31:0] i_app_rd_data,

  input              i_ibuf_go,
  output reg         o_ibuf_bsy,
  output reg         o_ibuf_ddr3_fault,
  input       [BUF_DEPTH - 1:0] i_ibuf_count,
  input       [BUF_DEPTH - 1:0] i_ibuf_start_addrb,
  output reg  [BUF_DEPTH - 1:0] o_ibuf_addrb,
  input       [31:0] i_ibuf_doutb,
  input       [MEM_ADDR_DEPTH - 1:0] i_ibuf_ddr3_addrb,

  input              i_obuf_go,
  output reg         o_obuf_bsy,
  output reg         o_obuf_ddr3_fault,
  input       [BUF_DEPTH - 1:0] i_obuf_count,
  input       [BUF_DEPTH - 1:0] i_obuf_start_addra,
  output reg  [BUF_DEPTH - 1:0] o_obuf_addra,
  output reg  [31:0] o_obuf_dina,
  output reg         o_obuf_wea,
  input       [MEM_ADDR_DEPTH - 1:0] i_obuf_ddr3_addra,
  input              rst
);

localparam ST_IDLE          = 2'h0;
localparam ST_IBUF_TO_DDR3  = 2'h1;
localparam ST_DDR3_TO_OBUF  = 2'h2;

localparam CMD_WR   = 3'b000;
localparam CMD_RD   = 3'b001;

reg  [MEM_ADDR_DEPTH - 1:0] r_app_addr;
reg  [BUF_DEPTH - 1:0] r_app_count;
reg  [BUF_DEPTH - 1:0] r_app_addr_count;
reg  [BUF_DEPTH - 1:0] r_app_data_count;
reg   [7:0] r_app_data_timer;
reg  [BUF_DEPTH - 1:0] r_obuf_addra;
reg  [15:0] r_state_clks;
reg  [15:0] r_write_clks;
reg  [15:0] r_read_clks;
reg   [1:0] r_state;

//wire [MEM_ADDR_DEPTH - 1:0] w_app_addr;

//assign w_app_addr = o_app_addr[MEM_ADDR_DEPTH - 1:3];
//o_app_wdf_data is the same as i_ibuf_doutb
assign o_app_wdf_data = i_ibuf_doutb;

always @(posedge ui_clk)
if (rst) begin

    o_app_en           <= 0;
    o_app_cmd          <= CMD_RD;
    o_app_wdf_wren     <= 0;
    o_app_wdf_end      <= 0;
    r_app_addr         <= 0;
    r_app_count        <= 0;
    r_app_addr_count   <= 0;
    r_app_data_count   <= 0;
    r_app_data_timer   <= 0;
    o_app_addr         <= 0;
    o_ibuf_addrb       <= 0;
    o_obuf_addra       <= 0;
    o_ibuf_bsy         <= 0;
    o_obuf_bsy         <= 0;
    o_ibuf_ddr3_fault  <= 0;
    o_obuf_ddr3_fault  <= 0;
    r_obuf_addra       <= 0;
    o_obuf_wea         <= 0;
    r_write_clks       <= 0;
    r_read_clks        <= 0;
    r_state_clks       <= 0;
    r_state            <= ST_IDLE;

end else begin

    o_app_addr[MEM_ADDR_DEPTH - 1:3] <= r_app_addr;
    o_app_addr[ 2:0] <= 0;

    //debug clock counter
    r_state_clks <= r_state_clks + 1;

    case (r_state)

    ST_IDLE: begin // 00
        o_app_cmd        <= CMD_RD;
        o_app_en         <= 0;
        o_app_wdf_wren   <= 0;
        o_app_wdf_end    <= 0;
        r_app_addr       <= 0;
        r_app_addr_count <= 0;
        r_app_data_count <= 0;
        r_app_data_timer <= 0;
        o_ibuf_addrb     <= 0;
        o_obuf_addra     <= 0;
        r_obuf_addra     <= 0;
        o_obuf_dina      <= 0;
        o_obuf_wea       <= 0;
        o_ibuf_bsy       <= 0;
        o_obuf_bsy       <= 0;
        r_state_clks     <= 0;
        if (i_app_phy_init_done) begin
            if (i_ibuf_go) begin
                o_ibuf_bsy        <= 1;
                o_app_cmd         <= CMD_WR;
                r_app_addr        <= i_ibuf_ddr3_addrb;
                r_app_count       <= i_ibuf_count;
                o_ibuf_addrb      <= i_ibuf_start_addrb;
                o_ibuf_ddr3_fault <= 0;
                r_state           <= ST_IBUF_TO_DDR3;
            end else
            if (i_obuf_go) begin
                o_obuf_bsy        <= 1;
                o_app_cmd         <= CMD_RD;
                r_app_addr        <= i_obuf_ddr3_addra;
                r_app_count       <= i_obuf_count;
                o_obuf_ddr3_fault <= 0;
                o_obuf_addra      <= i_obuf_start_addra;
                r_state           <= ST_DDR3_TO_OBUF;
            end
        end else begin
        end
    end


    ST_IBUF_TO_DDR3: begin // 03

        //ddr3 burst length is 8, so pace the address request
        //every 2nd clock because data read can only ouput as
        //2x 32bit words minimum and it takes 2 clocks minimum
        if (r_app_addr_count != r_app_count) begin
            if (i_app_rdy) begin
                r_app_addr_count <= r_app_addr_count + 1;
                o_app_en         <= ~o_app_en;
                if (o_app_en) begin
                    r_app_addr   <= r_app_addr + 1;
                end
            end
        end else begin
            //count is done, wait for ready and complete any
            //last o_app_en
            if (i_app_rdy) begin
                o_app_en <= 0;
            end
        end

        //do r_app_data_count tranactions. The counts have to be
        //1/2 the number of 32bit words to transfer because of
        //ddr3 burst length of 8. evey 2nd clock is an o_app_wdf_end pulse.
        if (r_app_data_count != r_app_count) begin
            if (r_app_data_count != r_app_addr_count) begin
                if (i_app_wdf_rdy) begin
                    r_app_data_timer <= 0;
                    o_app_wdf_wren   <= 1;
                    o_ibuf_addrb <= o_ibuf_addrb + 1;
                    if (o_app_wdf_wren) begin
                        r_app_data_count <= r_app_data_count + 1;
                        o_app_wdf_end    <= ~o_app_wdf_end;
                    end
                end else begin
                    if (r_app_data_timer == 100) begin
                        o_ibuf_ddr3_fault <= 1;
                        o_ibuf_bsy <= 0;
                        r_write_clks <= r_state_clks;
                        r_state    <= ST_IDLE;
                    end else begin
                        r_app_data_timer <= r_app_data_timer + 1;
                    end
                end
            end
        end else begin
            o_app_cmd      <= CMD_RD;
            o_ibuf_bsy     <= 0;
            o_app_wdf_end  <= 0;
            o_app_wdf_wren <= 0;
            r_write_clks   <= r_state_clks;
            r_state        <= ST_IDLE;
        end
    end


    //----------------------------------------------

    ST_DDR3_TO_OBUF: begin // 06

        //ddr3 burst length is 8, so pace the address request
        //every 2nd clock because data read can only ouput as
        //2x 32bit words minimum and it takes 2 clocks minimum
        if (r_app_addr_count != r_app_count) begin
            if (i_app_rdy) begin
                r_app_addr_count <= r_app_addr_count + 1;
                o_app_en         <= ~o_app_en;
                if (o_app_en) begin
                    r_app_addr <= r_app_addr + 1;
                end
            end
        end else begin
            //count is done, wait for ready and complete any
            //last o_app_en
            if (i_app_rdy) begin
                o_app_en <= 0;
            end
        end

        //do r_app_data_count tranactions. The counts have to be
        //1/2 the number of 32bit words to transfer because of
        //ddr3 burst length of 8. evey 2nd clock is an o_app_wdf_end pulse.
        if (r_app_data_count != r_app_count) begin
            if (i_app_rd_data_valid) begin
                r_app_data_timer <= 0;
                r_obuf_addra     <= r_obuf_addra + 1;
                o_obuf_addra     <= r_obuf_addra;
                o_obuf_dina      <= i_app_rd_data;
                o_obuf_wea       <= 1;
                r_app_data_count <= r_app_data_count + 1;
            end else begin
                //no app_rd_data_valid so start timing how long it
                //isn't here. If too long, then set timout error
                if (r_app_data_timer == 100) begin
                    o_obuf_ddr3_fault <= 1;
                    o_obuf_bsy  <= 0;
                    r_read_clks <= r_state_clks;
                    r_state     <= ST_IDLE;
                end else begin
                    r_app_data_timer <= r_app_data_timer + 1;
                end
            end
        end else begin
            o_obuf_bsy  <= 0;
            r_read_clks <= r_state_clks;
            r_state     <= ST_IDLE;
        end
    end

    default: begin //
        r_state <= ST_IDLE;
    end
    endcase
end

endmodule





