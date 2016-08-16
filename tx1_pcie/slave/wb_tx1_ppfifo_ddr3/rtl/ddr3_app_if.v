/*
Distributed under the MIT license.
Copyright (c) 2016 Dave McCoy (dave.mccoy@cospandesign.com)

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

module ddr3_app_if #(
  parameter                           MEM_ADDR_DEPTH  = 28
)(
  input                               rst,
  input                               clk,

  output                              idle,

  input                               i_init_calib_complete,
  input                               i_app_rdy,
  input                               i_app_wdf_rdy,
  output reg                          o_app_en,
  output reg  [2:0]                   o_app_cmd,
  output      [MEM_ADDR_DEPTH - 1:0]  o_app_addr,
  output reg                          o_app_wdf_wren,
  output reg  [3:0]                   o_app_wdf_mask,
  output reg                          o_app_wdf_end,
  output      [31:0]                  o_app_wdf_data,
  input                               i_app_rd_data_valid,
  input                               i_app_rd_data_end,
  input       [31:0]                  i_app_rd_data,

  //To DDR3
  input                               i_ingress_en,
  input       [MEM_ADDR_DEPTH - 3:0]  i_ingress_dword_addr,

  input                               i_ingress_rdy,
  output  reg                         o_ingress_act,
  input       [23:0]                  i_ingress_size,
  input       [31:0]                  i_ingress_data,
  output  reg                         o_ingress_stb,

  //From DDR3
  input                               i_egress_en,
  input       [MEM_ADDR_DEPTH - 3:0]  i_egress_dword_addr,

  input       [1:0]                   i_egress_rdy,
  output  reg [1:0]                   o_egress_act,
  input       [23:0]                  i_egress_size,
  output      [31:0]                  o_egress_data,
  output                              o_egress_stb
);
//local parameters
localparam          IDLE              = 0;
localparam          PREP_WR           = 1;
localparam          PREP_WR_DATA1     = 2;
localparam          PREP_WR_DATA2     = 3;
localparam          WR_TO_RAM_BOT     = 4;
localparam          WR_TO_RAM_TOP     = 5;
localparam          SEND_WR_CMD       = 6;
localparam          PREP_READ         = 7;
localparam          READ_FROM_RAM     = 8;



localparam          CMD_WR            = 3'b000;
localparam          CMD_RD            = 3'b001;


//registes/wires

(* keep = "true" *) reg [3:0]                   state;
reg [MEM_ADDR_DEPTH - 3: 0] r_app_addr;

wire [23:0]                 w_app_egr_size;
wire [23:0]                 w_data_egr_size;


reg [31:0]                  r_data_req_count;
reg [31:0]                  r_data_count;

//submodules
//asynchronous logic
assign  o_app_addr      = {r_app_addr, 3'b0};
//assign  w_app_egr_size  = {1'b0, i_egress_size[23:1]};
assign  w_app_egr_size  = i_egress_size[23:0];

assign  o_egress_stb    = i_app_rd_data_valid;
assign  o_egress_data   = i_app_rd_data;
assign  o_app_wdf_data  = i_ingress_data;
assign  idle            = (state == IDLE);
//synchronous logic

always @ (posedge clk) begin
  //Strobes
  o_ingress_stb         <=  0;
  o_app_wdf_end         <=  0;
  o_app_wdf_mask        <=  0;

  if (rst) begin
    o_app_cmd           <=  0;
    r_app_addr          <=  0;
    o_app_en            <=  0;
    o_app_wdf_wren      <=  0;
    r_data_req_count    <=  0;
    r_data_count        <=  0;
//    o_app_wdf_data      <=  0;
    state               <=  IDLE;
  end
  else begin
    //XXX: If egress clear, the user reset the output PPFIFO need to release it immediately and go to IDLE
    case (state)
      IDLE: begin
        o_app_wdf_wren  <=  0;
        o_ingress_act   <=  0;
        o_egress_act    <=  0;
        r_data_count    <=  0;

        o_app_cmd       <=  0;
        r_app_addr      <=  0;

        if (i_ingress_en) begin
          r_app_addr    <=  i_ingress_dword_addr;
          o_app_cmd     <=  CMD_WR;
          state         <= PREP_WR;
        end
        else if (i_egress_en) begin
          r_app_addr    <=  i_egress_dword_addr;
          o_app_cmd     <=  CMD_RD;
          state         <= PREP_READ;
        end
      end
      PREP_WR: begin
        //Get the PPFIFO
        if (i_ingress_en || i_ingress_rdy) begin
          //There is still some data to send
          r_data_count      <=  0;
          if (i_ingress_rdy && !o_ingress_act) begin
            o_ingress_act   <=  1;
            state           <=  PREP_WR_DATA1;
          end
        end
        else begin
          state             <=  IDLE;
        end
      end
      PREP_WR_DATA1: begin
        /*
        Since we are registering the next value, we need an extra step here to
          Set things up
        */
//        o_app_wdf_data      <=  i_ingress_data;
        o_ingress_stb       <=  1;
