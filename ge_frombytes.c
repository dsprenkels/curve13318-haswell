#include "ge.h"
#include <stdbool.h>

static bool ge_affine_point_on_curve(ge p)
{
    // Use the general curve equation to check if this point is on the curve
    // y^2 = x^3 - 3*x + 13318
    uint64_t nonzero = 0;
    fe51 lhs, rhs, t0;
    fe51_square(lhs, p[1]); // y^2
    fe51_square(t0, p[0]);  // x^2
    fe51_mul(rhs, t0, p[0]);// x^3
    fe51_zero(t0);          // 0
    fe51_add2p(t0);         // 0
    fe51_sub(t0, p[0]);     // -x
    fe51_add(rhs, t0);      // x^3 - x
    fe51_add(rhs, t0);      // x^3 - 2*x
    fe51_add(rhs, t0);      // x^3 - 3*x
    fe51_add_b(rhs);        // x^3 - 3*x + 13318
    fe51_carry(rhs);
    fe51_add2p(lhs);        // Still y^2
    fe51_sub(lhs, rhs);     // (==0) or (!=0) mod p
    fe51_carry(lhs);
    fe51_reduce(lhs);       // 0 or !0

    for (unsigned int i = 0; i < 10; i++) nonzero |= lhs[i];
    return nonzero == 0;
}

int ge_frombytes(ge p, const uint8_t *s)
{
    fe51_frombytes(p[0], &s[0]);
    fe51_frombytes(p[1], &s[32]);
    fe51_one(p[2]);



    if (! ge_affine_point_on_curve(p)) return -1;
    return 0;
}
