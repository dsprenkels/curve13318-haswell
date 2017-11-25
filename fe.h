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

typedef uint64_t fe[10];

#define fe_frombytes crypto_scalarmult_curve13318_ref_fe_frombytes
#define fe_tobytes crypto_scalarmult_curve13318_ref_fe_tobytes
#define fe_zero crypto_scalarmult_curve13318_ref_fe_zero
#define fe_one crypto_scalarmult_curve13318_ref_fe_one
#define fe_copy crypto_scalarmult_curve13318_ref_fe_copy
#define fe_add crypto_scalarmult_curve13318_ref_fe_add
#define fe_add2p crypto_scalarmult_curve13318_ref_fe_add2p
#define fe_mul crypto_scalarmult_curve13318_ref_fe_mul
#define fe_square crypto_scalarmult_curve13318_ref_fe_square
#define fe_carry crypto_scalarmult_curve13318_ref_fe_carry
#define fe_invert crypto_scalarmult_curve13318_ref_fe_invert
#define fe_add_b crypto_scalarmult_curve13318_ref_fe_add_b
#define fe_mul_b crypto_scalarmult_curve13318_ref_fe_mul_b
#define fe_reduce crypto_scalarmult_curve13318_ref_fe_reduce

/*
Set a fe value to zero
*/
static inline void fe_zero(fe z) {
    for (unsigned int i = 0; i < 10; i++) z[i] = 0;
}

/*
Set a fe value to one
*/
static inline void fe_one(fe z) {
    z[0] = 1;
    for (unsigned int i = 1; i < 10; i++) z[i] = 0;
}

/*
Copy a fe value to another fe type
*/
static inline void fe_copy(fe dest, fe src) {
    for (unsigned int i = 0; i < 10; i++) dest[i] = src[i];
}

/*
Add `rhs` into `z`
*/
static inline void fe_add(fe z, fe rhs) {
    for (unsigned int i = 0; i < 10; i++) z[i] += rhs[i];
}

/*
Add 2*p to the field element `z`, this ensures that:
    - z limbs will be at least 2^26 resp. 2^25
*/
static inline void fe_add2p(fe z) {
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
rippling and using `fe_add2p`.
*/
static inline void fe_sub(fe z, fe rhs) {
    for (unsigned int i = 0; i < 10; i++) z[i] -= rhs[i];
}

/*
Parse 32 bytes into a `fe` type
*/
extern void fe_frombytes(fe element, const uint8_t *bytes);

/*
Store a field element type into memory
*/
extern void fe_tobytes(uint8_t *bytes, fe element);

/*
Multiply two field elements,
*/
extern void fe_mul(fe dest, const fe op1, const fe op2);

/*
Square a field element
*/
extern void fe_square(fe dest, const fe element);

/*
Reduce this vectorized elements modulo 2^25.5
*/
extern void fe_carry(fe element);

/*
Invert an element modulo 2^255 - 19
*/
extern void fe_invert(fe dest, const fe element);

/*
Reduce an element s.t. the result is always in [0, 2^255-19⟩
*/
extern void fe_reduce(fe element);

/*
Add 13318 to `z`
*/
static inline void fe_add_b(fe z) {
    z[0] += CURVE13318_B;
}

/*
Multiply `z` by 13318
*/
static inline void fe_mul_b(fe z) {
    for (unsigned int i = 0; i < 10; i++) z[i] *= CURVE13318_B;
    fe_carry(z);
}

#endif // CURVE13318_FE_H_
