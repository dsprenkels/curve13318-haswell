#!/bin/echo Please execute with sage -python
# *-* encoding: utf-8 *-*

import ctypes
import io
import os
import sys
import unittest

from sage.all import *

from hypothesis import assume, example, given, note, settings, \
                       strategies as st, unlimited, HealthCheck

P = 2**255 - 19
F = FiniteField(P)
E = EllipticCurve(F, [-3, 13318])

# Initialize hypothesis
settings.register_profile('default', settings())
settings.register_profile('ci', settings(max_examples=1000, timeout=unlimited))
if os.getenv('CI') != None:
    settings.load_profile('ci')
else:
    settings.load_profile('default')

# Load shared libcurve13318 library
curve13318 = ctypes.CDLL(os.path.join(os.path.abspath('.'), 'libcurve13318.so'))

# Define functions
fe10_frombytes = curve13318.crypto_scalarmult_curve13318_avx2_fe10_frombytes
fe10_frombytes.argtypes = [ctypes.c_uint64 * 10, ctypes.c_ubyte * 32]
fe10_tobytes = curve13318.crypto_scalarmult_curve13318_avx2_fe10_tobytes
fe10_tobytes.argtypes = [ctypes.c_ubyte * 32, ctypes.c_uint64 * 10]
fe10_mul = curve13318.crypto_scalarmult_curve13318_avx2_fe10_mul
fe10_mul.argtypes = [ctypes.c_uint64 * 10] * 3
fe10_carry = curve13318.crypto_scalarmult_curve13318_avx2_fe10_carry
fe10_carry.argtypes = [ctypes.c_uint64 * 10]
fe10_square = curve13318.crypto_scalarmult_curve13318_avx2_fe10_square
fe10_square.argtypes = [ctypes.c_uint64 * 10] * 2
fe10_invert = curve13318.crypto_scalarmult_curve13318_avx2_fe10_invert
fe10_invert.argtypes = [ctypes.c_uint64 * 10] * 2
fe10_reduce = curve13318.crypto_scalarmult_curve13318_avx2_fe10_reduce
fe10_reduce.argtypes = [ctypes.c_uint64 * 10]
ge_frombytes = curve13318.crypto_scalarmult_curve13318_avx2_ge_frombytes
ge_frombytes.argtypes = [ctypes.c_uint64 * 30, ctypes.c_ubyte * 64]
ge_tobytes = curve13318.crypto_scalarmult_curve13318_avx2_ge_tobytes
ge_tobytes.argtypes = [ctypes.c_ubyte * 64, ctypes.c_uint64 * 30]
ge_add = curve13318.crypto_scalarmult_curve13318_avx2_ge_add
ge_add.argtypes = [ctypes.c_uint64 * 30] * 3


