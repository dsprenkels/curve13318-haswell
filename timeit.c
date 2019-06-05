// Measure the scalar multiplication cycle count

#include "scalarmult.h"
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

const size_t N = 100000;


static __inline__ unsigned long long rdtsc(void)
{
    unsigned hi, lo;
    __asm__ __volatile__ ("rdtsc" : "=a"(lo), "=d"(hi));
    return ( (unsigned long long)lo)|( ((unsigned long long)hi)<<32 );
}

static void __attribute__ ((noinline)) blank_benchmark(void) 
{
    // Prevent the compiler from optimizing out calls to this function
    __asm__ __volatile__ ("");
}

static int compar_double(const void *a_ptr, const void *b_ptr) {
    const double a = *(const double*)a_ptr;
    const double b = *(const double*)b_ptr;
    return (int)(a - b);
}

static double median(double *base, size_t nitems) {
    qsort(base, nitems, sizeof(base[0]), compar_double);
    
    if (nitems == 0) {
        return -1;
    }
    const size_t m = nitems / 2 - 1;
    if (nitems % 2 == 0) {
        return (base[m] + base[m+1]) / 2;
    }
    return base[m];
}

int main(int argc, char *argv[])
{
    uint8_t out[64] = {0};
    const uint8_t key[32] = {1};
    const uint8_t in[64] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 179, 43, 106, 247, 206, 176, 201, 77, 137, 224, 122, 176, 76, 93, 29, 69, 190, 137, 17, 103, 105, 172, 236, 172, 225, 72, 243, 7, 94, 128, 240, 17};
    
    // Estimate the (systematic) error of the measurement device
    double blank_measurements[N];
    for (size_t i = 0; i < N; i++) {
        __asm__ __volatile__ ("lfence");
        const unsigned long long start = rdtsc();
        blank_benchmark();
        blank_measurements[i] = (double)(rdtsc() - start);
    }
    
    // Measure the scalarmult routine
    double sample_measurements[N];
    for (size_t i = 0; i < N; i++) {
        __asm__ __volatile__ ("lfence");
        const unsigned long long start = rdtsc();
        int ret = crypto_scalarmult(out, key, in);
        sample_measurements[i] = (double)(rdtsc() - start);
        assert(ret == 0);
    }

    const double blank = median(blank_measurements, N);
    const double sample = median(sample_measurements, N);
    printf("MEASURED BLANK: %.0f\n", blank);
    printf("MEASURED SAMPLE: %.0f\n", sample);
    printf("----------------------------------------------------------------------\n");
    printf("MEASURED DIFF: %.0f\n", sample - blank);
    printf("  i.e. %.0fkcc\n", (sample - blank)/1000);
    return 0;
}
