`timescale 1 ns / 1 ps

module top_vexii (
    input clk,
    input reset,
    output signed [15:0] audio_left,
    output signed [15:0] audio_right,
    output bit sample_tick
);

    localparam SIZE = 29623;
    bit [31:0] mpeg_audio_rom[SIZE];
    initial $readmemh("fma.mem", mpeg_audio_rom);

    bit [15:0] data_word;
    bit data_strobe;
    wire fifo_full;
    wire playback_active;

    // Assuming 30 MHz clock rate and 44100 Hz sample rate
    localparam TICKS_PER_SAMPLE = 680;
    bit [10:0] sample_tick_cnt = 0;

    always_ff @(posedge clk) begin
        sample_tick_cnt <= sample_tick_cnt + 1;
        sample_tick <= 0;
        if (sample_tick_cnt == TICKS_PER_SAMPLE - 1) begin
            sample_tick_cnt <= 0;
            sample_tick <= 1;
        end
    end

    bit  playback_active_q;
    wire event_decoding_started;
    wire event_frame_decoded;
    wire event_underflow;


    always_ff @(posedge clk) begin
        // MPEG Audio has stopped.
        playback_active_q <= playback_active;
        if (playback_active_q && !playback_active) begin
            $display("Playback has finished!");
            $finish();
        end

        if (event_decoding_started) $display("DSP: Decoding started!");
        if (event_frame_decoded) $display("DSP: Frame decoded!");
        if (event_underflow) $display("DSP: Data underflow!");
    end


    mpeg_audio audio (
        .clk,
        .reset,
        .dsp_enable(1'b1),
        .data_word,
        .data_strobe,
        .fifo_full,
        .audio_left,
        .audio_right,
        .sample_tick44(sample_tick),
        .playback_active,
        .event_decoding_started,
        .event_frame_decoded,
        .event_underflow
    );

    bit provide_lower_word = 0;
    bit [14:0] mpeg_stream_address = 0;

    always_ff @(posedge clk) begin
        data_strobe <= 0;
        if (!fifo_full && !reset && mpeg_stream_address <= (SIZE + 10)) begin
            data_strobe <= 1;
            provide_lower_word <= !provide_lower_word;
            if (provide_lower_word) mpeg_stream_address <= mpeg_stream_address + 1;
            data_word <= provide_lower_word ? mpeg_audio_rom[mpeg_stream_address][15:0] : mpeg_audio_rom[mpeg_stream_address][31:16];
        end
    end

endmodule
