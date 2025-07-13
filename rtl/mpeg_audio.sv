`timescale 1 ns / 1 ps
`include "synth_window.svh"
`include "util.svh"

module mpeg_audio (
    input clk,
    input reset,

    input [15:0] data_word,
    input data_strobe,
    output fifo_full,

    output bit signed [15:0] audio_left,
    output bit signed [15:0] audio_right,
    input sample_tick44,
    output playback_active
);

    // 4kB of MPEG stream memory to fill from outside
    bit [31:0] mpeg_stream_fifo[1024];

    // Word Address
    bit [27:0] mpeg_stream_fifo_write_adr;
    bit [31:0] mpeg_stream_bit_index;
    wire [28:0] mpeg_stream_byte_index = mpeg_stream_bit_index[31:3];

    // Word address
    wire [27:0] mpeg_stream_fifo_read_adr = mpeg_stream_byte_index[28:1];

    assign fifo_full = mpeg_stream_fifo_write_adr > (mpeg_stream_fifo_read_adr + 28'd2000);

    always_ff @(posedge clk) begin
        if (data_strobe) begin
            mpeg_stream_fifo_write_adr <= mpeg_stream_fifo_write_adr + 1;
            if (!mpeg_stream_fifo_write_adr[0])
                mpeg_stream_fifo[mpeg_stream_fifo_write_adr[10:1]][31:16] <= data_word;
            if (mpeg_stream_fifo_write_adr[0])
                mpeg_stream_fifo[mpeg_stream_fifo_write_adr[10:1]][15:0] <= data_word;
        end

        if (dmem_cmd_payload_write && dmem_cmd_valid) begin
            if (dmem_cmd_payload_address == 32'h10002000)
                mpeg_stream_fifo_write_adr <= dmem_cmd_payload_data[27:0];
            if (dmem_cmd_payload_address == 32'h10002004)
                mpeg_stream_bit_index <= dmem_cmd_payload_data;
        end
    end


    // 28000 byte of memory are required
    bit [31:0] memory[40000/4];
    initial $readmemh("../sw/firmware.mem", memory);

    // sbt "Test/runMain vexiiriscv.Generate --with-rvm --with-rvc 
    // --region base=00000000,size=80000000,main=1,exe=1 --allow-bypass-from=0"

    wire        imem_cmd_valid;
    bit         imem_cmd_ready;
    wire [ 0:0] imem_cmd_payload_id;
    wire [31:0] imem_cmd_payload_address;
    bit         imem_rsp_valid;
    bit  [ 0:0] imem_rsp_payload_id;
    bit         imem_rsp_payload_error;
    bit  [31:0] imem_rsp_payload_word;
    wire        dmem_cmd_valid;
    bit         dmem_cmd_ready;
    wire [ 0:0] dmem_cmd_payload_id;
    wire        dmem_cmd_payload_write;
    wire [31:0] dmem_cmd_payload_address;
    wire [31:0] dmem_cmd_payload_data;
    wire [ 1:0] dmem_cmd_payload_size;
    wire [ 3:0] dmem_cmd_payload_mask;
    wire        dmem_cmd_payload_io;
    wire        dmem_cmd_payload_fromHart;
    wire [15:0] dmem_cmd_payload_uopId;
    bit         dmem_rsp_valid;
    bit  [ 0:0] dmem_rsp_payload_id;
    bit         dmem_rsp_payload_error;
    bit  [31:0] dmem_rsp_payload_data;

    /*verilator tracing_off*/
    VexiiRiscv vexii (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data),
        .clk(clk),
        .reset(reset)
    );
    /*verilator tracing_on*/

    bit signed [31:0] mac_vector_accu = 0;
    bit signed [17:0] mac_vector_temp1 = 0;
    bit signed [31:0] mac_vector_temp2 = 0;

    bit [31:0] mac_vector_addr;
    bit [8:0] mac_vector_index;
    bit [7:0] mac_vector_cnt;
    bit perform_calc;
    enum bit {
        IDLE,
        FETCH
    } mac_state;

    always_ff @(posedge clk) begin
        perform_calc <= 0;

        if (perform_calc) begin
            /*
            $display("Accumulate %d <= %d + %d * %d",
                     mac_vector_accu + mac_vector_temp1 * mac_vector_temp2, mac_vector_accu,
                     mac_vector_temp1, mac_vector_temp2);
            */
            mac_vector_accu <= mac_vector_accu + mac_vector_temp1 * mac_vector_temp2;
            // mac_vector_accu <= mac_vector_accu + 1;
        end

        case (mac_state)
            IDLE: begin
                if (dmem_cmd_payload_address == 32'h10001000 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) begin
                    mac_vector_addr <= dmem_cmd_payload_data;
                    //$display("Vector Adr %x", dmem_cmd_payload_data);
                end
                if (dmem_cmd_payload_address == 32'h10001004 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) begin
                    mac_vector_index <= dmem_cmd_payload_data[8:0];
                    mac_vector_cnt <= 8;
                    mac_state <= FETCH;
                    //$display("Vector Index %x", dmem_cmd_payload_data[8:0]);

                end
                if (dmem_cmd_payload_address == 32'h10001008 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready)
                    mac_vector_accu <= dmem_cmd_payload_data;
            end
            FETCH: begin
                mac_vector_temp1 <= PLM_AUDIO_SYNTHESIS_WINDOW(mac_vector_index);
                mac_vector_temp2 <= reverse_endian_32(memory[mac_vector_addr>>2]);
                mac_vector_index <= mac_vector_index + 64;
                mac_vector_addr  <= mac_vector_addr + 128 * 4;
                mac_vector_cnt   <= mac_vector_cnt - 1;
                if (mac_vector_cnt != 0) perform_calc <= 1;
                else mac_state <= IDLE;
            end
        endcase
    end

    always_comb begin
        imem_cmd_ready = 1;

        dmem_cmd_ready = 1;
        if (dmem_cmd_payload_address[31:28] == 4'd1) begin
            dmem_cmd_ready = !mac_state && fifo_nearly_full == 0;
        end
    end

    bit [31:0] debug_l_storage;

    always_ff @(posedge clk) begin
        imem_rsp_valid <= 0;
        dmem_rsp_valid <= 0;

        if (dmem_cmd_payload_write && dmem_cmd_valid) begin
            if (dmem_cmd_payload_address == 32'h1000000c) $finish();
            if (dmem_cmd_payload_address == 32'h10000030) soft_state <= dmem_cmd_payload_data;
            if (dmem_cmd_payload_address == 32'h10000000)
                $display("Debug out %x", dmem_cmd_payload_data);
            if (dmem_cmd_payload_address == 32'h10000040)
                $display("Debug A %x", dmem_cmd_payload_data);
            if (dmem_cmd_payload_address == 32'h10000044)
                $display("Debug B %x", dmem_cmd_payload_data);

            if (dmem_cmd_payload_address == 32'h10002004)
                mpeg_stream_bit_index <= dmem_cmd_payload_data;

            if (dmem_cmd_payload_address == 32'h10000004) debug_l_storage <= dmem_cmd_payload_data;
            if (dmem_cmd_payload_address == 32'h10000008)
                $display("Debug %d %d", signed'(debug_l_storage), signed'(dmem_cmd_payload_data));
        end

        if (dmem_cmd_valid && dmem_cmd_ready) begin
            dmem_rsp_payload_id <= dmem_cmd_payload_id;
            dmem_rsp_valid <= 1;

            case (dmem_cmd_payload_address[31:28])
                4'd1: begin
                    // I/O Area
                    if (!dmem_cmd_payload_write) begin
                        if (dmem_cmd_payload_address == 32'h10001008)
                            dmem_rsp_payload_data <= mac_vector_accu;
                        if (dmem_cmd_payload_address == 32'h10002000)
                            dmem_rsp_payload_data <= {3'b000, mpeg_stream_fifo_write_adr, 1'b0};
                        if (dmem_cmd_payload_address == 32'h10002004)
                            dmem_rsp_payload_data <= mpeg_stream_bit_index;
                    end
                end
                4'd0: begin
                    if (dmem_cmd_payload_write) begin
                        if (dmem_cmd_payload_mask[0])
                            memory[dmem_cmd_payload_address>>2][31:24] <= dmem_cmd_payload_data[7:0];
                        if (dmem_cmd_payload_mask[1])
                            memory[dmem_cmd_payload_address>>2][23:16] <= dmem_cmd_payload_data[15:8];
                        if (dmem_cmd_payload_mask[2])
                            memory[dmem_cmd_payload_address>>2][15:8] <= dmem_cmd_payload_data[23:16];
                        if (dmem_cmd_payload_mask[3])
                            memory[dmem_cmd_payload_address>>2][7:0] <= dmem_cmd_payload_data[31:24];
                    end else begin
                        dmem_rsp_payload_data <=
                            reverse_endian_32(memory[dmem_cmd_payload_address>>2]);
                    end
                end
                default: begin
                    // Assign the rest of the memory to the MPEG FIFO to fake a real big file
                    dmem_rsp_payload_data <= reverse_endian_32(
                        mpeg_stream_fifo[dmem_cmd_payload_address>>2]
                    );
                end
            endcase
        end

        if (imem_cmd_valid) begin
            imem_rsp_valid <= 1;
            imem_rsp_payload_id <= imem_cmd_payload_id;
            imem_rsp_payload_word <= reverse_endian_32(memory[imem_cmd_payload_address>>2]);
        end
    end

    audiostream xa_fifo_out[2] ();
    audiostream xa_fifo_in[2] ();

    wire [1:0] fifo_nearly_full;
    wire [1:0] fifo_half_full;

    audiofifo fifo_left (
        .clk,
        .reset,
        .in(xa_fifo_in[0]),
        .out(xa_fifo_out[0]),
        .nearly_full(fifo_nearly_full[0]),
        .half_full(fifo_half_full[0])
    );
    audiofifo fifo_right (
        .clk,
        .reset,
        .in(xa_fifo_in[1]),
        .out(xa_fifo_out[1]),
        .nearly_full(fifo_nearly_full[1]),
        .half_full(fifo_half_full[1])
    );

    wire [15:0] sample  /*verilator public_flat_rd*/ = dmem_cmd_payload_data[15:0];
    wire sample_left_write /*verilator public_flat_rd*/ = (dmem_cmd_payload_address == 32'h10003000 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) ;
    wire sample_right_write /*verilator public_flat_rd*/ = (dmem_cmd_payload_address == 32'h10004000 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) ;
    bit [31:0] soft_state = 0;

    always_comb begin
        xa_fifo_in[0].sample = sample;
        xa_fifo_in[1].sample = sample;
        xa_fifo_in[0].write  = sample_left_write;
        xa_fifo_in[1].write  = sample_right_write;
    end

    // Used to reduce the speed of zeroing after playback has ended
    bit dc_bias_cnt;
    bit audio_fifo_output_enabled = 0;
    assign playback_active = audio_fifo_output_enabled;

    bit strobe_fifo;
    always_comb begin
        strobe_fifo = 0;
        if (audio_fifo_output_enabled) begin
            if (sample_tick44) strobe_fifo = 1;
        end
    end


    always_ff @(posedge clk) begin
        dc_bias_cnt <= !dc_bias_cnt;

        xa_fifo_out[0].strobe <= 0;
        xa_fifo_out[1].strobe <= 0;

        if (reset) begin
            audio_fifo_output_enabled <= 0;
            xa_fifo_out[0].strobe <= 0;
            xa_fifo_out[1].strobe <= 0;
        end else begin

            if (fifo_half_full == 2'b11 && sample_tick44) begin
                audio_fifo_output_enabled <= 1;
            end

            if (xa_fifo_out[0].write == 0 && xa_fifo_out[0].write == 0) begin
                audio_fifo_output_enabled <= 0;
            end

            if (audio_fifo_output_enabled) begin
                if (strobe_fifo) begin
                    xa_fifo_out[0].strobe <= 1;
                    xa_fifo_out[1].strobe <= 1;

                    audio_left <= xa_fifo_out[0].sample;
                    audio_right <= xa_fifo_out[1].sample;
                end
            end else if (dc_bias_cnt) begin
                // Slowly move the current sample to zero
                // to remove pops when playing the next samples

                if (audio_left > 0) audio_left <= audio_left - 1;
                else if (audio_left < 0) audio_left <= audio_left + 1;

                if (audio_right > 0) audio_right <= audio_right - 1;
                else if (audio_right < 0) audio_right <= audio_right + 1;
            end
        end
    end


endmodule
