#include "ge.h"

// static bool point_on_curve(ge)
// {
//     fe X, Y, Z;
// }

int ge_frombytes(ge p, const uint8_t *s)
{
    fe_frombytes(p[0], &s[0]);
    fe_frombytes(p[1], &s[32]);
    p[2][0] = 1;
    for (int i = 1; i < 10; i++) p[2][i] = 0;

    // TODO(dsprenkels) Check if this point is valid

    return 0;
}
