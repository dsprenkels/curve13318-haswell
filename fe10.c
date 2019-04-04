#include "consts.h"
#include "fe10.h"
#include <inttypes.h>

void fe10_mul(fe10 h, const fe10 f_orig, const fe10 g_orig)
{
    fe10 f, g;
    for (unsigned int i = 0; i < 10; i++) f[i] = f_orig[i];
    for (unsigned int i = 0; i < 10; i++) g[i] = g_orig[i];

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

    // Carry immediately, this will be optimized in assembly
    fe10_carry(h);
}

void fe10_square(fe10 h, const fe10 f_orig)
{
    fe10 f;
    for (unsigned int i = 0; i < 10; i++) f[i] = f_orig[i];

    // Precompute (19*f_5, ..., 19*f_9)
    const uint64_t f19_5 = 19*f[5];
    const uint64_t f19_6 = 19*f[6];
    const uint64_t f19_7 = 19*f[7];
    const uint64_t f19_8 = 19*f[8];
    const uint64_t f19_9 = 19*f[9];

    // Precompute (2*f_0, ..., 2*f_9)
    const uint64_t f2_0 = 2*f[0];
    const uint64_t f2_1 = 2*f[1];
    const uint64_t f2_2 = 2*f[2];
    const uint64_t f2_3 = 2*f[3];
    const uint64_t f2_4 = 2*f[4];
    const uint64_t f2_5 = 2*f[5];
    const uint64_t f2_6 = 2*f[6];
    const uint64_t f2_7 = 2*f[7];
    const uint64_t f2_8 = 2*f[8];
    const uint64_t f2_9 = 2*f[9];
    
    // Precompute (4*f_1, 4*f_3, ... 4*f_9)
    const uint64_t f4_1 = 2*f2_1;
    const uint64_t f4_3 = 2*f2_3;
    const uint64_t f4_5 = 2*f2_5;
    const uint64_t f4_7 = 2*f2_7;

    // Round 1/10
    h[0] = f[0] * f[0];
    h[1] = f2_0 * f[1];
    h[2] = f2_0 * f[2];
    h[3] = f2_0 * f[3];
    h[4] = f2_0 * f[4];
    h[5] = f2_0 * f[5];
    h[6] = f2_0 * f[6];
    h[7] = f2_0 * f[7];
    h[8] = f2_0 * f[8];
    h[9] = f2_0 * f[9];
    
    // Round 2/10
    h[0] += f4_1 * f19_9;
    h[2] += f2_1 * f[1];
    h[3] += f2_1 * f[2];
    h[4] += f4_1 * f[3];
    h[5] += f2_1 * f[4];
    h[6] += f4_1 * f[5];
    h[7] += f2_1 * f[6];
    h[8] += f4_1 * f[7];
    h[9] += f2_1 * f[8];
    
    // Round 3/10
    h[0] += f2_2 * f19_8;
    h[1] += f2_2 * f19_9;
    h[4] += f[2] * f[2];
    h[5] += f2_2 * f[3];
    h[6] += f2_2 * f[4];
    h[7] += f2_2 * f[5];
    h[8] += f2_2 * f[6];
    h[9] += f2_2 * f[7];

    // Round 4/10
    h[0] += f4_3 * f19_7;
    h[1] += f2_3 * f19_8;
    h[2] += f4_3 * f19_9;
    h[6] += f2_3 * f[3];
    h[7] += f2_3 * f[4];
    h[8] += f4_3 * f[5];
    h[9] += f2_3 * f[6];
    
    // Round 5/10
    h[0] += f2_4 * f19_6;
    h[1] += f2_4 * f19_7;
    h[2] += f2_4 * f19_8;
    h[3] += f2_4 * f19_9;
    h[8] += f[4] * f[4];
    h[9] += f2_4 * f[5];

    // Round 6/10
    h[0] += f2_5 * f19_5;
    h[1] += f2_5 * f19_6;
    h[2] += f4_5 * f19_7;
    h[3] += f2_5 * f19_8;
    h[4] += f4_5 * f19_9;
    
    // Round 7/10
    h[2] += f[6] * f19_6;
    h[3] += f2_6 * f19_7;
    h[4] += f2_6 * f19_8;
    h[5] += f2_6 * f19_9;

    // Round 8/10
    h[4] += f2_7 * f19_7;
    h[5] += f2_7 * f19_8;
    h[6] += f4_7 * f19_9;
    
    // Round 9/10
    h[6] += f[8] * f19_8;
    h[7] += f2_8 * f19_9;
    
    // Round 10/10
    h[8] += f2_9 * f19_9;
    
    // Carry immediately, this will be optimized in assembly
    fe10_carry(h);
}

