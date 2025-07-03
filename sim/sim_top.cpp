

#if defined(VEXII)
#include "Vtop_vexii.h"
#include "Vtop_vexii___024root.h"
#define DUT Vtop_vexii
#define CONCAT_FLAT_PUBLIC(x) top_vexii##x
#elif defined(VEXII_WB)
#include "Vtop_vexii_wb.h"
#include "Vtop_vexii_wb___024root.h"
#define DUT Vtop_vexii_wb
#define CONCAT_FLAT_PUBLIC(x) top_vexii_wb##x
#elif defined(PICORV32)
#include "Vtop_picorv32.h"
#include "Vtop_picorv32___024root.h"
#define DUT Vtop_picorv32
#define CONCAT_FLAT_PUBLIC(x) top_picorv32##x
#else
#error "No target defined"
#endif

#include <verilated_fst_c.h>
#include <verilated_vcd_c.h>
#include <csignal>

//#define TRACE

volatile sig_atomic_t status = 0;

static void catch_function(int signo)
{
    status = signo;
}

uint64_t memory_heatmap[2300000];

class Machine
{
public:
    DUT dut;

#ifdef TRACE
    typedef VerilatedFstC tracetype_t;
    // typedef VerilatedVcdC tracetype_t;
    tracetype_t m_trace;
#endif
    FILE *f_audio_left{nullptr};
    FILE *f_audio_right{nullptr};
    char filename[100];
    uint64_t sim_time = 0;
    bool first_sample_provided{false};

    virtual ~Machine()
    {
        fclose(f_audio_right);
        fclose(f_audio_left);
    }

    Machine()
    {
#ifdef TRACE
        dut.trace(&m_trace, 5);
        m_trace.open("/tmp/waveform.vcd");
#endif

        sprintf(filename, "audio_left.bin");
        fprintf(stderr, "Writing to %s\n", filename);
        f_audio_left = fopen(filename, "wb");

        sprintf(filename, "audio_right.bin");
        fprintf(stderr, "Writing to %s\n", filename);
        f_audio_right = fopen(filename, "wb");

        // aplay -f float_le audio_left.bin  -r 44100
        // aplay -f float_le audio_right.bin  -r 44100

        dut.resetn = 0;
        for (int i = 0; i < 10; i++)
        {
            modelstep();
        }
        dut.resetn = 1;
    }

    void modelstep()
    {
        dut.clk = !dut.clk;
        dut.eval();
#ifdef TRACE
        m_trace.dump(sim_time);
#endif
        sim_time += 1;

        dut.clk = !dut.clk;
        dut.eval();
#ifdef TRACE
        m_trace.dump(sim_time);
#endif
        sim_time += 1;

        /*
        if ((dut.rootp->testbench__DOT__mem_la_read || dut.rootp->testbench__DOT__mem_la_write) && (dut.rootp->testbench__DOT__mem_la_addr & 0xf0000000) == 0)
        {
            memory_heatmap[dut.rootp->testbench__DOT__mem_la_addr / 4]++;
        }
        */

        if (!first_sample_provided && (dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample_left_write) || dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample_right_write)))
        {
            first_sample_provided = true;
            printf("First sample at %d\n", sim_time);
        }
        if (dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample_left_write))
            fwrite(&dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample), sizeof(int16_t), 1, f_audio_left);
        if (dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample_right_write))
            fwrite(&dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__sample), sizeof(int16_t), 1, f_audio_right);
    }
};

int main(int argc, char **argv, char **env)
{
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Machine machine;

    if (signal(SIGINT, catch_function) == SIG_ERR)
    {
        fputs("An error occurred while setting a signal handler.\n", stderr);
        return EXIT_FAILURE;
    }

    // for (int i = 0; i < 90000000; i++)
    while (status == 0 && !Verilated::gotFinish())
    {
        machine.modelstep();
    }

    fprintf(stderr, "Closing...\n");
    fflush(stdout);
    /*
        int maxi = 0;
        for (int i = 0; i < 128000; i++)
        {
            if (memory_heatmap[i])
                maxi = i;
        }

        for (int i = 0; i < maxi; i++)
        {
            printf("%08x %x\n", i * 4, memory_heatmap[i]);
        }
            */
}
