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
#include <unistd.h>

typedef struct {
    uint64_t v[10];
} fe10;

#define fe10_frombytes crypto_scalarmult_curve13318_avx2_fe10_frombytes
#define fe10_tobytes crypto_scalarmult_curve13318_avx2_fe10_tobytes
#define fe10_zero crypto_scalarmult_curve13318_avx2_fe10_zero
#define fe10_one crypto_scalarmult_curve13318_avx2_fe10_one
#define fe10_copy crypto_scalarmult_curve13318_avx2_fe10_copy
#define fe10_add crypto_scalarmult_curve13318_avx2_fe10_add
#define fe10_add2p crypto_scalarmult_curve13318_avx2_fe10_add2p
#define fe10_mul crypto_scalarmult_curve13318_avx2_fe10_mul
#define fe10_square crypto_scalarmult_curve13318_avx2_fe10_square
#define fe10_carry crypto_scalarmult_curve13318_avx2_fe10_carry
#define fe10_invert crypto_scalarmult_curve13318_avx2_fe10_invert
#define fe10_add_b crypto_scalarmult_curve13318_avx2_fe10_add_b
#define fe10_mul_b crypto_scalarmult_curve13318_avx2_fe10_mul_b
#define fe10_reduce crypto_scalarmult_curve13318_avx2_fe10_reduce

/*
Set a fe10 value to zero
*/
static inline void fe10_zero(fe10 *z) {
    for (size_t i = 0; i < 10; i++) z->v[i] = 0;
}

/*
Set a fe10 value to one
*/
static inline void fe10_one(fe10 *z) {
    z->v[0] = 1;
    for (size_t i = 1; i < 10; i++) z->v[i] = 0;
}

/*
Copy a fe10 value to another fe10 type
*/
static inline void fe10_copy(fe10 *restrict dest, const fe10 *restrict src) {
    for (size_t i = 0; i < 10; i++) dest->v[i] = src->v[i];
}

/*
Add `rhs` into `z`
*/
static inline void fe10_add(fe10 *z, fe10 *lhs, fe10 *rhs) {
    for (size_t i = 0; i < 10; i++) z->v[i] = lhs->v[i] + rhs->v[i];
}

/*
Add 2*p to the field element `z`, this ensures that:
    - z limbs will be at least 2^26 resp. 2^25
*/
static inline void fe10_add2p(fe10 *z) {
    z->v[0] += _2P0;
    z->v[1] += _2PRestB25;
    z->v[2] += _2PRestB26;
    z->v[3] += _2PRestB25;
    z->v[4] += _2PRestB26;
    z->v[5] += _2PRestB25;
    z->v[6] += _2PRestB26;
    z->v[7] += _2PRestB25;
    z->v[8] += _2PRestB26;
    z->v[9] += _2PRestB25;
}

/*
Add 4*p to the field element `z`. Useful when 2*p is not enough.
*/
static inline void fe10_add4p(fe10 *z) {
    z->v[0] += _4P0;
    z->v[1] += _4PRestB25;
    z->v[2] += _4PRestB26;
    z->v[3] += _4PRestB25;
    z->v[4] += _4PRestB26;
    z->v[5] += _4PRestB25;
    z->v[6] += _4PRestB26;
    z->v[7] += _4PRestB25;
    z->v[8] += _4PRestB26;
    z->v[9] += _4PRestB25;
}

/*
Subtract `rhs` from `z`. This function does *not* work if any of the resulting
limbs underflow! Ensure that this is not occurs by adding additional carry
rippling and using `fe10_add2p`.
*/
static inline void fe10_sub(fe10 *z, fe10 *lhs, fe10 *rhs) {
    for (size_t i = 0; i < 10; i++) z->v[i] = lhs->v[i] - rhs->v[i];
}

/*
Parse 32 bytes into a `fe` type
*/
extern void fe10_frombytes(fe10 *element, const uint8_t *bytes);

/*
Store a field element type into memory
*/
extern void fe10_tobytes(uint8_t *bytes, fe10 *element);

/*
Multiply two field elements,
*/
extern void fe10_mul(fe10 *dest, const fe10 *op1, const fe10 *op2);

/*
Square a field element
*/
extern void fe10_square(fe10 *dest, const fe10 *element);

/*
Reduce this vectorized elements modulo 2^25.5
*/
extern void fe10_carry(fe10 *element);

/*
Invert an element modulo 2^255 - 19
*/
extern void fe10_invert(fe10 *dest, const fe10 *element);

/*
Reduce an element s.t. the result is always in [0, 2^255-19⟩
*/
extern void fe10_reduce(fe10 *element);

/*
Add 13318 to `z`
*/
static inline void fe10_add_b(fe10 *z) {
    z->v[0] += CURVE13318_B;
}

/*
Multiply `z` by 13318
*/
static inline void fe10_mul_b(fe10 *z, fe10 *op) {
    for (size_t i = 0; i < 10; i++) z->v[i] = op->v[i] * CURVE13318_B;
    fe10_carry(z);
}

#endif // CURVE13318_FE_H_
