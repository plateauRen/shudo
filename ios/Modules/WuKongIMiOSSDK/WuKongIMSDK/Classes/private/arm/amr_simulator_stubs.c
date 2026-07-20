// Apple Silicon 模拟器 arm64 无法链接真机 AMR 静态库，提供桩实现以便编译/跑通登录与消息链路。
// 真机仍链接 libopencore-amr* / libvo-amrwbenc。
#include <TargetConditionals.h>
#if TARGET_OS_SIMULATOR

#include <stddef.h>
#include <string.h>

enum Mode {
    MR475 = 0,
    MR515,
    MR59,
    MR67,
    MR74,
    MR795,
    MR102,
    MR122,
    MRDTX,
    N_MODES
};

static char g_amr_stub_state;

void *Encoder_Interface_init(int dtx) {
    (void)dtx;
    return &g_amr_stub_state;
}

void Encoder_Interface_exit(void *state) { (void)state; }

int Encoder_Interface_Encode(void *state, enum Mode mode, const short *speech,
                             unsigned char *out, int forceSpeech) {
    (void)state;
    (void)mode;
    (void)speech;
    (void)forceSpeech;
    if (out) {
        out[0] = 0;
    }
    return 1;
}

void *Decoder_Interface_init(void) { return &g_amr_stub_state; }

void Decoder_Interface_exit(void *state) { (void)state; }

void Decoder_Interface_Decode(void *state, const unsigned char *in, short *out, int bfi) {
    (void)state;
    (void)in;
    (void)bfi;
    if (out) {
        memset(out, 0, 160 * sizeof(short));
    }
}

void *E_IF_init(void) { return &g_amr_stub_state; }

int E_IF_encode(void *state, int mode, const short *speech, unsigned char *out, int dtx) {
    (void)state;
    (void)mode;
    (void)speech;
    (void)dtx;
    if (out) {
        out[0] = 0;
    }
    return 1;
}

void E_IF_exit(void *state) { (void)state; }

void *D_IF_init(void) { return &g_amr_stub_state; }

void D_IF_decode(void *state, const unsigned char *bits, short *synth, int bfi) {
    (void)state;
    (void)bits;
    (void)bfi;
    if (synth) {
        memset(synth, 0, 320 * sizeof(short));
    }
}

void D_IF_exit(void *state) { (void)state; }

#endif
