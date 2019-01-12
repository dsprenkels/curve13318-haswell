#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(ITERATIONS)
# define ITERATIONS 1000000
#endif

// Noop function for calculating base measurement
uint64_t _bench_blank(void);

// Array with pointers to benchmark functions
uint64_t(**_bench_fns)(void);

// Array with pointers to benchmark names
char** _bench_names;

// Amount of benchmarks
unsigned int _bench_fns_n;


int compare_uint64_ts(const void *ptrx, const void *ptry) {
    const uint64_t x = *(const uint64_t*)ptrx;
    const uint64_t y = *(const uint64_t*)ptry;
    if (x < y) return -1;
    if (x > y) return 1;
    return 0;
}

uint64_t measure_fn( uint64_t(*fn)(void) ) {
    uint64_t *measurements = calloc(ITERATIONS, sizeof(uint64_t));
    if (measurements == NULL) abort();

    for (size_t i = 0; i < ITERATIONS; i++) {
        measurements[i] = fn();
    }
    qsort(measurements, ITERATIONS, sizeof(uint64_t), compare_uint64_ts);
    const uint64_t median = measurements[ITERATIONS/2];
    free(measurements);
    return median;
}

static int get_max_strlen(char **strs, const unsigned int n) {
    int max_length = 0;
    for (size_t i = 0; i < n; i++) {
        const int len = strlen(strs[i]);
        if (len > max_length) max_length = len;
    }
    return max_length;
}

int main(void) {
    const uint64_t blank = measure_fn(_bench_blank);
    const int max_name_length = get_max_strlen(_bench_names, _bench_fns_n);

    // Measure benchmark
    printf("running %d benchmarks\n\n", _bench_fns_n);
    for (size_t i = 0; i < _bench_fns_n; i++) {
        const char* name = _bench_names[i];
        uint64_t(*fn)(void) = *_bench_fns[i];

        printf("%s", _bench_names[i]);
        for (size_t j = 0; j < max_name_length - strlen(name); j++) printf(" ");
        printf(" ... bench: ");
        printf("% 10ld cycles/op\n", measure_fn(fn) - blank);
    }
    printf("\n");
    return 0;
}