void fe10_carry(fe10 z)
{
    // Interleave two carry chains (7 rounds):
    //   - a: z[0] -> z[1] -> z[2] -> z[3] -> z[4] -> z[5] -> z[6]
    //   - b: z[5] -> z[6] -> z[7] -> z[8] -> z[9] -> z[0] -> z[1]
    //
    // Precondition:
    //   - *Every* limb in `z` must be (strictly) less than 2^63
    //
    z[1] += z[0] >> 26;         // Round 1a
    z[0] &= _MASK26;
    z[6] += z[5] >> 25;         // Round 1b
    z[5] &= _MASK25;
    z[2] += z[1] >> 25;         // Round 2a
    z[1] &= _MASK25;
    z[7] += z[6] >> 26;         // Round 2b
    z[6] &= _MASK26;
    z[3] += z[2] >> 26;         // Round 3a
    z[2] &= _MASK26;
    z[8] += z[7] >> 25;         // Round 3b
    z[7] &= _MASK25;
    z[4] += z[3] >> 25;         // Round 4a
    z[3] &= _MASK25;
    z[9] += z[8] >> 26;         // Round 4b
    z[8] &= _MASK26;
    z[5] += z[4] >> 26;         // Round 5a
    z[4] &= _MASK26;
    z[0] += 19 * (z[9] >> 25);  // Round 5b
    z[9] &= _MASK25;
    z[6] += z[5] >> 25;         // Round 6a
    z[5] &= _MASK25;
    z[1] += z[0] >> 26;         // Round 6b
    z[0] &= _MASK26;
}

void fe10_invert(fe10 out, const fe10 z)
{
	fe10 z2;
	fe10 z9;
	fe10 z11;
	fe10 z2_5_0;
	fe10 z2_10_0;
	fe10 z2_20_0;
	fe10 z2_50_0;
	fe10 z2_100_0;
	fe10 t0;
	fe10 t1;
	unsigned int i;

	/* 2 */ fe10_square(z2,z);
	/* 4 */ fe10_square(t1,z2);
	/* 8 */ fe10_square(t0,t1);
	/* 9 */ fe10_mul(z9,t0,z);
	/* 11 */ fe10_mul(z11,z9,z2);
	/* 22 */ fe10_square(t0,z11);
	/* 2^5 - 2^0 = 31 */ fe10_mul(z2_5_0,t0,z9);

	/* 2^6 - 2^1 */ fe10_square(t0,z2_5_0);
	/* 2^7 - 2^2 */ fe10_square(t1,t0);
	/* 2^8 - 2^3 */ fe10_square(t0,t1);
	/* 2^9 - 2^4 */ fe10_square(t1,t0);
	/* 2^10 - 2^5 */ fe10_square(t0,t1);
	/* 2^10 - 2^0 */ fe10_mul(z2_10_0,t0,z2_5_0);

	/* 2^11 - 2^1 */ fe10_square(t0,z2_10_0);
	/* 2^12 - 2^2 */ fe10_square(t1,t0);
	/* 2^20 - 2^10 */ for (i = 2;i < 10;i += 2) { fe10_square(t0,t1); fe10_square(t1,t0); }
	/* 2^20 - 2^0 */ fe10_mul(z2_20_0,t1,z2_10_0);

	/* 2^21 - 2^1 */ fe10_square(t0,z2_20_0);
	/* 2^22 - 2^2 */ fe10_square(t1,t0);
	/* 2^40 - 2^20 */ for (i = 2;i < 20;i += 2) { fe10_square(t0,t1); fe10_square(t1,t0); }
	/* 2^40 - 2^0 */ fe10_mul(t0,t1,z2_20_0);

	/* 2^41 - 2^1 */ fe10_square(t1,t0);
	/* 2^42 - 2^2 */ fe10_square(t0,t1);
	/* 2^50 - 2^10 */ for (i = 2;i < 10;i += 2) { fe10_square(t1,t0); fe10_square(t0,t1); }
	/* 2^50 - 2^0 */ fe10_mul(z2_50_0,t0,z2_10_0);

	/* 2^51 - 2^1 */ fe10_square(t0,z2_50_0);
	/* 2^52 - 2^2 */ fe10_square(t1,t0);
	/* 2^100 - 2^50 */ for (i = 2;i < 50;i += 2) { fe10_square(t0,t1); fe10_square(t1,t0); }
	/* 2^100 - 2^0 */ fe10_mul(z2_100_0,t1,z2_50_0);

	/* 2^101 - 2^1 */ fe10_square(t1,z2_100_0);
	/* 2^102 - 2^2 */ fe10_square(t0,t1);
	/* 2^200 - 2^100 */ for (i = 2;i < 100;i += 2) { fe10_square(t1,t0); fe10_square(t0,t1); }
	/* 2^200 - 2^0 */ fe10_mul(t1,t0,z2_100_0);

	/* 2^201 - 2^1 */ fe10_square(t0,t1);
	/* 2^202 - 2^2 */ fe10_square(t1,t0);
	/* 2^250 - 2^50 */ for (i = 2;i < 50;i += 2) { fe10_square(t0,t1); fe10_square(t1,t0); }
	/* 2^250 - 2^0 */ fe10_mul(t0,t1,z2_50_0);

	/* 2^251 - 2^1 */ fe10_square(t1,t0);
	/* 2^252 - 2^2 */ fe10_square(t0,t1);
	/* 2^253 - 2^3 */ fe10_square(t1,t0);
	/* 2^254 - 2^4 */ fe10_square(t0,t1);
	/* 2^255 - 2^5 */ fe10_square(t1,t0);
	/* 2^255 - 21 */ fe10_mul(out,t1,z11);
}

