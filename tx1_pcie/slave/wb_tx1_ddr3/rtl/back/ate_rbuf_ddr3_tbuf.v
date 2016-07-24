//-------------------------------------------------------------------
//
//  COPYRIGHT (C) 2012, red_digital_cinema
//
//  THIS FILE MAY NOT BE MODIFIED OR REDISTRIBUTED WITHOUT THE
//  EXPRESSED WRITTEN CONSENT OF red_digital_cinema
//
//  red_digital_cinema                   
//  325 e. hillcrest drive              info@red_digital_cinema.com
//  suite 100                           
//  thousand oaks, ca 91360
//-------------------------------------------------------------------
// Title   : ate_rbuf_ddr3_tbuf.v
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
module ate_rbuf_ddr3_tbuf
(
    input              ui_clk160,
    input              ui_clk80,

    input              i_app_phy_init_done,
    input              i_app_rdy,
    input              i_app_wdf_rdy,
    output reg         o_app_en,
    output reg   [2:0] o_app_cmd,
    output reg  [28:0] o_app_addr,
    output reg         o_app_wdf_wren,
    output reg         o_app_wdf_end,
    output     [255:0] o_app_wdf_data,
    input              i_app_rd_data_valid,
    input              i_app_rd_data_end,
    input      [255:0] i_app_rd_data,

    input       [15:0] i_cmd_frame_row_count,
    input              i_cmd_go,
    output reg         o_cmd_done,
    input              i_mclk_output_done,

    input              i_rbuf_bank,
    input              i_frame_start,
    output reg   [8:0] o_row_rbuf_addrb,
    input      [255:0] i_row_rbuf_doutb,

    input              i_port_hsync,
    output reg         o_row_tbuf_go,
    input        [8:0] i_row_tbuf_addrb,
    output     [255:0] o_row_tbuf1_doutb,
    output     [255:0] o_row_tbuf2_doutb,
    output reg [15:0]  o_wdata,
    output       [3:0] o_state,
    input              rst
);

localparam ST_IDLE                    = 4'h0;
localparam ST_WAIT_PHY_INIT_DONE      = 4'h1;
localparam ST_WRITE_ROW_LOOP          = 4'h2;
localparam ST_WRITE_ROW_TO_DDR3       = 4'h3;
localparam ST_WRITE_NEXT_ROW          = 4'h4;
localparam ST_READ_ROW_LOOP           = 4'h5;
localparam ST_READ_ROW                = 4'h6;
localparam ST_READ_NEXT_ROW           = 4'h7;
localparam ST_WAIT_mclk_OUTPUT_DONE = 4'h8;

//r_addr_state's and r_data_state's
localparam STEP0                  = 2'h0;
localparam STEP1                  = 2'h1;
localparam STEP2                  = 2'h2;

localparam ROW_SIZE = 144;
localparam CMD_WR   = 3'b000;
localparam CMD_RD   = 3'b001;

reg  [15:0] r_frame_row_count;
reg  [15:0] r_frame_row_count0;
reg  [15:0] r_frame_row_count1;
reg  [15:0] r_frame_row_count2;
reg  [15:0] r_app_row_num;
reg  [ 7:0] r_app_en_count;
reg  [ 7:0] r_app_en_addr;
reg  [ 8:0] r_app_data_count;
reg   [2:0] r_cmd_go_shift_reg;
reg   [2:0] r_bank_shift_reg;
reg   [2:0] r_start_shift_reg;
reg   [2:0] r_hsync_shift_reg;
reg   [2:0] r_mclk_output_done_sr;
reg   [3:0] r_row_tbuf_count;
reg         r_row_tbuf_bank;
reg   [8:0] r_row_tbuf_addra;
reg   [8:0] r_row_tbuf_addra0;
reg [255:0] r_row_tbuf_dina;
reg         r_row_tbuf1_wea;
reg         r_row_tbuf2_wea;
reg  [15:0] r_state_clks;
reg   [1:0] r_addr_state;
reg   [1:0] r_data_state;
reg  [15:0] r_count;
reg  [ 3:0] r_state;

//use app_wdf_end to select upper or lower 256 bits of pixel data
//assign o_app_wdf_data = i_row_rbuf_doutb[255:0];
assign o_app_wdf_data = i_row_rbuf_doutb[255:0];

//assign o_app_addr[28:24] = 0;
//assign o_app_addr[23:11] = r_app_row_num[12:0];
//assign o_app_addr[10: 3] = r_app_en_addr;
//assign o_app_addr[ 2: 0] = 0;

assign o_state = r_state;

