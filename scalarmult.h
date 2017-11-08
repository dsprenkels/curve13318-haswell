#ifndef CURVE13318_SCALARMULT_H_
#define CURVE13318_SCALARMULT_H_

#define crypto_scalarmult crypto_scalarmult_curve13318_ref_scalarmult

#include <inttypes.h>

/*
Constant time & lookup scalar multiplication over Curve13318

Arguments:
  - q   Pointer to the output point (64 bytes)
  - k   Pointer to the exponent (32 bytes)
  - p   Pointer to the input point (32 bytes)
*/
int scalarmult(uint8_t *out, const uint8_t *k, const uint8_t *p);

#endif // CURVE13318_SCALARMULT_H_
