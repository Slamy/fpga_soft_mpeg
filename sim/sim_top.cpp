

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

int OUT_DEBUG;
#define PL_MPEG_IMPLEMENTATION
#include "../sw/pl_mpeg.h"

// #define TRACE

volatile sig_atomic_t status = 0;

static void catch_function(int signo)
{
    status = signo;
}

uint64_t softstate_heatmap[40]{0};

int write_bmp(const char *path, int width, int height, uint8_t *pixels)
{
    FILE *fh = fopen(path, "wb");
    if (!fh)
    {
        return 0;
    }

    int padded_width = (width * 3 + 3) & (~3);
    int padding = padded_width - (width * 3);
    int data_size = padded_width * height;
    int file_size = 54 + data_size;

    fwrite("BM", 1, 2, fh);
    fwrite(&file_size, 1, 4, fh);
    fwrite("\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00", 1, 12, fh);
    fwrite(&width, 1, 4, fh);
    fwrite(&height, 1, 4, fh);
    fwrite("\x01\x00\x18\x00\x00\x00\x00\x00", 1, 8, fh); // planes, bpp, compression
    fwrite(&data_size, 1, 4, fh);
    fwrite("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", 1, 16, fh);

    for (int y = height - 1; y >= 0; y--)
    {
        fwrite(pixels + y * width * 3, 3, width, fh);
        fwrite("\x00\x00\x00\x00", 1, padding, fh);
    }
    fclose(fh);
    return file_size;
}

typedef struct
{
    unsigned int width;
    unsigned int height;
    uint32_t adr;
} plm_plane2_t;

// Decoded Video Frame
// width and height denote the desired display size of the frame. This may be
// different from the internal size of the 3 planes.

typedef struct
{
    double time;
    unsigned int width;
    unsigned int height;
    plm_plane2_t y;
    plm_plane2_t cr;
    plm_plane2_t cb;
} plm_frame2_t;

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
    int bmp_cnt{0};

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

        softstate_heatmap[dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__soft_state)]++;

        if (dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__expose_frame))
        {

            uint32_t addr = dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__frame_adr);
            uint8_t *mem = (uint8_t *)&dut.rootp->CONCAT_FLAT_PUBLIC(__DOT__memory);
            plm_frame2_t frame = *(plm_frame2_t *)(mem + addr);

            // printf("%d %d %x %x %x\n", frame.width, frame.height, frame.y.adr, frame.cr.adr, frame.cb.adr);
            // printf("%x %x %x\n",mem[frame.y.adr], mem[frame.cr.adr],mem[frame.cb.adr]);
            plm_frame_t frame_convert;
            frame_convert.y.data = &mem[frame.y.adr];
            frame_convert.y.height = frame.y.height;
            frame_convert.y.width = frame.y.width;
            frame_convert.cr.data = &mem[frame.cr.adr];
            frame_convert.cr.height = frame.cr.height;
            frame_convert.cr.width = frame.cr.width;
            frame_convert.cb.data = &mem[frame.cb.adr];
            frame_convert.cb.height = frame.cb.height;
            frame_convert.cb.width = frame.cb.width;
            frame_convert.width = frame.width;
            frame_convert.height = frame.height;

            char bmp_name[16];
            int w = frame.width;
            int h = frame.height;
            uint8_t *pixels = (uint8_t *)malloc(w * h * 3);
            assert(pixels);
            plm_frame_to_bgr(&frame_convert, pixels, w * 3); // BMP expects BGR ordering

            sprintf(bmp_name, "%06d.bmp", bmp_cnt);
            printf("Writing %s\n", bmp_name);
            write_bmp(bmp_name, w, h, pixels);

            free(pixels);
            bmp_cnt++;
        }
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

    uint64_t sum = 0;
    for (int i = 0; i < 40; i++)
        sum += softstate_heatmap[i];

    for (int i = 0; i < 40; i++)
    {
        if (softstate_heatmap[i])
        {
            uint64_t percent = 100 * softstate_heatmap[i] / sum;
            printf("%3d %15d %3d\n", i, softstate_heatmap[i], percent);
        }
    }
}

/*
Debug out 1e1e1e1e  Waterlevel:         -103 Frames decoded:          30
Frames shown:         133  Load:         443 %
Writing 000030.bmp
^CClosing...
  0           14226   0
  2         3833160   2
  3            3036   0
  4            4338   0
  5            6522   0
  6         3250170   1
  7         5161493   2
  8         3537496   1
 10        36516822  19
 11        35133777  18
 12        30804639  16
 30        39509769  21
 31        10783757   5
 32        18320949   9
 */

/*
Removal of size check

Debug out 1e1e1e1e  Waterlevel:          -93 Frames decoded:          30
Frames shown:         123  Load:         410 %
Writing 000030.bmp
0           14049   0
2         3833192   2
3            2046   0
4            2874   0
5            6225   0
6         3226730   1
7         5017927   2
8         2765701   1
10        36882664  21
11        35533055  20
12        29506671  16
30        36067548  20
31         9753128   5
32        12252127   7
*/

/*
IDCT and everything afterwards removed

Debug out 24242424  Waterlevel:          -47 Frames decoded:          36
Frames shown:          83  Load:         230 %
Writing 000036.bmp
  0           14049   0
  2         4508975   3
  3            2418   0
  4            3357   0
  5            7355   0
  6           83526   0
  7         5793677   5
  8         3365248   2
 12        34262502  30
 30        39595724  34
 31        12152910  10
 32        14002514  12

*/

/*

plm_buffer_read_vlc is 20

Debug out 1e1e1e1e  Waterlevel:          -94 Frames decoded:          30  Frames shown:         124  Load:         413 %
Writing 000030.bmp
^CClosing...
  0           14164   0
  2         3833771   2
  3            2145   0
  4            2814   0
  5            6189   0
  6         3238955   1
  7           60720   0
  8          956709   0
 10        37491030  21
 11        35767599  20
 12         3001337   1
 20        40341058  22
 21        30516135  17
 30          251883   0
 31        10076302   5
 32        12568866   7

*/