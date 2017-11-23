/*
The type for a normal Field Element

In our case, the field is GF(2^255 - 19). The layout of this type is based on
[NEONCrypto2012]. It uses "radix 2^25.5", i.e. alternating 2^26 and 2^26.
In other words, an element (t :: fe) represents the integer:

t[0] + 2^26*t[1] + 2^51*t[2] + 2^77*t[3] + 2^102*t[4] + ... + 2^230*t[9]

[NEONCrypto2012]:
Bernstein, D. J. & Schwabe, P. Prouff, E. & Schaumont, P. (Eds.)
"NEON Crypto Cryptographic Hardware and Embedded Systems"
*/

#ifndef CURVE13318_FE_H_
#define CURVE13318_FE_H_

#include "consts.h"
#include <inttypes.h>

typedef uint64_t fe51[10];

#define fe51_frombytes crypto_scalarmult_curve13318_ref_fe51_frombytes
#define fe51_zero crypto_scalarmult_curve13318_ref_fe51_zero
#define fe51_one crypto_scalarmult_curve13318_ref_fe51_one
#define fe51_copy crypto_scalarmult_curve13318_ref_fe51_copy
#define fe51_add crypto_scalarmult_curve13318_ref_fe51_add
#define fe51_add2p crypto_scalarmult_curve13318_ref_fe51_add2p
#define fe51_mul crypto_scalarmult_curve13318_ref_fe51_mul
#define fe51_square crypto_scalarmult_curve13318_ref_fe51_square
#define fe51_carry crypto_scalarmult_curve13318_ref_fe51_carry
#define fe51_invert crypto_scalarmult_curve13318_ref_fe51_invert
#define fe51_add_b crypto_scalarmult_curve13318_ref_fe51_add_b
#define fe51_mul_b crypto_scalarmult_curve13318_ref_fe51_mul_b
#define fe51_reduce crypto_scalarmult_curve13318_ref_fe51_reduce

/*
Set a fe51 value to zero
*/
static inline void fe51_zero(fe51 z) {
    for (unsigned int i = 0; i < 10; i++) z[i] = 0;
}

/*
Set a fe51 value to one
*/
static inline void fe51_one(fe51 z) {
    z[0] = 1;
    for (unsigned int i = 1; i < 10; i++) z[i] = 0;
}

/*
Copy a fe51 value to another fe51 type
*/
static inline void fe51_copy(fe51 dest, fe51 src) {
    for (unsigned int i = 0; i < 10; i++) dest[i] = src[i];
}

/*
Add `rhs` into `z`
*/
static inline void fe51_add(fe51 z, fe51 rhs) {
    for (unsigned int i = 0; i < 10; i++) z[i] += rhs[i];
}

/*
Add 2*p to the field element `z`, this ensures that:
    - z limbs will be at least 2^26 resp. 2^25
*/
static inline void fe51_add2p(fe51 z) {
    z[0] += _2P0;
    z[1] += _2PRestB25;
    z[2] += _2PRestB26;
    z[3] += _2PRestB25;
    z[4] += _2PRestB26;
    z[5] += _2PRestB25;
    z[6] += _2PRestB26;
    z[7] += _2PRestB25;
    z[8] += _2PRestB26;
    z[9] += _2PRestB25;
}

/*
Subtract `rhs` from `z`. This function does *not* work if any of the resulting
limbs underflow! Ensure that this is not occurs by adding additional carry
rippling and using `fe51_add2p`.
*/
static inline void fe51_sub(fe51 z, fe51 rhs) {
    for (unsigned int i = 0; i < 10; i++) z[i] -= rhs[i];
}

/*
Parse 32 bytes into a `fe` type
*/
extern void fe51_frombytes(fe51 element, const uint8_t *bytes);

/*
Multiply two field elements,
*/
extern void fe51_mul(fe51 dest, const fe51 op1, const fe51 op2);

/*
Square a field element
*/
extern void fe51_square(fe51 dest, const fe51 element);

/*
Reduce this vectorized elements modulo 2^25.5
*/
extern void fe51_carry(fe51 element);

/*
Invert an element modulo 2^255 - 19
*/
extern void fe51_invert(fe51 dest, const fe51 element);

/*
Reduce an element s.t. the result is always in [0, 2^255-19⟩
*/

/*
Add 13318 to `z`
*/
static inline void fe51_add_b(fe51 z) {
    z[0] += CURVE13318_B;
}

/*
Multiply `z` by 13318
*/
static inline void fe51_mul_b(fe51 z) {
    for (unsigned int i = 0; i < 10; i++) z[i] *= CURVE13318_B;
    fe51_carry(z);
}

#endif // CURVE13318_FE_H_
