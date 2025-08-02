`timescale 1 ns / 1 ps
`include "synth_window.svh"
`include "util.svh"

module top_vexii (
    input clk,
    input resetn
);

    bit signed [34:0] fifo_water_level;
    bit [34:0] ticks_since_playback_started;
    bit [34:0] frames_decoded;

    bit fifo_nearly_empty;

    bit [31:0] mpeg_video_rom[201554];
    initial $readmemh("fmv.mem", mpeg_video_rom);

    // Memory arrays
    bit [31:0] memory_core1[500000]  /*verilator public_flat_rd*/;
    bit [31:0] memory_core2[500000]  /*verilator public_flat_rd*/;
    bit [31:0] shared_sram [500000];  // 128KB shared SRAM

    initial begin
        $readmemh("../sw/firmware.mem", memory_core1);
        $readmemh("../sw/firmware2.mem", memory_core2);
    end

    // Core 1 signals
    wire        imem_cmd_valid_1;
    bit         imem_cmd_ready_1;
    wire [ 0:0] imem_cmd_payload_id_1;
    wire [31:0] imem_cmd_payload_address_1;
    bit         imem_rsp_valid_1;
    bit  [ 0:0] imem_rsp_payload_id_1;
    bit         imem_rsp_payload_error_1;
    bit  [31:0] imem_rsp_payload_word_1;
    wire        dmem_cmd_valid_1;
    bit         dmem_cmd_ready_1;
    wire [ 0:0] dmem_cmd_payload_id_1;
    wire        dmem_cmd_payload_write_1;
    wire [31:0] dmem_cmd_payload_address_1;
    wire [31:0] dmem_cmd_payload_data_1;
    wire [ 1:0] dmem_cmd_payload_size_1;
    wire [ 3:0] dmem_cmd_payload_mask_1;
    wire        dmem_cmd_payload_io_1;
    wire        dmem_cmd_payload_fromHart_1;
    wire [15:0] dmem_cmd_payload_uopId_1;
    bit         dmem_rsp_valid_1;
    bit  [ 0:0] dmem_rsp_payload_id_1;
    bit         dmem_rsp_payload_error_1;
    bit  [31:0] dmem_rsp_payload_data_1;

    // Core 2 signals 
    wire        imem_cmd_valid_2;
    bit         imem_cmd_ready_2;
    wire [ 0:0] imem_cmd_payload_id_2;
    wire [31:0] imem_cmd_payload_address_2;
    bit         imem_rsp_valid_2;
    bit  [ 0:0] imem_rsp_payload_id_2;
    bit         imem_rsp_payload_error_2;
    bit  [31:0] imem_rsp_payload_word_2;
    wire        dmem_cmd_valid_2;
    bit         dmem_cmd_ready_2;
    wire [ 0:0] dmem_cmd_payload_id_2;
    wire        dmem_cmd_payload_write_2;
    wire [31:0] dmem_cmd_payload_address_2;
    wire [31:0] dmem_cmd_payload_data_2;
    wire [ 1:0] dmem_cmd_payload_size_2;
    wire [ 3:0] dmem_cmd_payload_mask_2;
    wire        dmem_cmd_payload_io_2;
    wire        dmem_cmd_payload_fromHart_2;
    wire [15:0] dmem_cmd_payload_uopId_2;
    bit         dmem_rsp_valid_2;
    bit  [ 0:0] dmem_rsp_payload_id_2;
    bit         dmem_rsp_payload_error_2;
    bit  [31:0] dmem_rsp_payload_data_2;

    /*verilator tracing_off*/
    VexiiRiscv vexii1 (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid_1),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready_1),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id_1),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address_1),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error_1),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word_1),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid_1),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart_1),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId_1),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error_1),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data_1),
        .clk(clk),
        .reset(!resetn)
    );
    VexiiRiscv vexii2 (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),
        .FetchCachelessPlugin_logic_bus_cmd_valid(imem_cmd_valid_2),
        .FetchCachelessPlugin_logic_bus_cmd_ready(imem_cmd_ready_2),
        .FetchCachelessPlugin_logic_bus_cmd_payload_id(imem_cmd_payload_id_2),
        .FetchCachelessPlugin_logic_bus_cmd_payload_address(imem_cmd_payload_address_2),
        .FetchCachelessPlugin_logic_bus_rsp_valid(imem_rsp_valid_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_id(imem_rsp_payload_id_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_error(imem_rsp_payload_error_2),
        .FetchCachelessPlugin_logic_bus_rsp_payload_word(imem_rsp_payload_word_2),
        .LsuCachelessPlugin_logic_bus_cmd_valid(dmem_cmd_valid_2),
        .LsuCachelessPlugin_logic_bus_cmd_ready(dmem_cmd_ready_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_id(dmem_cmd_payload_id_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_write(dmem_cmd_payload_write_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_address(dmem_cmd_payload_address_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_data(dmem_cmd_payload_data_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_size(dmem_cmd_payload_size_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_mask(dmem_cmd_payload_mask_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_io(dmem_cmd_payload_io_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_fromHart(dmem_cmd_payload_fromHart_2),
        .LsuCachelessPlugin_logic_bus_cmd_payload_uopId(dmem_cmd_payload_uopId_2),
        .LsuCachelessPlugin_logic_bus_rsp_valid(dmem_rsp_valid_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_id(dmem_rsp_payload_id_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_error(dmem_rsp_payload_error_2),
        .LsuCachelessPlugin_logic_bus_rsp_payload_data(dmem_rsp_payload_data_2),
        .clk(clk),
        .reset(!resetn)
    );
    /*verilator tracing_on*/

    bit debugflag = 0;

    wire [31:0] frame_adr  /*verilator public_flat_rd*/ = dmem_cmd_payload_data_1;
    wire expose_frame /*verilator public_flat_rd*/ = (dmem_cmd_payload_address_1 == 32'h10000010 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1) ;
    bit [31:0] soft_state1  /*verilator public_flat_rd*/ = 0;
    bit [31:0] soft_state2  /*verilator public_flat_rd*/ = 0;


    bit fail;
    bit draining_fifo = 0;
    bit [31:0] debug_l_storage;

    always_comb begin
        imem_cmd_ready_1 = 1;
        dmem_cmd_ready_1 = 1;
        imem_cmd_ready_2 = 1;
        dmem_cmd_ready_2 = 1;
    end

    // Assuming 30 MHz clock rate and 25 Hz frame rate
    localparam TICKS_PER_FRAME = 1200000;

    bit signed [15:0] shared_buffer_level = 0;

    wire shared_buffer_level_inc = dmem_cmd_payload_address_1 == 32'h10000014 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1;
    wire shared_buffer_level_dec = dmem_cmd_payload_address_2 == 32'h10000014 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2;

    always_ff @(posedge clk) begin
        debugflag <= 0;
        imem_rsp_valid_1 <= 0;
        dmem_rsp_valid_1 <= 0;
        imem_rsp_valid_2 <= 0;
        dmem_rsp_valid_2 <= 0;

        if (shared_buffer_level_inc && !shared_buffer_level_dec)
            shared_buffer_level <= shared_buffer_level + 1;
        if (shared_buffer_level_dec && !shared_buffer_level_inc)
            shared_buffer_level <= shared_buffer_level - 1;

        if (dmem_cmd_payload_address_1 == 32'h1000000c && dmem_cmd_payload_write_1 && dmem_cmd_valid_1)
            $finish();
        if (dmem_cmd_payload_address_1 == 32'h10000030 && dmem_cmd_payload_write_1 && dmem_cmd_valid_1)
            soft_state1 <= dmem_cmd_payload_data_1;
        if (dmem_cmd_payload_address_2 == 32'h10000030 && dmem_cmd_payload_write_2 && dmem_cmd_valid_2)
            soft_state2 <= dmem_cmd_payload_data_2;

        if (draining_fifo) begin
            fifo_water_level <= fifo_water_level - 1;
            ticks_since_playback_started <= ticks_since_playback_started + 1;
        end

        if (expose_frame) begin
            fifo_water_level <= fifo_water_level + TICKS_PER_FRAME;
            frames_decoded   <= frames_decoded + 1;
        end

        fifo_nearly_empty <= (fifo_water_level < (TICKS_PER_FRAME / 2));

        // With 2 frames available, we start the playback
        if (fifo_water_level >= (TICKS_PER_FRAME * 2)) draining_fifo <= 1;

        if (dmem_cmd_payload_address_1 == 32'h10000000 && dmem_cmd_valid_1 && dmem_cmd_payload_write_1)
            $display(
                "Debug out %x  Waterlevel: %d Frames decoded: %d  Frames shown: %d  Load: %d %%",
                dmem_cmd_payload_data_1,
                fifo_water_level / TICKS_PER_FRAME,
                frames_decoded,
                ticks_since_playback_started / TICKS_PER_FRAME,
                (ticks_since_playback_started / TICKS_PER_FRAME) * 100 / frames_decoded
            );

        // Core 1 memory access
        if (dmem_cmd_valid_1 && dmem_cmd_ready_1) begin
            dmem_rsp_payload_id_1 <= dmem_cmd_payload_id_1;
            dmem_rsp_valid_1 <= 1;

            case (dmem_cmd_payload_address_1[31:28])
                4'd4: begin  // Shared SRAM region
                    if (dmem_cmd_payload_write_1) begin
                        assert (dmem_cmd_payload_mask_1 == 4'b1111);
                        /*
                        $display("Shared Write %x %x", dmem_cmd_payload_address_1,
                                 dmem_cmd_payload_data_1);
                                 */
                        shared_sram[dmem_cmd_payload_address_1[20:2]] <= dmem_cmd_payload_data_1;
                    end else begin
                        dmem_rsp_payload_data_1 <= shared_sram[dmem_cmd_payload_address_1[20:2]];
                    end
                end
                4'd3: begin
                    if (!dmem_cmd_payload_write_1) begin
                    end
                end
                4'd2: begin
                    if (!dmem_cmd_payload_write_1) begin
                        dmem_rsp_payload_data_1 <=
                            reverse_endian_32(mpeg_video_rom[dmem_cmd_payload_address_1>>2]);
                    end
                end
                4'd1: begin
                    if (dmem_cmd_payload_write_1) begin
                        debugflag <= 1;
                    end
                end
                4'd0: begin
                    if (dmem_cmd_payload_write_1) begin
                        if (dmem_cmd_payload_mask_1[0])
                            memory_core1[dmem_cmd_payload_address_1>>2][7:0] <= dmem_cmd_payload_data_1[7:0];
                        if (dmem_cmd_payload_mask_1[1])
                            memory_core1[dmem_cmd_payload_address_1>>2][15:8] <= dmem_cmd_payload_data_1[15:8];
                        if (dmem_cmd_payload_mask_1[2])
                            memory_core1[dmem_cmd_payload_address_1>>2][23:16] <= dmem_cmd_payload_data_1[23:16];
                        if (dmem_cmd_payload_mask_1[3])
                            memory_core1[dmem_cmd_payload_address_1>>2][31:24] <= dmem_cmd_payload_data_1[31:24];
                    end else begin
                        dmem_rsp_payload_data_1 <= memory_core1[dmem_cmd_payload_address_1>>2];
                    end
                end
                default: ;
            endcase
        end

        // Core 2 memory access
        if (dmem_cmd_valid_2 && dmem_cmd_ready_2) begin
            dmem_rsp_payload_id_2 <= dmem_cmd_payload_id_2;
            dmem_rsp_valid_2 <= 1;

            case (dmem_cmd_payload_address_2[31:28])
                4'd5: begin  // Core 1 private memory
                    if (dmem_cmd_payload_write_2) begin
                        if (dmem_cmd_payload_mask_2[0])
                            memory_core1[dmem_cmd_payload_address_2[20:2]][7:0] <= dmem_cmd_payload_data_2[7:0];
                        if (dmem_cmd_payload_mask_2[1])
                            memory_core1[dmem_cmd_payload_address_2[20:2]][15:8] <= dmem_cmd_payload_data_2[15:8];
                        if (dmem_cmd_payload_mask_2[2])
                            memory_core1[dmem_cmd_payload_address_2[20:2]][23:16] <= dmem_cmd_payload_data_2[23:16];
                        if (dmem_cmd_payload_mask_2[3])
                            memory_core1[dmem_cmd_payload_address_2[20:2]][31:24] <= dmem_cmd_payload_data_2[31:24];
                    end else begin
                        dmem_rsp_payload_data_2 <= memory_core1[dmem_cmd_payload_address_2[20:2]];
                    end
                end
                4'd4: begin  // Shared SRAM region
                    if (dmem_cmd_payload_write_2) begin
                        shared_sram[dmem_cmd_payload_address_2[20:2]] <= dmem_cmd_payload_data_2;
                    end else begin
                        dmem_rsp_payload_data_2 <= shared_sram[dmem_cmd_payload_address_2[20:2]];
                    end
                end
                4'd0: begin  // Core 2 private memory
                    if (dmem_cmd_payload_write_2) begin
                        if (dmem_cmd_payload_mask_2[0])
                            memory_core2[dmem_cmd_payload_address_2>>2][7:0] <= dmem_cmd_payload_data_2[7:0];
                        if (dmem_cmd_payload_mask_2[1])
                            memory_core2[dmem_cmd_payload_address_2>>2][15:8] <= dmem_cmd_payload_data_2[15:8];
                        if (dmem_cmd_payload_mask_2[2])
                            memory_core2[dmem_cmd_payload_address_2>>2][23:16] <= dmem_cmd_payload_data_2[23:16];
                        if (dmem_cmd_payload_mask_2[3])
                            memory_core2[dmem_cmd_payload_address_2>>2][31:24] <= dmem_cmd_payload_data_2[31:24];
                    end else begin
                        dmem_rsp_payload_data_2 <= memory_core2[dmem_cmd_payload_address_2>>2];
                    end
                end
                default: ;

            endcase
        end

        if (imem_cmd_valid_1) begin
            imem_rsp_valid_1 <= 1;
            imem_rsp_payload_id_1 <= imem_cmd_payload_id_1;
            imem_rsp_payload_word_1 <= memory_core1[imem_cmd_payload_address_1>>2];
        end

        // Instruction fetch logic for core 2
        if (imem_cmd_valid_2) begin
            imem_rsp_valid_2 <= 1;
            imem_rsp_payload_id_2 <= imem_cmd_payload_id_2;
            imem_rsp_payload_word_2 <= memory_core2[imem_cmd_payload_address_2>>2];
        end
    end
endmodule
