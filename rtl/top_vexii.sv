`timescale 1 ns / 1 ps

module top_vexii (
    input clk30,
    input clk60,
    input reset
);

    localparam SIZE = 454125;
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
        .fifo_full
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
