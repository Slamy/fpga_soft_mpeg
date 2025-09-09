`timescale 1 ns / 1 ps
`include "util.svh"
`include "bus.svh"

module top_vexii (
    input clk30,
    input clk60,
    input reset

);

    // DDR3 simulation
    bit [63:0] ddram[500000/8]  /*verilator public_flat_rd*/;

    int ddr_latencycnt;
    bit [7:0] ddr_words_to_prove;
    bit [28:0] ddr_addr;

    wire DDRAM_CLK;
    bit DDRAM_BUSY;  // every read and write request is only accepted in a cycle where busy is low
    wire [7:0] DDRAM_BURSTCNT;  // amount of words to be written/read. Maximum is 128
    wire [28:0] DDRAM_ADDR;         // starting address for read/write. In case of burst; the addresses will internally count up
    bit [63:0] DDRAM_DOUT;  // data coming from (burst) read
    bit         DDRAM_DOUT_READY;   // high for 1 clock cycle for every 64 bit dataword requested via (burst) read request
    wire DDRAM_RD;  // request read at DDRAM_ADDR and DDRAM_BURSTCNT length
    wire [63:0] DDRAM_DIN;  // data word to be written
    wire  [7:0] DDRAM_BE;           // byte enable for each of the 8 bytes in DDRAM_DIN; only used for writing. (1=write; 0=ignore)
    wire DDRAM_WE;  // request write at DDRAM_ADDR with DDRAM_DIN data and DDRAM_BE mask

    always_ff @(posedge DDRAM_CLK) begin
        DDRAM_DOUT_READY <= 0;

        if (DDRAM_WE && !DDRAM_BUSY) begin
            ddram[DDRAM_ADDR[15:0]] <= DDRAM_DIN;
            //$display("Write at %x %x",DDRAM_ADDR, DDRAM_DIN);
        end

        if (DDRAM_RD && !DDRAM_BUSY) begin
            ddr_latencycnt <= 3;
            ddr_words_to_prove <= DDRAM_BURSTCNT;
            ddr_addr <= DDRAM_ADDR;
            DDRAM_BUSY <= 1;
        end

        if (DDRAM_BUSY) begin
            if (ddr_latencycnt > 0) ddr_latencycnt <= ddr_latencycnt - 1;
            else begin
                DDRAM_DOUT <= ddram[ddr_addr[15:0]];
                ddr_addr <= ddr_addr + 1;
                DDRAM_DOUT_READY <= 1;
                ddr_words_to_prove <= ddr_words_to_prove - 1;
                if (ddr_words_to_prove == 1) DDRAM_BUSY <= 0;
            end

        end
    end

    localparam SIZE = 494980;
    bit [31:0] mpeg_video_rom[SIZE];
    initial $readmemh("fmv.mem", mpeg_video_rom);

    bit [15:0] data_word;
    bit data_strobe;
    wire fifo_full;

    ddr_if ddr_host ();

    assign DDRAM_CLK = clk60;
    assign DDRAM_ADDR = ddr_host.addr;
    assign DDRAM_BE = ddr_host.byteenable;
    assign DDRAM_WE = ddr_host.write;
    assign DDRAM_RD = ddr_host.read;
    assign DDRAM_DIN = ddr_host.wdata;
    assign DDRAM_BURSTCNT = ddr_host.burstcnt;
    assign ddr_host.rdata = DDRAM_DOUT;
    assign ddr_host.rdata_ready = DDRAM_DOUT_READY;
    assign ddr_host.busy = DDRAM_BUSY;


    mpeg_video video (
        .clk30,
        .clk60,
        .reset,
        .dsp_enable(1'b1),
        .data_word,
        .data_strobe,
        .fifo_full,
        .ddrif(ddr_host),
        .hsync(),
        .vsync(),
        .hblank(),
        .vblank(),
        .vidout()
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