/*
Set z = if (z > p)  z - p,
        otherwise   z
*/
void fe10_reduce(fe10 z)
{
    /*
    `fe10_carry` ensures that an element `z` is always in range [0, 2^256⟩.
    So we either have to reduce by `p` if `z` ∈ [p, 2^256 - 38⟩  or by `2*p`
    if `z` ∈ [2^256 - 38, 2^256⟩.

    Instead of differentiating between these two conditionals we will perform
    a conditional reduction by `p` twice.

    TODO(dsprenkels) Implement this function using radix 2^51
    TODO(dsprenkels) Optimize carry ripple
    */
    uint64_t t, carry19, carry38, do_reduce;

    carry38 = z[0] + 38; // Round 1a
    carry38 >>= 26;
    carry19 = z[0] + 19; // Round 1b
    carry19 >>= 26;
    carry38 += z[1]; // Round 2a
    carry38 >>= 25;
    carry19 += z[1]; // Round 2b
    carry19 >>= 25;
    carry38 += z[2]; // Round 3a
    carry38 >>= 26;
    carry19 += z[2]; // Round 3b
    carry19 >>= 26;
    carry38 += z[3]; // Round 4a
    carry38 >>= 25;
    carry19 += z[3]; // Round 4b
    carry19 >>= 25;
    carry38 += z[4]; // Round 5a
    carry38 >>= 26;
    carry19 += z[4]; // Round 5b
    carry19 >>= 26;
    carry38 += z[5]; // Round 6a
    carry38 >>= 25;
    carry19 += z[5]; // Round 6b
    carry19 >>= 25;
    carry38 += z[6]; // Round 7a
    carry38 >>= 26;
    carry19 += z[6]; // Round 7b
    carry19 >>= 26;
    carry38 += z[7]; // Round 8a
    carry38 >>= 25;
    carry19 += z[7]; // Round 8b
    carry19 >>= 25;
    carry38 += z[8]; // Round 9a
    carry38 >>= 26;
    carry19 += z[8]; // Round 9b
    carry19 >>= 26;
    carry38 += z[9]; // Round 10a
    carry19 += z[9]; // Round 10b

    // Maybe add -2*p
    do_reduce = carry38 & 0x4000000;         // 2^26 or 0
    do_reduce <<= 37;                        // 2^63 or 0
    do_reduce = ((int64_t) do_reduce) >> 63; // 0xff... or 0x00...
    z[0] += do_reduce & 38;

    // Maybe add -p
    do_reduce ^= 0xFFFFFFFFFFFFFFFF;         // Do not reduce by 3*p!
    do_reduce &= carry19 & 0x2000000;        // 2^25 or 0
    z[9] += do_reduce;                       // Maybe add 2^255
    do_reduce <<= 38;                        // 2^63 or 0
    do_reduce = ((int64_t) do_reduce) >> 63; // 0xff... or 0x00...
    z[0] += do_reduce & 19;                  // Maybe add 19

    // In constract to `fe10_carry`, this function needs to carry the elements
    // `z` modulo `2^256`, i.e. *not* modulo `p`.
    t = z[0] & _REDMASK26;
    z[0] ^= t;
    z[1] += t >> 26;
    t = z[1] & _REDMASK25;
    z[1] ^= t;
    z[2] += t >> 25;
    t = z[2] & _REDMASK26;
    z[2] ^= t;
    z[3] += t >> 26;
    t = z[3] & _REDMASK25;
    z[3] ^= t;
    z[4] += t >> 25;
    t = z[4] & _REDMASK26;
    z[4] ^= t;
    z[5] += t >> 26;
    t = z[5] & _REDMASK25;
    z[5] ^= t;
    z[6] += t >> 25;
    t = z[6] & _REDMASK26;
    z[6] ^= t;
    z[7] += t >> 26;
    t = z[7] & _REDMASK25;
    z[7] ^= t;
    z[8] += t >> 25;
    t = z[8] & _REDMASK26;
    z[8] ^= t;
    z[9] += t >> 26;
    t = z[9] & _REDMASK26;
    z[9] ^= t;
}