always @(posedge ui_clk160)
if (rst) begin

    r_frame_row_count  <= 0;
    r_frame_row_count0 <= 0;
    r_frame_row_count1 <= 0;
    r_frame_row_count2 <= 0;
    r_cmd_go_shift_reg <= 0;
    r_bank_shift_reg   <= 0;
    r_start_shift_reg  <= 0;
    r_hsync_shift_reg  <= 0;
    r_mclk_output_done_sr <= 0;
    r_row_tbuf_count   <= 0;
    r_row_tbuf_addra   <= 0;
    r_row_tbuf_addra0  <= 0;
    r_row_tbuf_dina    <= 0;
    r_row_tbuf1_wea    <= 0;
    r_row_tbuf2_wea    <= 0;
    r_app_row_num      <= 0;
    r_app_en_count     <= 0;
    r_app_en_addr      <= 0;
    r_app_data_count   <= 0;
    r_state_clks       <= 0;
    r_count            <= 0;
    r_addr_state       <= 0;
    r_data_state       <= 0;
    r_state            <= ST_WAIT_PHY_INIT_DONE;
    o_wdata            <= 0;
    o_cmd_done         <= 0;
    o_row_rbuf_addrb   <= 0;
    o_row_tbuf_go      <= 0;
    r_row_tbuf_bank    <= 0;
    o_app_addr         <= 0;
    o_app_en           <= 0;
    o_app_cmd          <= CMD_RD;
    o_app_wdf_wren     <= 0;
    o_app_wdf_end      <= 0;