//        state               <=  PREP_WR_DATA2;
//      end
//      PREP_WR_DATA2: begin
        o_app_wdf_wren      <=  1;
        state               <=  WR_TO_RAM_BOT;
      end
      WR_TO_RAM_BOT: begin
        //Write the data to the DDR3 write FIFO
        if(r_data_count < i_ingress_size) begin
          o_app_wdf_wren      <=  1;
          if (o_app_wdf_wren && i_app_wdf_rdy) begin
            r_data_count      <=  r_data_count + 1;
            o_ingress_stb     <=  1;
//            o_app_wdf_data    <=  i_ingress_data;
            o_app_wdf_end     <=  1;
            o_app_en          <=  1;
            if (r_data_count + 1 >= i_ingress_size) begin
              o_app_wdf_mask  <=  4'hF;
            end
            state             <=  WR_TO_RAM_TOP;
          end
        end
        else begin
          //We're Done
          o_ingress_act       <=  0;
          state               <=  PREP_WR;
        end
      end
      WR_TO_RAM_TOP: begin
        //Second half of the 64-bit transaction
        o_app_wdf_end         <=  1;
        /*
        There is a chance that we need to send masked data, the data is send in
        8 Bytes but if we only want to send 4 bytes we need to mask the
        */
        if (r_data_count > i_ingress_size) begin
          o_app_wdf_mask      <=  4'hF;
        end

        /* Possible Scenarios
          - WR FIFO: [+] | CMD FIFO [+]: Just pass through and head back to
                                            WRIT_TO_RAM_BOT
          - WR FIFO: [+] | CMD FIFO [-]: Write the data and go to
                                            SEND_WR_CMD
          - WR FIFO: [-] | CMD FIFO [+]: Write the command and de-assert
                                            o_app_end
          - WR FIFO: [-] | CMD FIFO [-]: Wait for one of the following
                                            conditions to occur
        */
        if (o_app_wdf_wren && i_app_wdf_rdy) begin
          /*
            WR has been accepted,
              - If CMD is accepted don't de-assert the o_app_wdf_wren, we can
                keep it high! (Only do this if we have more data to send)
          */
          o_app_wdf_end       <=  0;
          r_data_count        <=  r_data_count + 1;


          if (i_app_rdy || !o_app_en) begin
            //App Data is sending or has already been sent
            if ((r_data_count + 1) >= i_ingress_size) begin
              o_app_wdf_wren  <=  0;
            end
            else begin
              o_app_wdf_wren  <=  1;
            end
            state             <=  WR_TO_RAM_BOT;
            if ((r_data_count + 1) < i_ingress_size) begin
              o_ingress_stb     <=  1;
//            o_app_wdf_data    <=  i_ingress_data;
            end
          end
          else begin
            state             <=  SEND_WR_CMD;
            o_app_wdf_wren    <=  0;
          end
        end
        if (i_app_rdy && o_app_en) begin
          o_app_en            <=  0;
          r_app_addr          <=  r_app_addr + 1;
        end
      end
      SEND_WR_CMD: begin
        if (i_app_rdy && o_app_en) begin
          /*
            Write data was accepted, now we just need to wait for the command
            to be accepted as well
          */
          o_app_en              <=  0;
          r_app_addr            <=  r_app_addr + 1;
          if ((r_data_count + 1) >= i_ingress_size) begin
            state               <=  WR_TO_RAM_BOT;
          end
          else begin
            //o_ingress_stb       <=  1;
            //o_app_wdf_wren      <=  1;
            state               <=  PREP_WR_DATA1;
          end
//          o_app_wdf_data        <=  i_ingress_data;
        end
      end
      PREP_READ: begin
        if (i_egress_en) begin
          r_data_req_count      <=  0;
          r_data_count          <=  0;
          if ((i_egress_rdy > 0) && (o_egress_act == 0)) begin
            if (i_egress_rdy[0]) begin
              o_egress_act[0]   <=  1;
            end
            else begin
              o_egress_act[1]   <=  1;
            end
            o_app_en            <=  1;
            state               <=  READ_FROM_RAM;
          end
        end
        else begin
          state                 <=  IDLE;
        end
      end
      READ_FROM_RAM: begin
        if (r_data_req_count < w_app_egr_size) begin
          /*Every one of these counts as two pieces of data*/
          o_app_en              <=  1;
          if (o_app_en && i_app_rdy) begin
            r_data_req_count    <=  r_data_req_count + 2;
            r_app_addr          <=  r_app_addr + 1;
            if (r_data_req_count + 2 >= w_app_egr_size) begin
              o_app_en          <=  0;
            end
          end
        end
        //Data is coming in from the DDR3
        if (i_app_rd_data_valid) begin
          r_data_count          <=  r_data_count + 1;
        end
        //Done
        if (r_data_count >= i_egress_size) begin
          o_app_en              <=  0;
          o_egress_act          <=  0;
          state                 <= PREP_READ;
        end
      end
      default: begin
        state                     <=  IDLE;
      end
    endcase
  end
end

endmodule
