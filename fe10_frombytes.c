/*
Load a bytestring into a field element (fe10)

This file is adapted from the sandy2x implementation, which in turn notes:
> This file is basically ref10/fe10_frombytes.h.
*/

#include "fe10.h"

static uint64_t load_3(const uint8_t *in)
{
  uint64_t result;
  result = (uint64_t) in[0];
  result |= ((uint64_t) in[1]) << 8;
  result |= ((uint64_t) in[2]) << 16;
  return result;
}

static uint64_t load_4(const uint8_t *in)
{
  uint64_t result;
  result = (uint64_t) in[0];
  result |= ((uint64_t) in[1]) << 8;
  result |= ((uint64_t) in[2]) << 16;
  result |= ((uint64_t) in[3]) << 24;
  return result;
}

void fe10_frombytes(fe10 z, const uint8_t *s)
{
  uint64_t z0 = load_4(s);
  uint64_t z1 = load_3(s + 4) << 6;
  uint64_t z2 = load_3(s + 7) << 5;
  uint64_t z3 = load_3(s + 10) << 3;
  uint64_t z4 = load_3(s + 13) << 2;
  uint64_t z5 = load_4(s + 16);
  uint64_t z6 = load_3(s + 20) << 7;
  uint64_t z7 = load_3(s + 23) << 5;
  uint64_t z8 = load_3(s + 26) << 4;
  uint64_t z9 = load_3(s + 29) << 2;
  uint64_t carry0;
  uint64_t carry1;
  uint64_t carry2;
  uint64_t carry3;
  uint64_t carry4;
  uint64_t carry5;
  uint64_t carry6;
  uint64_t carry7;
  uint64_t carry8;
  uint64_t carry9;

  carry9 = z9 >> 25; z0 += carry9 * 19; z9 &= 0x1FFFFFF;
  carry1 = z1 >> 25; z2 += carry1; z1 &= 0x1FFFFFF;
  carry3 = z3 >> 25; z4 += carry3; z3 &= 0x1FFFFFF;
  carry5 = z5 >> 25; z6 += carry5; z5 &= 0x1FFFFFF;
  carry7 = z7 >> 25; z8 += carry7; z7 &= 0x1FFFFFF;

  carry0 = z0 >> 26; z1 += carry0; z0 &= 0x3FFFFFF;
  carry2 = z2 >> 26; z3 += carry2; z2 &= 0x3FFFFFF;
  carry4 = z4 >> 26; z5 += carry4; z4 &= 0x3FFFFFF;
  carry6 = z6 >> 26; z7 += carry6; z6 &= 0x3FFFFFF;
  carry8 = z8 >> 26; z9 += carry8; z8 &= 0x3FFFFFF;

  z[0] = z0;
  z[1] = z1;
  z[2] = z2;
  z[3] = z3;
  z[4] = z4;
  z[5] = z5;
  z[6] = z6;
  z[7] = z7;
  z[8] = z8;
  z[9] = z9;
}
