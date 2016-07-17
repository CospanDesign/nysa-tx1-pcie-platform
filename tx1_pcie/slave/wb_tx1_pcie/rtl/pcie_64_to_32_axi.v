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

module pcie_64_to_32_axi #(
  parameter                 ADDRESS_WIDTH = 6
)(
  input                     clk,
  input                     rst,

  //Input
  input         [63:0]      i_64_data,
  input                     i_64_valid,
  input                     i_64_last,
  output  reg               o_64_ready,

  //Output
  output        [31:0]      o_32_data,
  output  reg               o_32_valid,
  output  reg               o_32_last,
  input                     i_32_ready

);
//local parameters
localparam      IDLE          = 4'h0;
localparam      READ          = 4'h1;
localparam      PREPARE_WRITE = 4'h2;
localparam      WRITE_TOP     = 4'h3;
localparam      WRITE_BOT     = 4'h4;
localparam      FINISHED      = 4'h5;
//registes/wires

reg   [3:0]                   state;
reg   [ADDRESS_WIDTH:     0]  r_addr_in;
reg   [ADDRESS_WIDTH:     0]  r_addr_out;

wire  [ADDRESS_WIDTH - 1: 0]  w_addr_in;
wire  [ADDRESS_WIDTH - 1: 0]  w_addr_out;

wire  [63:0]                  w_64_data;
reg   [63:0]                  r_64_data;

//submodules
blk_mem #(
  .DATA_WIDTH       (64                 ),
  .ADDRESS_WIDTH    (ADDRESS_WIDTH      )
) fifo0 (
  //Write
  .clka             (clk                ),
  .wea              (write_enable       ), //This may just be replaced with write activate
  .dina             (i_64_data          ),
  .addra            (w_addr_in          ),
                    
  .clkb             (clk                ),
  .doutb            (w_64_data          ),
  .addrb            (w_addr_out         )
);

assign  o_32_data = (state == WRITE_BOT) ? w_64_data[31:0] : w_64_data[63:32];
//assign  o_32_data = (state == WRITE_BOT) ? w_64_data[63:32] : w_64_data[31:0];

//asynchronous logic
assign  write_enable  = (o_64_ready && i_64_valid);
assign  w_addr_in     = r_addr_in [ADDRESS_WIDTH - 1: 0];
assign  w_addr_out    = r_addr_out[ADDRESS_WIDTH - 1: 0];

//synchronous logic

always @ (posedge clk) begin
  o_64_ready                <=  0;
  o_32_valid                <=  0;
  o_32_last                 <=  0;
  if (rst) begin
    state                   <=  IDLE;

    r_addr_in               <=  0;
    r_addr_out              <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        r_addr_out          <=  0;
        r_addr_in           <=  0;
        if (i_64_valid) begin
          state             <=  READ;
          o_64_ready        <=  1;
        end
      end
      READ: begin
        o_64_ready          <=  1;
        if (i_64_valid) begin
          r_addr_in         <=  r_addr_in + 1;
        end
        else begin
          state             <=  PREPARE_WRITE;
        end
      end
      PREPARE_WRITE: begin
        o_32_valid          <=  1;
        //r_64_data           <=  w_64_data;
        if (i_32_ready) begin
          //r_addr_out        <=  r_addr_out + 1;
          state             <=  WRITE_BOT;
        end
      end
      WRITE_TOP: begin
        o_32_valid          <=  1;
        //if (r_addr_out < r_addr_in) begin
        //  r_addr_out        <=  r_addr_out + 1;
        //end
        state               <=  WRITE_BOT;
      end
      WRITE_BOT: begin
        if (r_addr_out < (r_addr_in - 1)) begin
          o_32_valid        <=  1;
          state             <=  WRITE_TOP;
          //r_64_data         <=  w_64_data;
          r_addr_out        <=  r_addr_out + 1;
        end
        else begin
          state             <=  FINISHED;
        end
        if (r_addr_out == r_addr_in - 1) begin
          o_32_valid        <=  1;
          o_32_last         <=  1;
        end
      end
      FINISHED: begin
        state               <=  IDLE;
      end
      default: begin
        state               <=  IDLE;
      end
    endcase
  end
end



endmodule
