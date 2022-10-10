#include <stdio.h>
#include <stdlib.h>
#include <opus/opus.h>

#define SAMPLE_RATE 16000
#define CHANNELS 1
#define APPLICATION OPUS_APPLICATION_AUDIO

int main(void) {
    OpusEncoder* encoder;
    int err;

    encoder = opus_encoder_create(SAMPLE_RATE, CHANNELS, APPLICATION, &err);
    if (err < 0) {
        fprintf(stderr, "failed to create an encoder: %s\n", opus_strerror(err));
        return EXIT_FAILURE;
    }

    printf("Encoder: %p\n", encoder);

    return 0;
}