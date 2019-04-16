#include "fe51.h"
#include "ge.h"

void ge_tobytes(uint8_t *s, ge p)
{
    /*
    This function actually deals with the point at infinity, encoded as (0, 0).
    Namely, if `z` (`p[2]`) is zero, because of the implementation of
    `fe10_invert`, `z_inverse` will also be 0. And so, the coordinates that are
    encoded into `s` are 0.
    */
    fe51 x_projective, y_projective, z_projective, z_inverse, x_affine, y_affine;

    for (size_t i = 0; i < 5; i++) {
        x_projective.v[i] = p[0].v[2*i];
        x_projective.v[i] += p[0].v[2*i + 1] << 26;
    }
    for (size_t i = 0; i < 5; i++) {
        y_projective.v[i] = p[1].v[2*i];
        y_projective.v[i] += p[1].v[2*i + 1] << 26;
    }
    for (size_t i = 0; i < 5; i++) {
        z_projective.v[i] = p[2].v[2*i];
        z_projective.v[i] += p[2].v[2*i + 1] << 26;
    }

    // Convert to affine coordinates
    fe51_invert(&z_inverse, &z_projective);
    fe51_mul(&x_affine, &x_projective, &z_inverse);
    fe51_mul(&y_affine, &y_projective, &z_inverse);

    fe51_pack(&s[ 0], &x_affine);
    fe51_pack(&s[32], &y_affine);
}
