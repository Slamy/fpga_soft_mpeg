`timescale 1 ns / 1 ps
`include "synth_window.svh"
`include "util.svh"

module top_vexii_wb (
    input clk,
    input resetn
);

    bit signed [34:0] fifo_water_level[2];
    bit signed [34:0] ticks_since_playback_started;

    bit fifo_nearly_empty;

    bit [31:0] mpeg_audio_rom[21888];
    initial $readmemh("fma.mem", mpeg_audio_rom);

    bit [31:0] memory[500000];
    initial $readmemh("../sw/firmware.mem", memory);

    // sbt "Test/runMain vexiiriscv.Generate --with-rvm --with-rvc 
    // --region base=00000000,size=80000000,main=1,exe=1
    // --allow-bypass-from=0 --fetch-wishbone --lsu-wishbone"

    wire        dmem_cyc;
    wire        dmem_stb;
    bit         dmem_ack;
    bit         dmem_we;
    wire [29:0] dmem_adr;
    bit  [31:0] dmem_miso;
    wire [31:0] dmem_mosi;
    bit  [31:0] dmem_miso_mem;
    wire [ 3:0] dmem_sel;
    wire [ 2:0] dmem_cti;
    wire [ 1:0] dmem_bte;

    wire        imem_cyc;
    wire        imem_stb;
    bit         imem_ack;
    bit         imem_we;
    wire [29:0] imem_adr;
    bit  [31:0] imem_miso;
    wire [31:0] imem_mosi;
    wire [ 3:0] imem_sel;
    wire [ 2:0] imem_cti;
    wire [ 1:0] imem_bte;

    wire [31:0] dmem_adr_byte = {dmem_adr, 2'b00};
    wire [31:0] imem_adr_byte = {imem_adr, 2'b00};


    /*verilator tracing_off*/
    VexiiRiscv_wb vexii (
        .PrivilegedPlugin_logic_rdtime(0),
        .PrivilegedPlugin_logic_harts_0_int_m_timer(0),
        .PrivilegedPlugin_logic_harts_0_int_m_software(0),
        .PrivilegedPlugin_logic_harts_0_int_m_external(0),

        .LsuCachelessWishbonePlugin_logic_bridge_down_CYC(dmem_cyc),
        .LsuCachelessWishbonePlugin_logic_bridge_down_STB(dmem_stb),
        .LsuCachelessWishbonePlugin_logic_bridge_down_ACK(dmem_ack),
        .LsuCachelessWishbonePlugin_logic_bridge_down_WE(dmem_we),
        .LsuCachelessWishbonePlugin_logic_bridge_down_ADR(dmem_adr),
        .LsuCachelessWishbonePlugin_logic_bridge_down_DAT_MISO(dmem_miso),
        .LsuCachelessWishbonePlugin_logic_bridge_down_DAT_MOSI(dmem_mosi),
        .LsuCachelessWishbonePlugin_logic_bridge_down_SEL(dmem_sel),
        .LsuCachelessWishbonePlugin_logic_bridge_down_ERR(0),
        .LsuCachelessWishbonePlugin_logic_bridge_down_CTI(dmem_cti),
        .LsuCachelessWishbonePlugin_logic_bridge_down_BTE(dmem_bte),

        .FetchCachelessWishbonePlugin_logic_bridge_bus_CYC(imem_cyc),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_STB(imem_stb),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_ACK(imem_ack),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_WE(imem_we),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_ADR(imem_adr),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_DAT_MISO(imem_miso),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_DAT_MOSI(imem_mosi),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_SEL(imem_sel),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_ERR(0),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_CTI(imem_cti),
        .FetchCachelessWishbonePlugin_logic_bridge_bus_BTE(imem_bte),
        .clk(clk),
        .reset(!resetn)
    );
    /*verilator tracing_on*/

    bit debugflag = 0;

    wire [31:0] sample  /*verilator public_flat_rd*/ = dmem_mosi;
    wire sample_left_write /*verilator public_flat_rd*/ = (dmem_adr_byte == 32'h10000010 && dmem_we && dmem_stb) ;
    wire sample_right_write /*verilator public_flat_rd*/ = (dmem_adr_byte == 32'h10000020 && dmem_we&& dmem_stb) ;
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
        end

        case (mac_state)
            IDLE: begin
                if (dmem_adr_byte == 32'h30000000 && dmem_we && dmem_stb)
                    mac_vector_addr <= dmem_mosi;
                if (dmem_adr_byte == 32'h30000004 && dmem_we && dmem_stb) begin
                    mac_vector_index <= dmem_mosi[8:0];
                    mac_vector_cnt <= 8;
                    mac_state <= FETCH;
                end
                if (dmem_adr_byte == 32'h30000008 && dmem_we && dmem_stb)
                    mac_vector_accu <= dmem_mosi;
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

    bit dmem_ack_q;
    bit dmem_cyc_q;
    bit dmem_stb_q;
    bit imem_ack_q;
    bit imem_cyc_q;
    bit imem_stb_q;

    always_comb begin
        dmem_miso = dmem_miso_mem;

        imem_ack  = imem_stb_q && imem_cyc_q && imem_stb && imem_cyc && !imem_ack_q;

        // In general accept on same cycle
        dmem_ack  = dmem_stb && dmem_cyc;


        case (dmem_adr_byte[31:28])
            4'd1: begin
                //if (dmem_we) dmem_ack = dmem_stb && dmem_cyc;
            end
            4'd3: begin
                dmem_miso = mac_vector_accu;
                dmem_ack  = dmem_stb && dmem_cyc && mac_state == IDLE;
            end
            default: begin
                // When reading from memory, we delay one cycle
                if (!dmem_we)
                    dmem_ack = dmem_stb_q && dmem_cyc_q && dmem_stb && dmem_cyc && !dmem_ack_q;
            end
        endcase
    end

    // Assuming 30 MHz clock rate and 44100 Hz sample rate
    localparam TICKS_PER_SAMPLE = 680;
    
    always_ff @(posedge clk) begin
        debugflag  <= 0;
        dmem_stb_q <= dmem_stb;
        dmem_cyc_q <= dmem_cyc;
        dmem_ack_q <= dmem_ack;
        imem_stb_q <= imem_stb;
        imem_cyc_q <= imem_cyc;
        imem_ack_q <= imem_ack;

        if (dmem_adr_byte == 32'h1000000c && dmem_we && dmem_stb)
            $finish();
        if (dmem_adr_byte == 32'h10000030 && dmem_we && dmem_stb) soft_state <= dmem_mosi;

        if (draining_fifo) begin
            fifo_water_level[0] <= fifo_water_level[0] - 1;
            fifo_water_level[1] <= fifo_water_level[1] - 1;
            ticks_since_playback_started <= ticks_since_playback_started + 1;
        end

        if (sample_left_write) fifo_water_level[0] <= fifo_water_level[0] + TICKS_PER_SAMPLE;
        if (sample_right_write) fifo_water_level[1] <= fifo_water_level[1] + TICKS_PER_SAMPLE;

        // 
        fifo_nearly_empty <= (fifo_water_level[0] < (TICKS_PER_SAMPLE*4)) || (fifo_water_level[1] < (TICKS_PER_SAMPLE*4));

        // With 40 samples available, we start the playback
        if (fifo_water_level[0] > (TICKS_PER_SAMPLE * 40)) draining_fifo <= 1;

        if (dmem_adr_byte == 32'h10000000 && dmem_we && dmem_stb)
            $display(
                "Debug out %x  Samples decoded: %d %d  Samples played %d  Load: %d %%",
                dmem_mosi,
                fifo_water_level[0] / TICKS_PER_SAMPLE,
                fifo_water_level[1] / TICKS_PER_SAMPLE,
                ticks_since_playback_started / TICKS_PER_SAMPLE,
                ticks_since_playback_started * 100 / fifo_water_level[0]);

        if (dmem_stb) begin
            //if (dmem_we) $display("CPU Write at %x", dmem_adr);
            // else $display("CPU Read at %x", dmem_adr);

            case (dmem_adr_byte[31:28])
                4'd3: begin
                end
                4'd2: begin
                    if (!dmem_we) begin
                        dmem_miso_mem <= reverse_endian_32(mpeg_audio_rom[15'(dmem_adr)]);
                    end
                end
                4'd1: begin
                    if (dmem_we) begin
                        debugflag <= 1;
                    end
                end
                4'd0: begin
                    if (dmem_we) begin
                        if (dmem_sel[0]) memory[19'(dmem_adr)][31:24] <= dmem_mosi[7:0];
                        if (dmem_sel[1]) memory[19'(dmem_adr)][23:16] <= dmem_mosi[15:8];
                        if (dmem_sel[2]) memory[19'(dmem_adr)][15:8] <= dmem_mosi[23:16];
                        if (dmem_sel[3]) memory[19'(dmem_adr)][7:0] <= dmem_mosi[31:24];
                    end else begin
                        dmem_miso_mem <= reverse_endian_32(memory[19'(dmem_adr)]);
                    end
                end
                default: ;
            endcase
        end

        if (imem_cyc && imem_stb) begin
            imem_miso <= reverse_endian_32(memory[19'(imem_adr)]);
        end
    end
endmodule
