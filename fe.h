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

#include <inttypes.h>

typedef uint64_t fe[10];

#define fe_frombytes crypto_scalarmult_curve13318_ref_fe_frombytes
#define fe_mul crypto_scalarmult_curve13318_ref_fe_mul
#define fe_carry crypto_scalarmult_curve13318_ref_fe_carry

/*
Parse 32 bytes into a `fe` type
*/
extern void fe_frombytes(fe element, const uint8_t *bytes);

/*
Multiply two field elements,
*/
extern void fe_mul(fe dest, fe op1, fe op2);

/*
Reduce this vectorized elements modulo 2^25.5
*/
extern void fe_carry(fe element);

#endif // CURVE13318_FE_H_
