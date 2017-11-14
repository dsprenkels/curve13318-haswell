/*
Group element in our curve E : y^2 = x^3 - 3*x + 13318

Because of the limitations of the Renes-Costello-Batina addition formulas, a
point on E is represented by its projective coordinates, i.e. (X : Y : Z).
*/

#ifndef CURVE13318_GE_H_
#define CURVE13318_GE_H_

#include "fe.h"

typedef fe51 ge[3];
typedef fe51 ge_affine[2];

#define ge_frombytes crypto_scalarmult_curve13318_ref_ge_frombytes


/*
Parse a bytestring into a point on the curve

Arguments:
  - point   Output point
  - bytes   Input bytes
Returns:
  0 on succes, nonzero on failure
*/
int ge_frombytes(ge point, const uint8_t *bytes);

#endif // CURVE13318_GE_H_
