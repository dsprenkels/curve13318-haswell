#include "ge.h"

void ge_tobytes(uint8_t *s, ge p)
{
    /*
    This function actually deals with the point at infinity, encoded as (0, 0).
    Namely, if `z` (`p[2]`) is zero, because of the implementation of
    `fe10_invert`, `z_inverse` will also be 0. And so, the coordinates that are
    encoded into `s` are 0.
    */
    fe10 x_affine, y_affine, z_inverse;

    // Convert to affine coordinates
    fe10_invert(z_inverse, p[2]);
    fe10_mul(x_affine, p[0], z_inverse);
    fe10_mul(y_affine, p[1], z_inverse);

    fe10_tobytes(&s[ 0], x_affine);
    fe10_tobytes(&s[32], y_affine);
}
