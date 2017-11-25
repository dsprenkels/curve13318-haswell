#!/bin/echo Please execute with sage -python
# *-* encoding: utf-8 *-*

import ctypes
import io
import os
import sys
import unittest

from sage.all import *

from hypothesis import assume, example, given, settings, strategies as st, unlimited

P = 2**255 - 19

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
fe_frombytes = curve13318.crypto_scalarmult_curve13318_ref_fe_frombytes
fe_frombytes.argtypes = [ctypes.c_uint64 * 10, ctypes.c_ubyte * 32]
fe_tobytes = curve13318.crypto_scalarmult_curve13318_ref_fe_tobytes
fe_tobytes.argtypes = [ctypes.c_ubyte * 32, ctypes.c_uint64 * 10]
fe_mul = curve13318.crypto_scalarmult_curve13318_ref_fe_mul
fe_mul.argtypes = [ctypes.c_uint64 * 10] * 3
fe_carry = curve13318.crypto_scalarmult_curve13318_ref_fe_carry
fe_carry.argtypes = [ctypes.c_uint64 * 10]
fe_square = curve13318.crypto_scalarmult_curve13318_ref_fe_square
fe_square.argtypes = [ctypes.c_uint64 * 10] * 2
fe_invert = curve13318.crypto_scalarmult_curve13318_ref_fe_invert
fe_invert.argtypes = [ctypes.c_uint64 * 10] * 2
fe_reduce = curve13318.crypto_scalarmult_curve13318_ref_fe_reduce
fe_reduce.argtypes = [ctypes.c_uint64 * 10]
ge_frombytes = curve13318.crypto_scalarmult_curve13318_ref_ge_frombytes
ge_frombytes.argtypes = [ctypes.c_uint64 * 30, ctypes.c_ubyte * 64]


def fe_dumps(h):
    s = ''
    exponent = 230
    for i in range(9, 0, -1):
        s += "{}*2^{} + ".format(h[i], exponent)
        exponent -= 25 if i % 2 == 0 else 26
    s += "{}".format(h[0])
    return s

def fe_val(h):
    val = 0
    exponent = 0
    for i, limb in enumerate(h):
        val += limb * 2**exponent
        exponent += 26 if i % 2 == 0 else 25
    return val

def make_fe(initial_value=[]):
    h = (ctypes.c_uint64 * 10)(0)
    for i, limb in enumerate(initial_value):
        h[i] = limb
    return h


class TestFE(unittest.TestCase):
    def setUp(self):
        self.F = FiniteField(P)

    @staticmethod
    def frombytes(bytelist):
        h = make_fe()
        c_bytes = (ctypes.c_ubyte * 32)(0)

        fe_value = 0
        for i, b in enumerate(bytelist):
            c_bytes[i] = b
            fe_value += b * 2**(8*i)
        fe_frombytes(h, c_bytes)
        return h, fe_value

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_frombytes(self, bytelist):
        h, expected = self.frombytes(bytelist)
        actual = fe_val(h) % P
        expected %= P
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_tobytes(self, limbs):
        h = make_fe(limbs)
        expected = fe_val(h) % P
        c_bytes = (ctypes.c_ubyte * 32)(0)
        fe_carry(h)
        fe_tobytes(c_bytes, h)
        actual = 0
        for i, b in enumerate(c_bytes):
            actual += b * 2**(8*i)
        self.assertEqual(actual, expected)

    @given(st.tuples(
        st.lists(st.integers(0, 255), min_size=32, max_size=32),
        st.lists(st.integers(0, 255), min_size=32, max_size=32)))
    def test_mul(self, bytelists):
        f, f_val = self.frombytes(bytelists[0])
        g, g_val = self.frombytes(bytelists[1])
        expected = self.F(f_val * g_val)
        h = make_fe()
        fe_mul(h, f, g)
        actual = self.F(fe_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_square(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = self.F(f_val**2)
        h = make_fe()
        fe_square(h, f)
        actual = self.F(fe_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_carry(self, limbs):
        f = make_fe(limbs)
        expected = self.F(fe_val(f))
        fe_carry(f)
        actual = fe_val(f)
        assert(actual < 2**256)
        self.assertEqual(self.F(actual), expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_invert(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = self.F(f_val)**-1 if f_val != 0 else 0
        h = make_fe()
        fe_invert(h, f)
        actual = self.F(fe_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    # Value that that is in [p, 2^255⟩
    @example([2**26 -19, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**25 - 1 ])
    # Value that that is in [2*p, 2^256⟩
    @example([2**26 -38, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**26 - 1 ])
    def test_reduce(self, limbs):
        f = make_fe(limbs)
        expected = self.F(fe_val(f))
        fe_carry(f)
        fe_reduce(f)
        actual = fe_val(f)
        self.assertEqual(actual, expected)


class TestGE(unittest.TestCase):
    def setUp(self):
        self.F = FiniteField(P)
        self.E = EllipticCurve(self.F, [-3, 13318])

    def construct_y(self, x, sign=None):
        if sign == 1:
            return self.F(sqrt(x**3 - 3*x + 13318))
        elif sign == -1:
            return self.F(-sqrt(x**3 - 3*x + 13318))
        elif sign == None:
            return None
        else:
            raise AssertionError

    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1, None]))
    @example(0, 0, None) # point at infinity
    def test_frombytes(self, x, y_suggest, sign):
        x = self.F(x)
        try:
            y = self.construct_y(x, sign)
            if y == None:
                y = self.F(y_suggest)
        except ValueError:
            # `sqrt` failed
            assume(False)

        # Is the point valid?
        try:
            if x == 0 and y == 0:
                # We are dealing with ∞
                point = self.E(0)
            else:
                point = self.E(x, y)
            expected = 0
        except TypeError:
            point = (x, y, 1)
            expected = -1

        # Encode the numbers as byte input
        c_bytes = (ctypes.c_ubyte * 64)(0)
        for i in range(32):
            c_bytes[i] = (x.lift() >> (8*i)) & 0xFF
        for i in range(32):
            c_bytes[32+i] = (y.lift() >> (8*i)) & 0xFF

        c_point = (ctypes.c_uint64 * 30)(0)
        ret = ge_frombytes(c_point, c_bytes)
        self.assertEqual(ret, expected)
        self.assertEqual(fe_val(c_point[ 0:10]), point[0])
        self.assertEqual(fe_val(c_point[10:20]), point[1])
        self.assertEqual(fe_val(c_point[20:30]), point[2])

if __name__ == '__main__':
    unittest.main()
