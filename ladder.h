#ifndef CURVE13318_LADDER_H_
#define CURVE13318_LADDER_H_

#define ladder crypto_scalarmult_curve13318_avx2_ladder

#include "ge.h"
#include <inttypes.h>

/*
Constant double-and-add algorithm for E : x^3 - 3x + 13318


crypto_scalarmult_curve13318_avx2_ladder:
    ; Double-and-add ladder for shared secret point multiplication
    ;
    ; Arguments:
    ;   ge q:               [rdi]
    ;   uint8_t *windows:   [rsi]
    ;   ge ptable[16]:      [rdx]
    ;

Arguments:
  - q           Output ge element, should be initialized to 𝒪 or P, depending
                on the zeroth window.
  - windows     51 uint8_t windows
  - p           Lookup table
*/
void crypto_scalarmult_curve13318_avx2_ladder(ge_opt q, uint8_t windows[51], ge_opt ptable[16]);

#endif // CURVE13318_LADDER_H_
