`timescale 1 ns / 1 ps
`include "synth_window.svh"
`include "util.svh"

module top_vexii (
    input clk,
    input resetn
);

    bit signed [34:0] fifo_water_level[2];
    bit [34:0] ticks_since_playback_started;
    bit [34:0] samples_decoded;

    bit fifo_nearly_empty;

    bit [31:0] mpeg_audio_rom[21888];
    initial $readmemh("fma.mem", mpeg_audio_rom);

    bit [31:0] memory[500000];
    initial $readmemh("../sw/firmware.mem", memory);

    // sbt "Test/runMain vexiiriscv.Generate --with-rvm --with-rvc --region base=00000000,size=80000000,main=1,exe=1 --allow-bypass-from=0"

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
        .reset(!resetn)
    );
    /*verilator tracing_on*/

    bit debugflag = 0;

    wire [31:0] sample  /*verilator public_flat_rd*/ = dmem_cmd_payload_data;
    wire sample_left_write /*verilator public_flat_rd*/ = (dmem_cmd_payload_address == 32'h10000010 && dmem_cmd_payload_write && dmem_cmd_valid) ;
    wire sample_right_write /*verilator public_flat_rd*/ = (dmem_cmd_payload_address == 32'h10000020 && dmem_cmd_payload_write&& dmem_cmd_valid) ;
    bit [31:0] soft_state = 0;


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
                if (dmem_cmd_payload_address == 32'h30000000 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) begin
                    mac_vector_addr <= dmem_cmd_payload_data;
                    //$display("Vector Adr %x", dmem_cmd_payload_data);
                end
                if (dmem_cmd_payload_address == 32'h30000004 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready) begin
                    mac_vector_index <= dmem_cmd_payload_data[8:0];
                    mac_vector_cnt <= 8;
                    mac_state <= FETCH;
                    //$display("Vector Index %x", dmem_cmd_payload_data[8:0]);

                end
                if (dmem_cmd_payload_address == 32'h30000008 && dmem_cmd_payload_write && dmem_cmd_valid && dmem_cmd_ready)
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

    bit fail;
    bit draining_fifo = 0;
    bit [31:0] debug_l_storage;

    always_comb begin
        imem_cmd_ready = 1;

        dmem_cmd_ready = 1;
        if (dmem_cmd_payload_address[31:28] == 4'd3) dmem_cmd_ready = !mac_state;
    end

    // Assuming 30 MHz clock rate and 44100 Hz sample rate
    localparam TICKS_PER_SAMPLE = 680;

    always_ff @(posedge clk) begin
        debugflag <= 0;
        imem_rsp_valid <= 0;
        dmem_rsp_valid <= 0;

        if (dmem_cmd_payload_address == 32'h1000000c && dmem_cmd_payload_write && dmem_cmd_valid)
            $finish();
        if (dmem_cmd_payload_address == 32'h10000030 && dmem_cmd_payload_write && dmem_cmd_valid)
            soft_state <= dmem_cmd_payload_data;

        if (draining_fifo) begin
            fifo_water_level[0] <= fifo_water_level[0] - 1;
            fifo_water_level[1] <= fifo_water_level[1] - 1;
            ticks_since_playback_started <= ticks_since_playback_started + 1;
        end

        if (sample_left_write) fifo_water_level[0] <= fifo_water_level[0] + TICKS_PER_SAMPLE;
        if (sample_right_write) fifo_water_level[1] <= fifo_water_level[1] + TICKS_PER_SAMPLE;
        if (sample_left_write) samples_decoded <= samples_decoded + 1;

        fifo_nearly_empty <= (fifo_water_level[0] < (TICKS_PER_SAMPLE*4)) || (fifo_water_level[1] < (TICKS_PER_SAMPLE*4));

        // With 40 samples available, we start the playback
        if (fifo_water_level[0] > (TICKS_PER_SAMPLE * 40)) draining_fifo <= 1;

        if (dmem_cmd_payload_address == 32'h10000000 && dmem_cmd_valid && dmem_cmd_payload_write)
            $display(
                "Debug out %x  Waterlevel: %d %d Samples decoded: %d  Samples played: %d  Load: %d %%",
                dmem_cmd_payload_data,
                fifo_water_level[0] / TICKS_PER_SAMPLE,
                fifo_water_level[1] / TICKS_PER_SAMPLE, samples_decoded,
                ticks_since_playback_started / TICKS_PER_SAMPLE,
                (ticks_since_playback_started / TICKS_PER_SAMPLE) * 100 / samples_decoded);

        if (dmem_cmd_valid && dmem_cmd_ready) begin
            dmem_rsp_payload_id <= dmem_cmd_payload_id;
            dmem_rsp_valid <= 1;

            //if (dmem_cmd_payload_write) $display("CPU Write at %x", dmem_cmd_payload_address);
            // else $display("CPU Read at %x", dmem_cmd_payload_address);

            case (dmem_cmd_payload_address[31:28])
                4'd3: begin
                    if (!dmem_cmd_payload_write) begin
                        if (dmem_cmd_payload_address == 32'h30000008)
                            dmem_rsp_payload_data <= mac_vector_accu;
                        if (dmem_cmd_payload_address == 32'h3000000c)
                            dmem_rsp_payload_data <= mac_state ? 1 : 0;

                        //if (mac_state != IDLE) fail <= 1;
                        //assert (mac_state == IDLE || dmem_cmd_payload_address[]);
                    end
                end
                4'd2: begin
                    if (!dmem_cmd_payload_write) begin
                        dmem_rsp_payload_data <=
                            reverse_endian_32(mpeg_audio_rom[dmem_cmd_payload_address>>2]);
                    end
                end
                4'd1: begin
                    if (dmem_cmd_payload_write) begin
                        debugflag <= 1;
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
                default: ;
            endcase
        end

        if (imem_cmd_valid) begin
            imem_rsp_valid <= 1;
            imem_rsp_payload_id <= imem_cmd_payload_id;
            imem_rsp_payload_word <= reverse_endian_32(memory[imem_cmd_payload_address>>2]);
        end
    end
endmodule
