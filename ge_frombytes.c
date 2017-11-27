#include "ge.h"
#include <stdbool.h>

static bool ge_affine_point_on_curve(ge p)
{
    // Use the general curve equation to check if this point is on the curve
    // y^2 = x^3 - 3*x + 13318
    uint64_t nonzero = 0;
    fe lhs, rhs, t0;
    fe_square(lhs, p[1]);  // y^2
    fe_square(t0, p[0]);   // x^2
    fe_mul(rhs, t0, p[0]); // x^3
    fe_zero(t0);           // 0
    fe_add2p(t0);          // 0
    fe_sub(t0, t0, p[0]);  // -x
    fe_add(rhs, rhs, t0);  // x^3 - x
    fe_add(rhs, rhs, t0);  // x^3 - 2*x
    fe_add(rhs, rhs, t0);  // x^3 - 3*x
    fe_add_b(rhs);         // x^3 - 3*x + 13318
    fe_carry(rhs);
    fe_add2p(lhs);         // Still y^2
    fe_sub(lhs, lhs, rhs); // (==0) or (!=0) mod p
    fe_carry(lhs);
    fe_reduce(lhs);        // 0 or !0

    for (unsigned int i = 0; i < 10; i++) nonzero |= lhs[i];
    return nonzero == 0;
}

int ge_frombytes(ge p, const uint8_t *s)
{
    fe_frombytes(p[0], &s[0]);
    fe_frombytes(p[1], &s[32]);

    // Handle point at infinity encoded by (0, 0)
    uint64_t infinity = 1;
    for (unsigned int i = 0; i < 10; i++) infinity &= p[0][i] == 0;
    for (unsigned int i = 0; i < 10; i++) infinity &= p[1][i] == 0;
    infinity = -((int64_t) infinity);
    uint64_t not_infinity = infinity ^ 0xFFFFFFFFFFFFFFFF;

    // Set y to 1 if we are at the point at infinity
    p[1][0] |= 1 & infinity;

    // Initialize z to 1 (or 0 if infinity)
    p[2][0] = 1 & not_infinity;
    for (unsigned int i = 1; i < 10; i++) p[2][i] = 0;

    // Check if this point is valid
    if (not_infinity & !ge_affine_point_on_curve(p)) return -1;
    return 0;
}
