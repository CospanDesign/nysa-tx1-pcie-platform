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
 * Author: dave.mccoy@cospandesign.com
 * Description: PPFIFO -> BRAM and BRM -> PPFIFO
 *  Attaches two PPFIFO to a block RAM.
 *
 *  How to use:
 *
 *  PPFIFO (Read to the BRAM) Interface Attached to read_*
 *  PPFIFO (Write from the BRAM) Interface Attached to write_*
 *
 * Changes:
 */

`define MEM_WAIT  2

module adapter_ppfifo_dpb #(
  parameter                           MEM_DEPTH   = 10,
  parameter                           DATA_WIDTH  = 32
)(
  input                               clk,
  input                               rst,
  input                               i_ppfifo_2_mem_stb,
  input                               i_mem_2_ppfifo_stb,
  output                              o_ing_ppfifo_has_data,
  output                              o_egr_ppfifo_is_ready,
  output                              o_busy,

  //Ping Pong FIFO Interface
  input           [1:0]               i_write_ready,
  output  reg     [1:0]               o_write_activate,
  input           [23:0]              i_write_size,
  output  reg                         o_write_stb,
  output          [DATA_WIDTH - 1:0]  o_write_data,

  input                               i_read_ready,
  output  reg                         o_read_activate,
  input           [23:0]              i_read_size,
  input           [DATA_WIDTH - 1:0]  i_read_data,
  output  reg                         o_read_stb,

  //User Memory Interface
  input                               i_bram_clk,
  input                               i_bram_we,
  input           [MEM_DEPTH  - 1: 0] i_bram_addr,
  input           [DATA_WIDTH - 1: 0] i_bram_din,
  output          [DATA_WIDTH - 1: 0] o_bram_dout
);
//local parameters
localparam        MEM_SIZE    = (2 ** MEM_DEPTH);

//States
localparam        IDLE        = 0;
localparam        WRITE_SETUP = 1;
localparam        WRITE       = 2;
localparam        READ_SETUP  = 3;
localparam        READ        = 4;

//registes/wires
reg   [3:0]                           state;
reg   [23:0]                          count;

reg                                   r_we;
reg   [MEM_DEPTH - 1: 0]              r_addr;
reg   [3:0]                           mem_wait_count;
reg   [23:0]                          prev_mem_addr;


//submodules

//Read/Write Data to a local buffer
dpb #(
  .DATA_WIDTH     (DATA_WIDTH           ),
  .ADDR_WIDTH     (MEM_DEPTH            )

) local_buffer (

  .clka           (i_bram_clk           ),
  .wea            (i_bram_we            ),
  .addra          (i_bram_addr          ),
  .douta          (o_bram_dout          ),
  .dina           (i_bram_din           ),

  .clkb           (clk                  ),
  .web            (r_we                 ),
  .addrb          (r_addr               ),
  .dinb           (i_read_data          ),
  .doutb          (o_write_data         )
);

//asynchronous logic
assign  o_busy                = (state != IDLE);
assign  o_ing_ppfifo_has_data = (i_read_ready);
assign  o_egr_ppfifo_is_ready = (i_write_ready > 0);

//synchronous logic

always @ (posedge clk) begin
  o_read_stb                      <=  0;
  o_write_stb                     <=  0;
  r_we                            <=  0;
  if (rst) begin
    o_write_activate              <=  0;
    o_read_activate               <=  0;
    count                         <=  0;
    r_addr                        <=  0;

    state                         <=  IDLE;
  end
  else begin
    case (state)
      IDLE: begin
        o_read_activate           <=  0;
        o_write_activate          <=  0;
        r_addr                    <=  0;

        count                     <=  0;
        if (i_mem_2_ppfifo_stb) begin
          //Load the memory data into the PPFIFO
          state                   <=  WRITE_SETUP;
        end
        else if (i_ppfifo_2_mem_stb) begin
          state                   <=  READ_SETUP;
        end
      end
      WRITE_SETUP: begin
        if ((i_write_ready > 0) && (o_write_activate == 0)) begin
          if (i_write_ready[0]) begin
            o_write_activate[0]   <=  1;
          end
          else begin
            o_write_activate[1]   <=  1;
          end
          state                   <=  WRITE;
        end
      end
      WRITE: begin
        if (count < i_write_size) begin
          r_addr                  <=  r_addr + 1;
          o_write_stb             <=  1;
          count                   <=  count + 1;
        end
        else begin
          o_write_activate        <=  0;
          state                   <=  IDLE;
        end
      end
      READ_SETUP: begin
        if(i_read_ready) begin
          o_read_activate         <=  1;
          state                   <=  READ;
        end
      end
      READ: begin
        //Memory Interface
        r_we                      <=  1;
        if (r_we) begin
          if (count < i_read_size) begin
            o_read_stb            <=  1;
            count                 <=  count + 1;
          end
          else begin
            //Done Reading
            o_read_activate       <=  0;
            state                 <=  IDLE;
            r_we                  <=  0;
          end
        end
        if (o_read_stb) begin
          //Delay incrementing the address
          r_addr                  <=  r_addr + 1;
        end
      end
      default: begin
        //Shouldn't get here
        state                     <= IDLE;
      end
    endcase
  end
end

endmodule
