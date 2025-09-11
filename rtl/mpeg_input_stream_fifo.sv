`timescale 1 ns / 1 ps

// https://www.intel.com/content/www/us/en/docs/programmable/683082/21-3/mixed-width-dual-port-ram.html
// 4096x16 write and 2048x32 read
// So, this is 8KB of memory
module mpeg_input_stream_fifo (
    input [12:0] waddr,
    input [15:0] wdata,
    input we,
    input clkw,
    input clkr,
    input [11:0] raddr,
    output logic [31:0] q
);

    logic [1:0][15:0] ram[4096];
    always_ff @(posedge clkw) begin
        if (we) ram[waddr[12:1]][waddr[0]] <= wdata;
    end

    always_ff @(posedge clkr) begin
        q <= ram[raddr];
    end
endmodule : mpeg_input_stream_fifo

