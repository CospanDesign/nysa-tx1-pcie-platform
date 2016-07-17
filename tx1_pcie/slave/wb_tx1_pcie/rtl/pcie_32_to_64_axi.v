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

module pcie_32_to_64_axi #(
  parameter FIFO_DEPTH    = 7
)(
  input                     clk,
  input                     rst,

  //Input
  input         [3:0]       i_32_keep,
  input         [31:0]      i_32_data,
  input                     i_32_valid,
  input                     i_32_last,
  output                    o_32_ready,

  //Output
  output        [63:0]      o_64_data,
  output        [7:0]       o_64_keep,
  output  reg               o_64_valid,
  output  reg               o_64_last,
  input                     i_64_ready

);
//local parameters
localparam      IDLE          = 0;
localparam      WRITE_BOT     = 1;
localparam      WRITE_TOP     = 2;
localparam      WRITE_RELEASE = 3;

localparam      READY         = 1;
localparam      RELEASE       = 2;

//registes/wires
reg     [3:0]             istate;
reg     [23:0]            icount;
reg     [23:0]            ocount;

wire    [23:0]            ingress_size;
wire    [1:0]             ingress_rdy;
reg     [1:0]             ingress_act;
reg     [71:0]            ingress_data;
reg                       ingress_stb;

reg     [3:0]             ostate;
wire    [23:0]            egress_size;
wire                      egress_rdy;
reg                       egress_act;
wire                      egress_stb;
wire    [71:0]            egress_data;

//submodules
ppfifo #(
  .DATA_WIDTH                 (72                         ),
  .ADDRESS_WIDTH              (FIFO_DEPTH                 )
) ppf (
  .reset                      (rst                        ),
  //Write Side
  .write_clock                (clk                        ),
  .write_ready                (ingress_rdy                ),
  .write_activate             (ingress_act                ),
  .write_fifo_size            (ingress_size               ),
  .write_strobe               (ingress_stb                ),
  .write_data                 (ingress_data               ),

  //Read Side
  .read_clock                 (clk                        ),
  .read_ready                 (egress_rdy                 ),
  .read_activate              (egress_act                 ),
  .read_count                 (egress_size                ),
  .read_strobe                (egress_stb                 ),
  .read_data                  (egress_data                ),
  .inactive                   (egress_idle                )
);

//asynchronous logic

//This is a little strange to just connect the output clock with the input clock but if this is done
//Users do not need to figure out how to hook up the clocks
assign  o_32_ready      = (ingress_act > 0) && (icount < ingress_size);
assign  o_64_data       = {egress_data[67:36], egress_data[31: 0]};
assign  o_64_keep       = {egress_data[71:68], egress_data[35:32]};
assign  egress_stb      = (i_64_ready && o_64_valid && !o_64_last);

//synchronous logic

//32-bit incomming
always @ (posedge clk) begin
  ingress_stb          <=  0;

  if (rst) begin
    icount             <=  0;
    ingress_act        <=  0;
    ingress_data       <=  0;

    istate               <=  IDLE;
  end
  else begin
    case (istate)
      IDLE: begin
        ingress_act    <=  0;
        if ((ingress_rdy > 0) && (ingress_act == 0)) begin
          icount           <=  0;
          if (ingress_rdy[0]) begin
            ingress_act[0] <=  1;
          end
          else begin
            ingress_act[1] <=  1;
          end
          istate             <=  READY;
        end
      end
      WRITE_BOT: begin
        if (icount < ingress_size) begin
          if (i_32_valid && o_32_ready) begin
            ingress_data[35:0]    <=  {i_32_keep, i_32_data};
            ingress_data[71:36]   <=  36'h0;
            istate                <=  WRITE_TOP;
          end
        end
        //Conditions to release the FIFO or stop a transaction
        else begin
          istate              <=  WRITE_RELEASE;
        end
        if (i_32_last) begin
          istate              <=  WRITE_RELEASE;
          ingress_stb         <=  1;
        end
      end
      WRITE_TOP: begin
        if (icount < ingress_size) begin
          if (i_32_valid && o_32_ready) begin
            ingress_stb           <=  1;
            ingress_data[71:36]   <=  {i_32_keep, i_32_data};
            icount                <=  icount + 1;
            istate                <=  WRITE_BOT;
          end
        end
        //Conditions to release the FIFO or stop a transaction
        else begin
          istate              <=  WRITE_RELEASE;
        end
        if (i_32_last) begin
          istate              <=  WRITE_RELEASE;
          //ingress_stb         <=  1;
        end
      end
      WRITE_RELEASE: begin
        ingress_act           <=  0;
        istate                <=  IDLE;
      end
      default: begin
      end
    endcase
  end
end

//64-bit outgoing
always @ (posedge clk) begin
  //egress_stb            <=  0;
  o_64_valid            <=  0;
  o_64_last             <=  0;

  if (rst) begin
    ostate              <=  IDLE;
    egress_act          <=  0;
    ocount              <=  0;
  end
  else begin
    case (ostate)
      IDLE: begin
        egress_act      <=  0;
        if (egress_rdy && !egress_act) begin
          ocount        <=  0;
          egress_act    <=  1;
          ostate        <=  READY;
        end
      end
      READY: begin
        //Wait for the AXI Stream output to be ready
        o_64_valid      <=  1;
        if (i_64_ready && o_64_valid) begin
          //Axi Bus is ready, PPFIFO is ready, send data
          if ((ocount + 2) < egress_size) begin
            ocount      <=  ocount + 1;
          end
          else begin
            //No more data within the PPFIFO
            o_64_last     <=  1;
            ostate        <=  RELEASE;
          end
        end
      end
      RELEASE: begin
        egress_act        <=  0;
        ostate            <=  IDLE;
      end
      default: begin
      end
    endcase
  end
end

endmodule
