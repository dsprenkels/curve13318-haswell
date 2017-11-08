#include "fe.h"
#include <inttypes.h>

void fe_mul(fe h, fe f, fe g)
{
    // Precompute (19*g_1, ..., 19*g_9)
    const uint64_t g19_1 = 19*g[1];
    const uint64_t g19_2 = 19*g[2];
    const uint64_t g19_3 = 19*g[3];
    const uint64_t g19_4 = 19*g[4];
    const uint64_t g19_5 = 19*g[5];
    const uint64_t g19_6 = 19*g[6];
    const uint64_t g19_7 = 19*g[7];
    const uint64_t g19_8 = 19*g[8];
    const uint64_t g19_9 = 19*g[9];

    // Precompute (2*f_1, 2*f_3, ... 2*f_9)
    const uint64_t f2_1 = 2*f[1];
    const uint64_t f2_3 = 2*f[3];
    const uint64_t f2_5 = 2*f[5];
    const uint64_t f2_7 = 2*f[7];
    const uint64_t f2_9 = 2*f[9];

    // Compute multiplication, round 1/10
    for (int i = 0; i < 10; i++) h[i]  = f[0] * g[i];

    // Round 2/10
    h[0] += f2_1 * g19_9;
    h[1] += f[1] * g[0];
    h[2] += f2_1 * g[1];
    h[3] += f[1] * g[2];
    h[4] += f2_1 * g[3];
    h[5] += f[1] * g[4];
    h[6] += f2_1 * g[5];
    h[7] += f[1] * g[6];
    h[8] += f2_1 * g[7];
    h[9] += f[1] * g[8];

    // Round 3/10
    h[0] += f[2] * g19_8;
    h[1] += f[2] * g19_9;
    h[2] += f[2] * g[0];
    h[3] += f[2] * g[1];
    h[4] += f[2] * g[2];
    h[5] += f[2] * g[3];
    h[6] += f[2] * g[4];
    h[7] += f[2] * g[5];
    h[8] += f[2] * g[6];
    h[9] += f[2] * g[7];

    // Round 4/10
    h[0] += f2_3 * g19_7;
    h[1] += f[3] * g19_8;
    h[2] += f2_3 * g19_9;
    h[3] += f[3] * g[0];
    h[4] += f2_3 * g[1];
    h[5] += f[3] * g[2];
    h[6] += f2_3 * g[3];
    h[7] += f[3] * g[4];
    h[8] += f2_3 * g[5];
    h[9] += f[3] * g[6];

    // Round 5/10
    h[0] += f[4] * g19_6;
    h[1] += f[4] * g19_7;
    h[2] += f[4] * g19_8;
    h[3] += f[4] * g19_9;
    h[4] += f[4] * g[0];
    h[5] += f[4] * g[1];
    h[6] += f[4] * g[2];
    h[7] += f[4] * g[3];
    h[8] += f[4] * g[4];
    h[9] += f[4] * g[5];

    // Round 6/10
    h[0] += f2_5 * g19_5;
    h[1] += f[5] * g19_6;
    h[2] += f2_5 * g19_7;
    h[3] += f[5] * g19_8;
    h[4] += f2_5 * g19_9;
    h[5] += f[5] * g[0];
    h[6] += f2_5 * g[1];
    h[7] += f[5] * g[2];
    h[8] += f2_5 * g[3];
    h[9] += f[5] * g[4];

    // Round 7/10
    h[0] += f[6] * g19_4;
    h[1] += f[6] * g19_5;
    h[2] += f[6] * g19_6;
    h[3] += f[6] * g19_7;
    h[4] += f[6] * g19_8;
    h[5] += f[6] * g19_9;
    h[6] += f[6] * g[0];
    h[7] += f[6] * g[1];
    h[8] += f[6] * g[2];
    h[9] += f[6] * g[3];

    // Round 8/10
    h[0] += f2_7 * g19_3;
    h[1] += f[7] * g19_4;
    h[2] += f2_7 * g19_5;
    h[3] += f[7] * g19_6;
    h[4] += f2_7 * g19_7;
    h[5] += f[7] * g19_8;
    h[6] += f2_7 * g19_9;
    h[7] += f[7] * g[0];
    h[8] += f2_7 * g[1];
    h[9] += f[7] * g[2];

    // Round 9/10
    h[0] += f[8] * g19_2;
    h[1] += f[8] * g19_3;
    h[2] += f[8] * g19_4;
    h[3] += f[8] * g19_5;
    h[4] += f[8] * g19_6;
    h[5] += f[8] * g19_7;
    h[6] += f[8] * g19_8;
    h[7] += f[8] * g19_9;
    h[8] += f[8] * g[0];
    h[9] += f[8] * g[1];

    // Round 10/10
    h[0] += f2_9 * g19_1;
    h[1] += f[9] * g19_2;
    h[2] += f2_9 * g19_3;
    h[3] += f[9] * g19_4;
    h[4] += f2_9 * g19_5;
    h[5] += f[9] * g19_6;
    h[6] += f2_9 * g19_7;
    h[7] += f[9] * g19_8;
    h[8] += f2_9 * g19_9;
    h[9] += f[9] * g[0];
}

void fe_carry(fe h)
{
    // Interleave two carry chains (7 rounds):
    //   - a: h[0] -> h[1] -> h[2] -> h[3] -> h[4] -> h[5] -> h[6]
    //   - b: h[5] -> h[6] -> h[7] -> h[8] -> h[9] -> h[0] -> h[1]
    static const uint64_t mask25 = 0xfffffffffe000000;
    static const uint64_t mask26 = 0xfffffffffc000000;

    uint64_t tmp;
    tmp = h[0] & mask26; // Round 1a
    h[0] ^= tmp;
    h[1] += tmp >> 26;
    tmp = h[5] & mask25;  // Round 1b
    h[5] ^= tmp;
    h[6] += tmp >> 25;
    tmp = h[1] & mask25; // Round 2a
    h[1] ^= tmp;
    h[2] += tmp >> 25;
    tmp = h[6] & mask26; // Round 2b
    h[6] ^= tmp;
    h[7] += tmp >> 26;
    tmp = h[2] & mask26; // Round 3a
    h[2] ^= tmp;
    h[3] += tmp >> 26;
    tmp = h[7] & mask25; // Round 3b
    h[7] ^= tmp;
    h[8] += tmp >> 25;
    tmp = h[3] & mask25; // Round 4a
    h[3] ^= tmp;
    h[4] += tmp >> 25;
    tmp = h[8] & mask26; // Round 4b
    h[8] ^= tmp;
    h[9] += tmp >> 26;
    tmp = h[4] & mask26; // Round 5a
    h[4] ^= tmp;
    h[5] += tmp >> 26;
    tmp = h[9] & mask26; // Round 5b
    h[9] ^= tmp;
    h[0] += 38 * (tmp >> 26);
    tmp = h[5] & mask25; // Round 6a
    h[5] ^= tmp;
    h[6] += tmp >> 25;
    tmp = h[0] & mask26; // Round 6b
    h[0] ^= tmp;
    h[1] += tmp >> 26;
    tmp = h[6] & mask26; // Round 7a
    h[6] ^= tmp;
    h[7] += tmp >> 26;
    tmp = h[1] & mask25; // Round 7b :)
    h[1] ^= tmp;
    h[2] += tmp >> 25;
}
