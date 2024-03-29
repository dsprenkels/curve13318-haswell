#include "ge.h"
#include <stdbool.h>

static bool ge_affine_point_on_curve(ge p)
{
    // TODO(dsprenkels) Use fe51 arithmetic here

    // Use the general curve equation to check if this point is on the curve
    // y^2 = x^3 - 3*x + 13318
    uint64_t nonzero = 0;
    fe10 lhs, rhs, t0;
    fe10_square(&lhs, &p[1]);   // y^2
    fe10_square(&t0, &p[0]);    // x^2
    fe10_mul(&rhs, &t0, &p[0]); // x^3
    fe10_zero(&t0);             // 0
    fe10_add2p(&t0);            // 0
    fe10_sub(&t0, &t0, &p[0]);  // -x
    fe10_add(&rhs, &rhs, &t0);  // x^3 - x
    fe10_add(&rhs, &rhs, &t0);  // x^3 - 2*x
    fe10_add(&rhs, &rhs, &t0);  // x^3 - 3*x
    fe10_add_b(&rhs);           // x^3 - 3*x + 13318
    fe10_carry(&rhs);
    fe10_add2p(&lhs);           // Still y^2
    fe10_sub(&lhs, &lhs, &rhs); // (==0) or (!=0) mod p
    fe10_carry(&lhs);
    fe10_reduce(&lhs);          // 0 or !0

    for (unsigned int i = 0; i < 10; i++) nonzero |= lhs.v[i];
    return nonzero == 0;
}

int ge_frombytes(ge p, const uint8_t *s)
{
    fe10_frombytes(&p[0], &s[0]);
    fe10_frombytes(&p[1], &s[32]);

    // Initialize z to 1
    p[2].v[0] = 1;
    for (unsigned int i = 1; i < 10; i++) p[2].v[i] = 0;

    // Check if this point is valid
    if (!ge_affine_point_on_curve(p)) return -1;
    return 0;
}
