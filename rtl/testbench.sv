`timescale 1 ns / 1 ps

function [31:0] reverse_endian_32;
    input [31:0] data_in;
    begin
        reverse_endian_32 = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
    end
endfunction


module testbench (
    input clk,
    input resetn
);

    bit [31:0] underflow_cnt[2];

    bit [31:0] mpeg_audio_rom[21888];
    initial $readmemh("fma.mem", mpeg_audio_rom);

    bit [31:0] memory[500000];
    initial $readmemh("../sw/firmware.mem", memory);

    wire        trap;

    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready = 1;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    bit  [31:0] mem_rdata;

    wire        mem_la_read;
    wire        mem_la_write;
    wire [31:0] mem_la_addr;
    wire [31:0] mem_la_wdata;
    wire [ 3:0] mem_la_wstrb;

    wire        trace_valid;
    wire [35:0] trace_data;

    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    wire        pcpi_wr = 0;
    wire [31:0] pcpi_rd = 0;
    wire        pcpi_wait = 0;
    wire        pcpi_ready = 0;

    /* verilator tracing_off */

    picorv32 #(
        .BARREL_SHIFTER(1),
        .ENABLE_FAST_MUL(1),
        .ENABLE_DIV(1),
        .COMPRESSED_ISA(1)
        //.PROGADDR_RESET('h10000),
        //.STACKADDR('h10000),
        //.ENABLE_TRACE(1)
    ) uut (
        .clk         (clk),
        .resetn      (resetn),
        .trap        (trap),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .mem_la_read (mem_la_read),
        .mem_la_write(mem_la_write),
        .mem_la_addr (mem_la_addr),
        .mem_la_wdata(mem_la_wdata),
        .mem_la_wstrb(mem_la_wstrb),
        .trace_valid (trace_valid),
        .trace_data  (trace_data),
        .pcpi_valid  (pcpi_valid),
        .pcpi_insn   (pcpi_insn),
        .pcpi_rs1    (pcpi_rs1),
        .pcpi_rs2    (pcpi_rs2),
        .pcpi_wr     (pcpi_wr),
        .pcpi_rd     (pcpi_rd),
        .pcpi_wait   (pcpi_wait),
        .pcpi_ready  (pcpi_ready),
        .irq         (0),
        .eoi         ()
    );
    /* verilator tracing_on */

    bit debugflag = 0;

    wire [31:0] sample  /*verilator public_flat_rd*/ = mem_la_wdata;
    wire sample_left_write /*verilator public_flat_rd*/ = (mem_la_addr == 32'h10000010 && mem_la_write) ;
    wire sample_right_write /*verilator public_flat_rd*/ = (mem_la_addr == 32'h10000020 && mem_la_write) ;
    bit [31:0] soft_state = 0;

    always_ff @(posedge clk) begin
        debugflag <= 0;

        if (mem_la_addr == 32'h10000030 && mem_la_write) soft_state <= mem_la_wdata;

        if (underflow_cnt[0] > 0) underflow_cnt[0] <= underflow_cnt[0] - 1;
        if (underflow_cnt[1] > 0) underflow_cnt[1] <= underflow_cnt[1] - 1;

        if (sample_left_write) underflow_cnt[0] <= underflow_cnt[0] + 680;
        if (sample_right_write) underflow_cnt[1] <= underflow_cnt[1] + 680;

        if (mem_la_addr == 32'h10000000 && mem_la_write)
            $display("Debug out %x %c", mem_la_wdata, mem_la_wdata[7:0]);

        case (mem_la_addr[31:28])
            4'd2: begin
                if (mem_la_read) begin
                    mem_rdata <= reverse_endian_32(mpeg_audio_rom[mem_la_addr>>2]);
                end
            end
            4'd1: begin
                if (mem_la_write) begin
                    debugflag <= 1;
                end
            end
            4'd0: begin
                if (mem_la_read) begin
                    mem_rdata <= reverse_endian_32(memory[mem_la_addr>>2]);
                end

                if (mem_la_write) begin
                    if (mem_la_wstrb[0]) memory[mem_la_addr>>2][31:24] <= mem_la_wdata[7:0];
                    if (mem_la_wstrb[1]) memory[mem_la_addr>>2][23:16] <= mem_la_wdata[15:8];
                    if (mem_la_wstrb[2]) memory[mem_la_addr>>2][15:8] <= mem_la_wdata[23:16];
                    if (mem_la_wstrb[3]) memory[mem_la_addr>>2][7:0] <= mem_la_wdata[31:24];
                end

            end
            default: ;
        endcase

    end
endmodule
