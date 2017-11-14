/*
Use the traditional addition chain from Peter.
*/

#include "fe.h"

void fe51_invert(fe51 out, const fe51 z)
{
	fe51 z2;
	fe51 z9;
	fe51 z11;
	fe51 z2_5_0;
	fe51 z2_10_0;
	fe51 z2_20_0;
	fe51 z2_50_0;
	fe51 z2_100_0;
	fe51 t0;
	fe51 t1;
	unsigned int i;

	/* 2 */ fe51_square(z2,z);
	/* 4 */ fe51_square(t1,z2);
	/* 8 */ fe51_square(t0,t1);
	/* 9 */ fe51_mul(z9,t0,z);
	/* 11 */ fe51_mul(z11,z9,z2);
	/* 22 */ fe51_square(t0,z11);
	/* 2^5 - 2^0 = 31 */ fe51_mul(z2_5_0,t0,z9);

	/* 2^6 - 2^1 */ fe51_square(t0,z2_5_0);
	/* 2^7 - 2^2 */ fe51_square(t1,t0);
	/* 2^8 - 2^3 */ fe51_square(t0,t1);
	/* 2^9 - 2^4 */ fe51_square(t1,t0);
	/* 2^10 - 2^5 */ fe51_square(t0,t1);
	/* 2^10 - 2^0 */ fe51_mul(z2_10_0,t0,z2_5_0);

	/* 2^11 - 2^1 */ fe51_square(t0,z2_10_0);
	/* 2^12 - 2^2 */ fe51_square(t1,t0);
	/* 2^20 - 2^10 */ for (i = 2;i < 10;i += 2) { fe51_square(t0,t1); fe51_square(t1,t0); }
	/* 2^20 - 2^0 */ fe51_mul(z2_20_0,t1,z2_10_0);

	/* 2^21 - 2^1 */ fe51_square(t0,z2_20_0);
	/* 2^22 - 2^2 */ fe51_square(t1,t0);
	/* 2^40 - 2^20 */ for (i = 2;i < 20;i += 2) { fe51_square(t0,t1); fe51_square(t1,t0); }
	/* 2^40 - 2^0 */ fe51_mul(t0,t1,z2_20_0);

	/* 2^41 - 2^1 */ fe51_square(t1,t0);
	/* 2^42 - 2^2 */ fe51_square(t0,t1);
	/* 2^50 - 2^10 */ for (i = 2;i < 10;i += 2) { fe51_square(t1,t0); fe51_square(t0,t1); }
	/* 2^50 - 2^0 */ fe51_mul(z2_50_0,t0,z2_10_0);

	/* 2^51 - 2^1 */ fe51_square(t0,z2_50_0);
	/* 2^52 - 2^2 */ fe51_square(t1,t0);
	/* 2^100 - 2^50 */ for (i = 2;i < 50;i += 2) { fe51_square(t0,t1); fe51_square(t1,t0); }
	/* 2^100 - 2^0 */ fe51_mul(z2_100_0,t1,z2_50_0);

	/* 2^101 - 2^1 */ fe51_square(t1,z2_100_0);
	/* 2^102 - 2^2 */ fe51_square(t0,t1);
	/* 2^200 - 2^100 */ for (i = 2;i < 100;i += 2) { fe51_square(t1,t0); fe51_square(t0,t1); }
	/* 2^200 - 2^0 */ fe51_mul(t1,t0,z2_100_0);

	/* 2^201 - 2^1 */ fe51_square(t0,t1);
	/* 2^202 - 2^2 */ fe51_square(t1,t0);
	/* 2^250 - 2^50 */ for (i = 2;i < 50;i += 2) { fe51_square(t0,t1); fe51_square(t1,t0); }
	/* 2^250 - 2^0 */ fe51_mul(t0,t1,z2_50_0);

	/* 2^251 - 2^1 */ fe51_square(t1,t0);
	/* 2^252 - 2^2 */ fe51_square(t0,t1);
	/* 2^253 - 2^3 */ fe51_square(t1,t0);
	/* 2^254 - 2^4 */ fe51_square(t0,t1);
	/* 2^255 - 2^5 */ fe51_square(t1,t0);
	/* 2^255 - 21 */ fe51_mul(out,t1,z11);
}
