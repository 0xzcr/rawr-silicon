// micrec.exe: record a mic through Wine's Windows audio stack (waveIn, the same path game voice chat uses).
// Usage:  micrec.exe list                      -> print input devices
//         (device -1 = WAVE_MAPPER, the system default mic: what a Windows game gets)
//         micrec.exe <device#> <seconds> <rate> <out.wav>
// Build:  zig cc -target x86_64-windows-gnu -O2 micrec.c -lwinmm -o micrec.exe
#include <windows.h>
#include <mmsystem.h>
#include <stdio.h>
#include <stdlib.h>

#define BUFFERS 8          // small ring of buffers, like a game's voice capture
#define BUFFER_MS 20       // 20 ms each, a typical voice frame size

static void write_wav(const char *path, const short *samples, DWORD count, DWORD rate) {
    FILE *f = fopen(path, "wb");
    if (!f) { printf("cannot open %s\n", path); exit(1); }
    DWORD data_bytes = count * 2, riff = 36 + data_bytes, fmt_len = 16, byte_rate = rate * 2;
    WORD pcm = 1, channels = 1, align = 2, bits = 16;
    fwrite("RIFF", 1, 4, f); fwrite(&riff, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
    fwrite(&fmt_len, 4, 1, f); fwrite(&pcm, 2, 1, f); fwrite(&channels, 2, 1, f);
    fwrite(&rate, 4, 1, f); fwrite(&byte_rate, 4, 1, f); fwrite(&align, 2, 1, f); fwrite(&bits, 2, 1, f);
    fwrite("data", 1, 4, f); fwrite(&data_bytes, 4, 1, f); fwrite(samples, 2, count, f);
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc == 2) {
        UINT n = waveInGetNumDevs();
        for (UINT i = 0; i < n; i++) {
            WAVEINCAPSA caps;
            if (waveInGetDevCapsA(i, &caps, sizeof caps) == MMSYSERR_NOERROR) printf("%u: %s\n", i, caps.szPname);
        }
        return 0;
    }
    if (argc != 5) { printf("usage: micrec list | micrec <device#> <seconds> <rate> <out.wav>\n"); return 1; }

    UINT device = (UINT)atoi(argv[1]);
    DWORD seconds = (DWORD)atoi(argv[2]), rate = (DWORD)atoi(argv[3]);
    DWORD total = seconds * rate, got = 0;
    short *out = calloc(total, sizeof(short));

    WAVEFORMATEX fmt = { WAVE_FORMAT_PCM, 1, rate, rate * 2, 2, 16, 0 };
    HANDLE done_event = CreateEventA(NULL, FALSE, FALSE, NULL);
    HWAVEIN in;
    MMRESULT r = waveInOpen(&in, device, &fmt, (DWORD_PTR)done_event, 0, CALLBACK_EVENT);
    if (r != MMSYSERR_NOERROR) { printf("waveInOpen failed: %u\n", r); return 1; }

    DWORD frame = rate * BUFFER_MS / 1000;
    WAVEHDR hdr[BUFFERS];
    for (int i = 0; i < BUFFERS; i++) {
        ZeroMemory(&hdr[i], sizeof hdr[i]);
        hdr[i].lpData = malloc(frame * 2);
        hdr[i].dwBufferLength = frame * 2;
        waveInPrepareHeader(in, &hdr[i], sizeof hdr[i]);
        waveInAddBuffer(in, &hdr[i], sizeof hdr[i]);
    }
    waveInStart(in);

    // Collect finished buffers in order and hand each one straight back to the driver.
    int next = 0;
    while (got < total) {
        WaitForSingleObject(done_event, 1000);
        while ((hdr[next].dwFlags & WHDR_DONE) && got < total) {
            DWORD n = hdr[next].dwBytesRecorded / 2;
            if (n > total - got) n = total - got;
            memcpy(out + got, hdr[next].lpData, n * 2);
            got += n;
            hdr[next].dwFlags &= ~WHDR_DONE;
            waveInAddBuffer(in, &hdr[next], sizeof hdr[next]);
            next = (next + 1) % BUFFERS;
        }
    }
    waveInStop(in);
    waveInReset(in);
    waveInClose(in);
    write_wav(argv[4], out, got, rate);
    printf("recorded %lu samples at %lu Hz to %s\n", (unsigned long)got, (unsigned long)rate, argv[4]);
    return 0;
}