end else begin

    o_app_addr[28:24] <= 0;
    o_app_addr[23:11] <= r_app_row_num[12:0];
    o_app_addr[10: 3] <= r_app_en_count;
    o_app_addr[ 2: 0] <= 0;

    //transfter i_cmd_frame_row_count to cml_clk80 clock domain
    r_frame_row_count0 <= i_cmd_frame_row_count;
    r_frame_row_count1 <= r_frame_row_count0;
    r_frame_row_count2 <= r_frame_row_count1;
    if (r_frame_row_count2 == r_frame_row_count1) begin
        r_frame_row_count  <= r_frame_row_count2;
    end

    r_cmd_go_shift_reg <= {r_cmd_go_shift_reg[1:0], i_cmd_go};
    r_bank_shift_reg   <= {r_bank_shift_reg[1:0],   i_rbuf_bank};
    r_hsync_shift_reg  <= {r_hsync_shift_reg[1:0],  i_port_hsync};
    r_start_shift_reg  <= {r_start_shift_reg[1:0],  i_frame_start};
    r_mclk_output_done_sr <= {r_mclk_output_done_sr[1:0], i_mclk_output_done};

    //toggle r_row_tbuf_bank on falling edge of hsync
    if (r_hsync_shift_reg[2:1] == 2'b10) begin
        r_row_tbuf_bank <= ~r_row_tbuf_bank;
    end

    case (r_state)

    ST_IDLE: begin // 00
        o_cmd_done        <= 0;
        o_app_cmd         <= CMD_RD;
        o_app_en          <= 0;
        r_app_en_count    <= 0;
        r_app_en_addr     <= 0;
        r_app_data_count  <= 0;
        o_wdata           <= 0;
        o_app_wdf_wren    <= 0;
        o_app_wdf_end     <= 0;
        r_state_clks      <= 0;
        r_app_row_num     <= 0;
        r_count           <= 0;
        o_row_rbuf_addrb  <= 0;
        o_row_tbuf_go     <= 0;
        r_row_tbuf_bank   <= 0;
        r_row_tbuf_addra  <= 0;
        r_row_tbuf_addra0 <= 0;
        r_row_tbuf_dina   <= 0;
        r_row_tbuf1_wea   <= 0;
        r_row_tbuf2_wea   <= 0;
        //cmd_go is set
        //i_frame_start is set, start of new frame
        if (r_cmd_go_shift_reg[2] &&
            r_start_shift_reg[2:1] == 2'b01) begin
            r_state <= ST_WRITE_ROW_LOOP;
        end
    end

    //----------------------------------------------

    ST_WAIT_PHY_INIT_DONE: begin // 01
        if (i_app_phy_init_done) begin
            if (r_count == 1023) begin
                r_count <= 0;
                r_state <= ST_IDLE;
            end else begin
                r_count <= r_count + 1;
            end
        end
    end

    //----------------------------------------------

    ST_WRITE_ROW_LOOP: begin // 02
        o_app_en         <= 0;
        r_app_en_count   <= 0;
        r_app_en_addr    <= 0;
        o_row_rbuf_addrb <= 0; //-1
        r_app_data_count <= 0;
        o_app_wdf_wren   <= 0;
        o_app_wdf_end    <= 0;
        r_state_clks     <= 0;
        o_app_cmd        <= CMD_RD;
        o_wdata          <= r_app_row_num;
        if (r_count == 7) begin
            r_count <= 0;
            r_state <= ST_WRITE_ROW_TO_DDR3;
        end else begin   
            r_count <= r_count + 1;
        end
    end

    ST_WRITE_ROW_TO_DDR3: begin // 03
        r_state_clks    <= r_state_clks + 1;
        o_app_cmd       <= CMD_WR;

        //application interface..
        if (r_app_en_count == ROW_SIZE) begin
            if (i_app_rdy) begin
                o_app_en <= 0;
            end
        end else begin
            if (i_app_rdy) begin
                o_app_en <= ~o_app_en;
                if (o_app_en) begin
                    r_app_en_count <= r_app_en_count + 1;
                end
            end
        end

        //in case of code error, don't just stay stuck in this state
        if (r_state_clks == 600) begin
            r_count     <= 0;
            r_state     <= ST_WRITE_NEXT_ROW;
        end else
        if (r_app_data_count == ROW_SIZE) begin
            o_app_wdf_wren <= 0;
            o_app_wdf_end  <= 0;
            r_count        <= 0;
            r_state        <= ST_WRITE_NEXT_ROW;
        end else
        if (r_app_en_count) begin
            if (r_app_data_count != r_app_en_count) begin
                if (i_app_wdf_rdy) begin
                    o_app_wdf_wren <= 1;
                    o_row_rbuf_addrb <= o_row_rbuf_addrb + 1;
                    if (o_app_wdf_wren) begin
                        o_wdata <= o_wdata + 1;
                        o_app_wdf_end <= ~o_app_wdf_end;
                        if (o_app_wdf_end) begin
                            r_app_data_count <= r_app_data_count + 1;
                            if (r_app_data_count == ROW_SIZE - 1) begin
                                o_app_wdf_wren <= 0;
                            end
                        end
                    end
                end
            end
        end
    end

    ST_WRITE_NEXT_ROW: begin // 04
        o_app_en         <= 0;
        r_app_en_count   <= 0;
        r_app_en_addr    <= 0;
        r_app_data_count <= 0;
        o_app_wdf_wren   <= 0;
        o_app_wdf_end    <= 0;
        o_row_rbuf_addrb <= 0;
        r_addr_state     <= 0;
        r_data_state     <= 0;
        r_state_clks     <= 0;
        r_count          <= 0;
        //hold here until i_rbuf_bank toggles, there's another
        //row_rbuf memory block available
        if (r_bank_shift_reg[2]  != r_bank_shift_reg[1]) begin
            if (r_app_row_num    == r_frame_row_count-1) begin
                r_app_row_num    <= 0;
                r_row_tbuf_bank  <= 0;
                r_row_tbuf_count <= 0;
                r_state <= ST_READ_ROW_LOOP;
            end else begin
                r_app_row_num <= r_app_row_num + 1;
                r_state <= ST_WRITE_ROW_LOOP;
            end
        end
    end

    //----------------------------------------------

    ST_READ_ROW_LOOP: begin // 05
        o_cmd_done        <= 1;
        o_app_en          <= 0;
        r_app_en_count    <= 0;  //-1
        r_app_en_addr     <= 0;
        r_app_data_count  <= 0;
        o_app_wdf_wren    <= 0;
        o_app_wdf_end     <= 0;
        r_state_clks      <= 0;
        o_wdata           <= r_app_row_num;
        r_row_tbuf_addra  <= 0;
        r_row_tbuf_addra0 <= 0;
        r_row_tbuf_dina   <= 0;
        r_row_tbuf1_wea   <= 0;
        r_row_tbuf2_wea   <= 0;
        r_state_clks      <= 0;
        o_app_cmd         <= CMD_RD;

        if (r_count == 7) begin
            r_count <= 0;
            r_state <= ST_READ_ROW;
        end else begin   
            r_count <= r_count + 1;
        end
    end

    ST_READ_ROW: begin // 06
        o_app_cmd      <= CMD_RD;
        r_state_clks    <= r_state_clks + 1;

        //application interface..
        if (r_app_en_count == ROW_SIZE) begin
            if (i_app_rdy) begin
                o_app_en <= 0;
            end
        end else begin
            if (i_app_rdy) begin
                o_app_en <= ~o_app_en;
                if (o_app_en) begin
                    r_app_en_count <= r_app_en_count + 1;
                end
            end
        end

        if (r_count == 100) begin
            r_count <= 0;
            r_state <= ST_READ_NEXT_ROW;
        end else begin
            if (i_app_rd_data_valid) begin
                r_row_tbuf_addra0 <= r_row_tbuf_addra0 + 1;
                r_row_tbuf_addra  <= r_row_tbuf_addra0;
                r_row_tbuf_dina   <= i_app_rd_data;
                r_row_tbuf1_wea   <= ~r_app_row_num[0];
                r_row_tbuf2_wea   <=  r_app_row_num[0];
                r_count <= 0;
                o_wdata <= o_wdata + 1;
            end else begin
                r_count <= r_count + 1;
            end
        end
    end

    ST_READ_NEXT_ROW: begin // 07
        r_state_clks   <= 0;

        r_row_tbuf_addra0 <= 0;
        r_row_tbuf_addra  <= 0;
        r_row_tbuf_dina   <= 0;
        r_row_tbuf1_wea   <= 0;
        r_row_tbuf2_wea   <= 0;
        if (r_count == 20) begin

            //*************************************************************
            //r_row_tbuf_count == 0 - just starting out, read row0 
            //                        into row_tbuf1_mem
            //r_row_tbuf_count == 1 - just starting out, read row1 
            //                        into row_tbuf2_mem and
            //                        toggle the row_tbuf_bank
            //r_row_tbuf_count == 2   on going, read next even row
            //                        into row_tbuf1_mem
            //r_row_tbuf_count == 3   on going, read next odd row
            //                        into row_tbuf2_mem
            //hold until hsync goes to 0, then toggle row_tbuf_bank bit
            //and back up r_row_tbuf_count to 2 in order to collect 
            //2 more rows ahead
            //*************************************************************

            if (r_row_tbuf_count == 0) begin
                r_app_row_num    <= r_app_row_num + 1;
                r_row_tbuf_count <= r_row_tbuf_count + 1;
                r_count          <= 0;
                r_state <= ST_READ_ROW_LOOP;
            end else
            if (r_row_tbuf_count == 1) begin
                //tell tbuf_output routine that it can start outputting
                o_row_tbuf_go    <= 1;
                r_row_tbuf_bank  <= ~r_row_tbuf_bank;
                r_app_row_num    <= r_app_row_num + 1;
                r_row_tbuf_count <= r_row_tbuf_count + 1;
                r_count          <= 0;
                r_state <= ST_READ_ROW_LOOP;
            end else
            if (r_row_tbuf_count == 2) begin
                r_app_row_num    <= r_app_row_num + 1;
                r_row_tbuf_count <= r_row_tbuf_count + 1;
                r_count          <= 0;
                r_state <= ST_READ_ROW_LOOP;
            end else begin  //r_row_tbuf_count == 3
                if (o_row_tbuf_go == 0 && r_mclk_output_done_sr[2]) begin
                    r_state <= ST_WAIT_mclk_OUTPUT_DONE;
                end else
                if (r_hsync_shift_reg[2:1] == 2'b10) begin
                    o_row_tbuf_go <= 0;
                    if (r_app_row_num >= r_frame_row_count) begin
                        r_app_row_num <= 0;
                        r_state <= ST_WAIT_mclk_OUTPUT_DONE;
                    end else begin
                        r_row_tbuf_count <= 2;
                        r_app_row_num    <= r_app_row_num + 1;
                        r_count          <= 0;
                        r_state <= ST_READ_ROW_LOOP;
                    end
                end
            end
        end else begin
            r_count <= r_count + 1;
        end
    end
    ST_WAIT_mclk_OUTPUT_DONE: begin // 07
        if (r_mclk_output_done_sr[2]) begin
            o_row_tbuf_go <= 0;
            r_app_row_num <= 0;
            r_state <= ST_IDLE;
        end
    end

    default: begin //
        r_state <= ST_IDLE;
    end
    endcase
end



blk_mem #                        
(                                
  .DATA_WIDTH                    (256),
  .ADDRESS_WIDTH                 (10) 
)                                
u_ate_row_tbuf1_mem                 
(                                
    .clka                        (ui_clk160),
    .addra                       ({r_row_tbuf_bank,r_row_tbuf_addra}),
    .dina                        (r_row_tbuf_dina),
    .wea                         (r_row_tbuf1_wea),

    .clkb                        (~ui_clk80),
    .addrb                       ({~r_row_tbuf_bank,i_row_tbuf_addrb}),
    .doutb                       (o_row_tbuf1_doutb)
);                               


blk_mem #                        
(                                
  .DATA_WIDTH                    (256),
  .ADDRESS_WIDTH                 (10) 
)                                
u_ate_row_tbuf2_mem                 
(                                
    .clka                        (ui_clk160),
    .addra                       ({r_row_tbuf_bank,r_row_tbuf_addra}),
    .dina                        (r_row_tbuf_dina),
    .wea                         (r_row_tbuf2_wea),

    .clkb                        (~ui_clk80),
    .addrb                       ({~r_row_tbuf_bank,i_row_tbuf_addrb}),
    .doutb                       (o_row_tbuf2_doutb)
);                               


endmodule





