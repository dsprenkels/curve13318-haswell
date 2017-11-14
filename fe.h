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

typedef uint64_t fe51[10];

#define fe51_frombytes crypto_scalarmult_curve13318_ref_fe51_frombytes
#define fe51_mul crypto_scalarmult_curve13318_ref_fe51_mul
#define fe51_square crypto_scalarmult_curve13318_ref_fe51_square
#define fe51_carry crypto_scalarmult_curve13318_ref_fe51_carry
#define fe51_invert crypto_scalarmult_curve13318_ref_fe51_invert

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


#endif // CURVE13318_FE_H_
