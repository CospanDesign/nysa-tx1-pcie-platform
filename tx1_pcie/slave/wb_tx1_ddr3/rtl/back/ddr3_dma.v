

module ddr3_dma(
    input                                 clk,
    input                                 rst,

    //Write Side
    input                                 write_enable,
    input       [63:0]                    write_addr,
    input                                 write_addr_inc,
    input                                 write_addr_dec,
    output  reg                           write_finished,
    input       [23:0]                    write_count,
    input                                 write_flush,

    output      [1:0]                     write_ready,
    input       [1:0]                     write_activate,
    output      [23:0]                    write_size,
    input                                 write_strobe,
    input       [31:0]                    write_data,

    //Read Side
    input                                 read_enable,
    input       [63:0]                    read_addr,
    input                                 read_addr_inc,
    input                                 read_addr_dec,
    output                                read_busy,
    output                                read_error,
    input       [23:0]                    read_count,
    input                                 read_flush,

    output                                read_ready,
    input                                 read_activate,
    output      [23:0]                    read_size,
    output      [31:0]                    read_data,
    input                                 read_strobe,

    //Local Registers/Wires
    output                                cmd_en,
    output        [2:0]                   cmd_instr,
    output        [5:0]                   cmd_bl,
    output        [29:0]                  cmd_byte_addr,
    input                                 cmd_empty,
    input                                 cmd_full,

    output                                wr_en,
    output        [3:0]                   wr_mask,
    output        [31:0]                  wr_data,
    input                                 wr_full,
    input                                 wr_empty,
    input         [6:0]                   wr_count,
    input                                 wr_underrun,
    input                                 wr_error,

    output                                rd_en,
    input         [31:0]                  rd_data,
    input                                 rd_full,
    input                                 rd_empty,
    input         [6:0]                   rd_count,
    input                                 rd_overflow,
    input                                 rd_error
);

//Local Parameters

//Registers/Wires
reg [23:0]  local_write_size;
reg [23:0]  local_write_count;

reg         prev_edge_write_enable;
wire        posedge_write_enable;
wire [27:0] cmd_word_addr;

//Sub Modules
//Submodules
ddr3_controller dc(

  .clk                (clk                   ),
  .rst                (rst                   ),

  .write_en           (write_enable          ),
  .write_address      (write_addr[27:0]      ),

  .read_en            (read_enable           ),
  .read_address       (read_addr[27:0]       ),

  .if_write_strobe    (write_strobe          ),
  .if_write_data      (write_data            ),
  .if_write_ready     (write_ready           ),
  .if_write_activate  (write_activate        ),
  .if_write_fifo_size (write_size            ),
  //.if_starved         (if_starved            ),

  .of_read_strobe     (read_strobe           ),
  .of_read_ready      (read_ready            ),
  .of_read_activate   (read_activate         ),
  .of_read_size       (read_size             ),
  .of_read_data       (read_data             ),

  .cmd_en             (cmd_en                ),
  .cmd_instr          (cmd_instr             ),
  .cmd_bl             (cmd_bl                ),
  .cmd_word_addr      (cmd_word_addr         ),
  .cmd_empty          (cmd_empty             ),
  .cmd_full           (cmd_full              ),

  .wr_en              (wr_en                 ),
  .wr_mask            (wr_mask               ),
  .wr_data            (wr_data               ),
  .wr_full            (wr_full               ),
  .wr_empty           (wr_empty              ),
  .wr_count           (wr_count              ),
  .wr_underrun        (wr_underrun           ),
  .wr_error           (wr_error              ),

  .rd_en              (rd_en                 ),
  .rd_data            (rd_data               ),
  .rd_full            (rd_full               ),
  .rd_empty           (rd_empty              ),
  .rd_count           (rd_count              ),
  .rd_overflow        (rd_overflow           ),
  .rd_error           (rd_error              )

);



//Asynchroous Logic

assign      read_busy            = read_enable;
assign      read_error           = 0;
assign      posedge_write_enable = !prev_edge_write_enable && write_enable;
assign      cmd_byte_addr        = {cmd_word_addr, 2'b0};

//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin
    //local_write_size        <= 0;
    local_write_count       <= 0;
    write_finished          <= 0;
    prev_edge_write_enable  <= 0;
  end
  else begin
    if (write_count > 0) begin
      if (write_strobe) begin
        local_write_count   <= local_write_count + 1;
      end
      if (local_write_count >= write_count) begin
        write_finished      <=  1;
      end
    end
    else begin
      write_finished        <= 0;
      local_write_count     <= 0;
    end

    prev_edge_write_enable  <=  write_enable;
  end
end

endmodule