class TestFE(unittest.TestCase):
    def setUp(self):
        F = FiniteField(P)

    @staticmethod
    def frombytes(bytelist):
        h = make_fe10()
        c_bytes = (ctypes.c_ubyte * 32)(0)

        fe10_value = 0
        for i, b in enumerate(bytelist):
            c_bytes[i] = b
            fe10_value += b * 2**(8*i)
        fe10_frombytes(h, c_bytes)
        return h, fe10_value

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_frombytes(self, bytelist):
        h, expected = self.frombytes(bytelist)
        actual = fe10_val(h) % P
        expected %= P
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_tobytes(self, limbs):
        h = make_fe10(limbs)
        expected = fe10_val(h) % P
        c_bytes = (ctypes.c_ubyte * 32)(0)
        fe10_carry(h)
        fe10_tobytes(c_bytes, h)
        actual = 0
        for i, b in enumerate(c_bytes):
            actual += b * 2**(8*i)
        self.assertEqual(actual, expected)

    @given(st.integers(0, 2**255 - 1))
    def test_tobytes(self, z):
        z = F(z)

        # Encode the number in its C representation
        shift = 0
        limbs = [0]*10
        for i in range(10):
            mask_width = 26 if i % 2 == 0 else 25
            limbs[i] = (2**mask_width - 1) & (z.lift() >> shift)
            shift += mask_width
        c_fe = make_fe10(limbs)
        c_bytes = (ctypes.c_ubyte * 32)(0)
        fe10_tobytes(c_bytes, c_fe)

        actual_z = 0
        for i, b in enumerate(c_bytes):
            actual_z += b * 2**(8*i)
        self.assertEqual(actual_z, z)

    @given(st.tuples(
        st.lists(st.integers(0, 255), min_size=32, max_size=32),
        st.lists(st.integers(0, 255), min_size=32, max_size=32)))
    def test_mul(self, bytelists):
        f, f_val = self.frombytes(bytelists[0])
        g, g_val = self.frombytes(bytelists[1])
        expected = F(f_val * g_val)
        h = make_fe10()
        fe10_mul(h, f, g)
        actual = F(fe10_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_square(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = F(f_val**2)
        h = make_fe10()
        fe10_square(h, f)
        actual = F(fe10_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_carry(self, limbs):
        f = make_fe10(limbs)
        expected = F(fe10_val(f))
        fe10_carry(f)
        actual = fe10_val(f)
        assert(actual < 2**256)
        self.assertEqual(F(actual), expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_invert(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = F(f_val)**-1 if f_val != 0 else 0
        h = make_fe10()
        fe10_invert(h, f)
        actual = F(fe10_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    # Value that that is in [p, 2^255⟩
    @example([2**26 -19, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**25 - 1 ])
    # Value that that is in [2*p, 2^256⟩
    @example([2**26 -38, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**26 - 1 ])
    def test_reduce(self, limbs):
        f = make_fe10(limbs)
        expected = F(fe10_val(f))
        fe10_carry(f)
        fe10_reduce(f)
        actual = fe10_val(f)
        self.assertEqual(actual, expected)


class TestGE(unittest.TestCase):
    @staticmethod
    def encode_point(x, y, z):
        """Encode a point in its C representation"""
        shift = 0
        x_limbs, y_limbs, z_limbs = [0]*10, [0]*10, [0]*10
        for i in range(10):
            mask_width = 26 if i % 2 == 0 else 25
            x_limbs[i] = (2**mask_width - 1) & (x.lift() >> shift)
            y_limbs[i] = (2**mask_width - 1) & (y.lift() >> shift)
            z_limbs[i] = (2**mask_width - 1) & (z.lift() >> shift)
            shift += mask_width

        p = (ctypes.c_uint64 * 30)(0)
        for i, limb in enumerate(x_limbs + y_limbs + z_limbs):
            p[i] = limb
        return p

    def decode_point(self, point):
        x = fe10_val(point[ 0:10])
        y = fe10_val(point[10:20])
        z = fe10_val(point[20:30])
        return (x, y, z)

    def decode_bytes(self, c_bytes):
        x, y = F(0), F(0)
        for i, b in enumerate(c_bytes[0:32]):
            x += b * 2**(8*i)
        for i, b in enumerate(c_bytes[32:64]):
            y += b * 2**(8*i)
        return x, y

    def point_to_bytes(self, x, y):
        """Encode the numbers as byte input"""
        # Encode the numbers as byte input
        c_bytes = (ctypes.c_ubyte * 64)(0)
        for i in range(32):
            c_bytes[i] = (x >> (8*i)) & 0xFF
        for i in range(32):
            c_bytes[32+i] = (y >> (8*i)) & 0xFF
        return c_bytes

    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]))
    @example(0, 0, 1) # point at infinity
    @example(0, P, 1)
    @example(0, 2*P, 1)
    def test_frombytes(self, x, y_suggest, sign):
        x = F(x)
        try:
            x, y = (sign * E(x, y_suggest)).xy()
            expected_y = y
            expected = 0
        except TypeError:
            # `sqrt` failed
            if F(x) == 0 and F(y_suggest) == 0:
                y, expected_y = F(0), F(1)
                z = F(0)
                expected = 0
            else:
                y, expected_y = F(y_suggest), F(y_suggest)
                z = F(1)
                expected = -1

        c_bytes = self.point_to_bytes(x.lift(), y.lift())
        c_point = (ctypes.c_uint64 * 30)(0)
        ret = ge_frombytes(c_point, c_bytes)
        actual_x, actual_y, actual_z = self.decode_point(c_point)
        self.assertEqual(ret, expected)
        self.assertEqual(fe10_val(c_point[ 0:10]), x)
        self.assertEqual(fe10_val(c_point[10:20]), expected_y)
        self.assertEqual(fe10_val(c_point[20:30]), z)

    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]))
    @example(0, 0, 1) # a point at infinity
    @example(0, P, 1)
    @example(0, 2*P, 1)
    def test_tobytes(self, x, z, sign):
        (x, y, z), point = make_ge(x, z, sign)
        c_point = self.encode_point(x, y, z)
        c_bytes = (ctypes.c_ubyte * 64)(0)
        ge_tobytes(c_bytes, c_point)

        if z != 0:
            expected_x, expected_y = point.xy()
        else:
            expected_x, expected_y = F(0), F(0)

        actual_x, actual_y = self.decode_bytes(c_bytes)
        self.assertEqual(actual_x, expected_x)
        self.assertEqual(actual_y, expected_y)

    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),   st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1), st.sampled_from([1, -1]))
    @example(0, 0, 1, 0, 0, 1)
    def test_add(self, x1, z1, sign1, x2, z2, sign2):
        (x1, y1, z1), point1 = make_ge(x1, z1, sign1)
        (x2, y2, z2), point2 = make_ge(x2, z2, sign2)
        c_point1 = self.encode_point(x1, y1, z1)
        c_point2 = self.encode_point(x2, y2, z2)
        c_point3 = (ctypes.c_uint64 * 30)(0)
        ge_add(c_point3, c_point1, c_point2)
        x3, y3, z3 = self.decode_point(c_point3)
        expected = point1 + point2
        note("Expected: {}".format(expected))
        note("Actual: ({} : {} : {})".format(x3, y3, z3))
        if expected == E(0):
            self.assertEqual(F(z3), 0)
            return
        actual = E([F(x3), F(y3), F(z3)])
        self.assertEqual(actual, expected)


    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),   st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1), st.sampled_from([1, -1]))
    @example(0, 0, 1, 0, 0, 1)
    @example(0, 1, 1, 0, 0, 1)
    @example(0, 1, -1, 0, 0, 1)
    @example(5, 26250914708855074711006248540861075732027942443063102939584266239L, 1)
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_add_ref(self, x1, z1, sign1, x2, z2, sign2):
        (x1, y1, z1), point1 = make_ge(x1, z1, sign1)
        (x2, y2, z2), point2 = make_ge(x2, z2, sign2)
        note("testing: {} + {}".format(point1, point2))
        note("locals(): {}".format(locals()))
        x1, y1, z1 = F(x1), F(y1), F(z1)
        x2, y2, z2 = F(x2), F(y2), F(z2)
        b = 13318
        t0 = x1 * x2;       t1 = y1 * y2;       t2 = z1 * z2
        t3 = x1 + y1;       t4 = x2 + y2;       t3 = t3 * t4
        t4 = t0 + t1;       t3 = t3 - t4;       t4 = y1 + z1
        x3 = y2 + z2;       t4 = t4 * x3;       x3 = t1 + t2
        t4 = t4 - x3;       x3 = x1 + z1;       y3 = x2 + z2
        x3 = x3 * y3;       y3 = t0 + t2;       y3 = x3 - y3
        z3 =  b * t2;       x3 = y3 - z3;       z3 = x3 + x3
        x3 = x3 + z3;       z3 = t1 - x3;       x3 = t1 + x3
        y3 =  b * y3;       t1 = t2 + t2;       t2 = t1 + t2
        y3 = y3 - t2;       y3 = y3 - t0;       t1 = y3 + y3
        y3 = t1 + y3;       t1 = t0 + t0;       t0 = t1 + t0
        t0 = t0 - t2;       t1 = t4 * y3;       t2 = t0 * y3
        y3 = x3 * z3;       y3 = y3 + t2;       x3 = x3 * t3
        x3 = x3 - t1;       z3 = z3 * t4;       t1 = t3 * t0
        z3 = z3 + t1
        self.assertEqual(E([x3, y3, z3]), point1 + point2)

    @example(0, 0, 1)
    @example(0, 1, 1)
    @example(0, 1, -1)
    @example(5, 26250914708855074711006248540861075732027942443063102939584266239L, 1)
    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]))
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_double_ref(self, x, z, sign):
        (x, y, z), point = make_ge(x, z, sign)
        note("testing: 2*{}".format(point))
        note("locals(): {}".format(locals()))
        x, y, z = F(x), F(y), F(z)
        b = 13318
        t0 =  x *  x;       t1 =  y *  y;       t2 =  z *  z
        t3 =  x *  y;       t3 = t3 + t3;       z3 =  x *  z
        z3 = z3 + z3;       y3 =  b * t2;       y3 = y3 - z3
        x3 = y3 + y3;       y3 = x3 + y3;       x3 = t1 - y3
        y3 = t1 + y3;       y3 = x3 * y3;       x3 = x3 * t3
        t3 = t2 + t2;       t2 = t2 + t3;       z3 =  b * z3
        z3 = z3 - t2;       z3 = z3 - t0;       t3 = z3 + z3
        z3 = z3 + t3;       t3 = t0 + t0;       t0 = t3 + t0
        t0 = t0 - t2;       t0 = t0 * z3;       y3 = y3 + t0
        t0 =  y *  z;       t0 = t0 + t0;       z3 = t0 * z3
        x3 = x3 - z3;       z3 = t0 * t1;       z3 = z3 + z3
        z3 = z3 + z3;
        self.assertEqual(E([x3, y3, z3]), 2*point)

    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),   st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1), st.sampled_from([1, -1]))
    @example(0, 0, 1, 0, 0, 1)
    def test_add_ref(self, x1, z1, sign1, x2, z2, sign2):
        (x1, y1, z1), point1 = make_ge(x1, z1, sign1)
        (x2, y2, z2), point2 = make_ge(x2, z2, sign2)
        note("testing: {} + {}".format(point1, point2))
        note("locals(): {}".format(locals()))
        x1, y1, z1 = F(x1), F(y1), F(z1)
        x2, y2, z2 = F(x2), F(y2), F(z2)
        b = 13318
        t0 = x1 * x2;        t1 = y1 * y2;        t2 = z1 * z2
        t3 = x1 + y1;        t4 = x2 + y2;        t3 = t3 * t4
        t4 = t0 + t1;        t3 = t3 - t4;        t4 = y1 + z1
        x3 = y2 + z2;        t4 = t4 * x3;        x3 = t1 + t2
        t4 = t4 - x3;        x3 = x1 + z1;        y3 = x2 + z2
        x3 = x3 * y3;        y3 = t0 + t2;        y3 = x3 - y3
        z3 =  b * t2;        x3 = y3 - z3;        z3 = x3 + x3
        x3 = x3 + z3;        z3 = t1 - x3;        x3 = t1 + x3
        y3 =  b * y3;        t1 = t2 + t2;        t2 = t1 + t2
        y3 = y3 - t2;        y3 = y3 - t0;        t1 = y3 + y3
        y3 = t1 + y3;        t1 = t0 + t0;        t0 = t1 + t0
        t0 = t0 - t2;        t1 = t4 * y3;        t2 = t0 * y3
        y3 = x3 * z3;        y3 = y3 + t2;        x3 = x3 * t3
        x3 = x3 - t1;        z3 = z3 * t4;        t1 = t3 * t0
        z3 = z3 + t1
        self.assertEqual(E([x3, y3, z3]), point1 + point2)


def fe10_dumps(h):
    s = ''
    exponent = 230
    for i in range(9, 0, -1):
        s += "{}*2^{} + ".format(h[i], exponent)
        exponent -= 25 if i % 2 == 0 else 26
    s += "{}".format(h[0])
    return s

def fe10_val(h):
    val = 0
    exponent = 0
    for i, limb in enumerate(h):
        val += limb * 2**exponent
        exponent += 26 if i % 2 == 0 else 25
    return val

def make_fe10(initial_value=[]):
    h = (ctypes.c_uint64 * 10)(0)
    for i, limb in enumerate(initial_value):
        h[i] = limb
    return h

def make_ge(x, z, sign):
    if z != 0:
        try:
            point = sign * E.lift_x(F(x))
        except ValueError:
            assume(False)
        x, y = point.xy()
        z = F(z)
        x, y = z * x, z * y
    else:
        point = E(0)
        x, y, z = F(0), F(1), F(z)
    return (x, y, z), point


if __name__ == '__main__':
    unittest.main()
