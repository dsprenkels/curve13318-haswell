/*
Group element in our curve E : y^2 = x^3 - 3*x + 13318

Because of the limitations of the Renes-Costello-Batina addition formulas, a
point on E is represented by its projective coordinates, i.e. (X : Y : Z).
*/

#ifndef CURVE13318_GE_H_
#define CURVE13318_GE_H_

#include "fe.h"

typedef fe ge[3];

#define ge_frombytes crypto_scalarmult_curve13318_ref_ge_frombytes
#define ge_tobytes crypto_scalarmult_curve13318_ref_ge_tobytes


/*
Parse a bytestring into a point on the curve

Arguments:
  - point   Output point
  - bytes   Input bytes
Returns:
  0 on succes, nonzero on failure
*/
int ge_frombytes(ge point, const uint8_t *bytes);

/*
Convert a projective point on the curve to its byte representation

Arguments:
  - bytes   Output bytes
  - point   Output point
Returns:
  0 on succes, nonzero on failure
*/
void ge_tobytes(uint8_t *bytes, ge point);

#endif // CURVE13318_GE_H_
