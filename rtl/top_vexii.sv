`timescale 1 ns / 1 ps

module top_vexii (
    input clk30,
    input clk60,
    input reset

);

    wire        DDRAM_CLK;
    wire        DDRAM_BUSY;
    wire [ 7:0] DDRAM_BURSTCNT;
    wire [28:0] DDRAM_ADDR;
    wire [63:0] DDRAM_DOUT;
    wire        DDRAM_DOUT_READY;
    wire        DDRAM_RD;
    wire [63:0] DDRAM_DIN;
    wire [ 7:0] DDRAM_BE;
    wire        DDRAM_WE;

    bit  [63:0] ddram            [500000/8]  /*verilator public_flat_rd*/;

    always_ff @(posedge DDRAM_CLK) begin
        if (DDRAM_WE) begin
            ddram[DDRAM_ADDR[15:0]] <= DDRAM_DIN;
            //$display("Write at %x %x",DDRAM_ADDR, DDRAM_DIN);
        end
    end

    localparam SIZE = 494980;
    bit [31:0] mpeg_video_rom[SIZE];
    initial $readmemh("fmv.mem", mpeg_video_rom);

    bit [15:0] data_word;
    bit data_strobe;
    wire fifo_full;

    mpeg_video video (
        .clk30,
        .clk60,
        .reset,
        .dsp_enable(1'b1),
        .data_word,
        .data_strobe,
        .fifo_full,

        .DDRAM_CLK,
        .DDRAM_BUSY,
        .DDRAM_BURSTCNT,
        .DDRAM_ADDR,
        .DDRAM_DOUT,
        .DDRAM_DOUT_READY,
        .DDRAM_RD,
        .DDRAM_DIN,
        .DDRAM_BE,
        .DDRAM_WE
    );

    bit provide_lower_word = 0;
    bit [18:0] mpeg_stream_address = 0;

    always_ff @(posedge clk30) begin
        data_strobe <= 0;

        if (!fifo_full && !reset && mpeg_stream_address <= (SIZE + 10)) begin
            data_strobe <= 1;
            provide_lower_word <= !provide_lower_word;
            if (provide_lower_word) mpeg_stream_address <= mpeg_stream_address + 1;
            data_word <= provide_lower_word ? mpeg_video_rom[mpeg_stream_address][15:0] : mpeg_video_rom[mpeg_stream_address][31:16];
        end
    end

endmodule
