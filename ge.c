/*
Cointains arithmetic for the group element, i.e. points on the curve.
This code uses the Renes-Costello-Batina addition formulas, for fast and
secure double-and-adding.
*/

#include "fe10.h"
#include "ge.h"

void ge_add(ge p3, const ge p1, const ge p2)
{
    fe10 x1, y1, z1, x2, y2, z2, x3, y3, z3, t0, t1, t2, t3, t4;
    fe10_copy(&x1, &p1[0]);
    fe10_copy(&y1, &p1[1]);
    fe10_copy(&z1, &p1[2]);
    fe10_copy(&x2, &p2[0]);
    fe10_copy(&y2, &p2[1]);
    fe10_copy(&z2, &p2[2]);

    /*
    A couple of times you will see me add 2*p twice. In this case I will be
    subtracting a field element of which I know it is smaller than 4*p, but
    may be larger than 2*p. In this case, adding 2*p another time is cheaper
    than a carry ripple. Obviously, when *really* optimising for performance,
    this should be implemented by adding 4*p in one go.
    */
    /*   #: Instruction number as mentioned in the paper */
             fe10_mul(&t0, &x1, &x2);
             fe10_mul(&t1, &y1, &y2);
             fe10_mul(&t2, &z1, &z2);
             fe10_add(&t3, &x1, &y1);
    /*  5 */ fe10_add(&t4, &x2, &y2);
             fe10_mul(&t3, &t3, &t4);
             fe10_add(&t4, &t0, &t1);
             fe10_add2p(&t3); fe10_sub(&t3, &t3, &t4);
             fe10_add(&t4, &y1, &z1);
    /* 10 */ fe10_add(&x3, &y2, &z2);
             fe10_mul(&t4, &t4, &x3);
             fe10_add(&x3, &t1, &t2);
             fe10_add4p(&t4); fe10_sub(&t4, &t4, &x3);
             fe10_add(&x3, &x1, &z1);
    /* 15 */ fe10_add(&y3, &x2, &z2);
             fe10_mul(&x3, &x3, &y3);
             fe10_add(&y3, &t0, &t2);
             fe10_add2p(&x3); fe10_sub(&y3, &x3, &y3);
             fe10_mul_b(&z3, &t2);
    /* 20 */ fe10_add2p(&y3); fe10_sub(&x3, &y3, &z3);
             fe10_add(&z3, &x3, &x3);
             fe10_add(&x3, &x3, &z3); fe10_carry(&x3);
             fe10_add2p(&t1); fe10_sub(&z3, &t1, &x3); fe10_carry(&t1); fe10_carry(&z3);
             fe10_add(&x3, &t1, &x3);
    /* 25 */ fe10_mul_b(&y3, &y3);
             fe10_add(&t1, &t2, &t2);
             fe10_add(&t2, &t1, &t2); fe10_carry(&t2);
             fe10_add4p(&y3); fe10_sub(&y3, &y3, &t2);
             fe10_sub(&y3, &y3, &t0); fe10_carry(&y3);
    /* 30 */ fe10_add(&t1, &y3, &y3);
             fe10_add(&y3, &t1, &y3);
             fe10_add(&t1, &t0, &t0);
             fe10_add(&t0, &t1, &t0);
             fe10_add2p(&t0); fe10_sub(&t0, &t0, &t2);
    /* 35 */ fe10_mul(&t1, &t4, &y3);
             fe10_mul(&t2, &t0, &y3);
             fe10_mul(&y3, &x3, &z3);
             fe10_add(&y3, &y3, &t2);
             fe10_mul(&x3, &x3, &t3);
    /* 40 */ fe10_add2p(&x3); fe10_sub(&x3, &x3, &t1); fe10_carry(&x3);
             fe10_mul(&z3, &z3, &t4);
             fe10_mul(&t1, &t3, &t0);
             fe10_add(&z3, &z3, &t1);

    fe10_copy(&p3[0], &x3);
    fe10_copy(&p3[1], &y3);
    fe10_copy(&p3[2], &z3);
}

void ge_double(ge p3, const ge p)
{
    fe10 x, y, z, x3, y3, z3, t0, t1, t2, t3;
    fe10_copy(&x, &p[0]);
    fe10_copy(&y, &p[1]);
    fe10_copy(&z, &p[2]);

    /*
    A couple of times you will see me add 2*p twice. In this case I will be
    subtracting a field element of which I know it is smaller than 4*p, but
    may be larger than 2*p. In this case, adding 2*p another time is cheaper
    than a carry ripple.
    */
    /*   #: Instruction number as mentioned in the paper */
             fe10_square(&t0, &x);
             fe10_square(&t1, &y);
             fe10_square(&t2, &z);
             fe10_mul(&t3, &x, &y);
    /*  5 */ fe10_add(&t3, &t3, &t3);
             fe10_mul(&z3, &x, &z);
             fe10_add(&z3, &z3, &z3); fe10_carry(&z3);
             fe10_mul_b(&y3, &t2);
             fe10_add2p(&y3); fe10_sub(&y3, &y3, &z3);
    /* 10 */ fe10_add(&x3, &y3, &y3);
             fe10_add(&y3, &x3, &y3); fe10_carry(&y3);
             fe10_add2p(&t1); fe10_sub(&x3, &t1, &y3);
             fe10_add(&y3, &t1, &y3);
             fe10_mul(&y3, &x3, &y3);
    /* 15 */ fe10_mul(&x3, &x3, &t3);
             fe10_add(&t3, &t2, &t2);
             fe10_add(&t2, &t2, &t3); fe10_carry(&t2);
             fe10_mul_b(&z3, &z3);
             fe10_add2p(&z3); fe10_sub(&z3, &z3, &t2);
    /* 20 */ fe10_add2p(&z3); fe10_sub(&z3, &z3, &t0);
             fe10_carry(&z3); fe10_add(&t3, &z3, &z3);
             fe10_add(&z3, &z3, &t3);
             fe10_add(&t3, &t0, &t0);
             fe10_add(&t0, &t3, &t0);
    /* 25 */ fe10_add2p(&t0); fe10_sub(&t0, &t0, &t2);
             fe10_mul(&t0, &t0, &z3);
             fe10_add(&y3, &y3, &t0);
             fe10_mul(&t0, &y, &z);
             fe10_add(&t0, &t0, &t0);
    /* 30 */ fe10_mul(&z3, &t0, &z3);
             fe10_add2p(&x3); fe10_sub(&x3, &x3, &z3);
             fe10_mul(&z3, &t0, &t1);
             fe10_add(&z3, &z3, &z3);
             fe10_add(&z3, &z3, &z3);

    fe10_copy(&p3[0], &x3);
    fe10_copy(&p3[1], &y3);
    fe10_copy(&p3[2], &z3);
}
