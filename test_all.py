#!/bin/echo Please execute with sage -python

import ctypes
import io
import os
import sys
import unittest

from sage.all import *

from hypothesis import given, settings, strategies as st

P = 2**255 - 19

# Initialize hypothesis
settings.register_profile('default', settings())
settings.register_profile('ci', settings(max_examples=2000))
if os.getenv('CI') != None:
    settings.load_profile('ci')
else:
    settings.load_profile('default')

# Load shared libcurve13318 library
curve13318 = ctypes.CDLL(os.path.join(os.path.abspath('.'), 'libcurve13318.so'))

# Define functions
fe51_frombytes = curve13318.crypto_scalarmult_curve13318_ref_fe51_frombytes
fe51_frombytes.argtypes = [ctypes.c_uint64 * 10, ctypes.c_ubyte * 32]
fe51_mul = curve13318.crypto_scalarmult_curve13318_ref_fe51_mul
fe51_mul.argtypes = [ctypes.c_uint64 * 10] * 3
fe51_carry = curve13318.crypto_scalarmult_curve13318_ref_fe51_carry
fe51_carry.argtypes = [ctypes.c_uint64 * 10] * 2
fe51_square = curve13318.crypto_scalarmult_curve13318_ref_fe51_square
fe51_square.argtypes = [ctypes.c_uint64 * 10] * 2
fe51_invert = curve13318.crypto_scalarmult_curve13318_ref_fe51_invert
fe51_invert.argtypes = [ctypes.c_uint64 * 10] * 2


def fe51_dumps(h):
    s = ''
    exponent = 230
    for i in range(9, 0, -1):
        s += "{}*2^{} + ".format(h[i], exponent)
        exponent -= 25 if i % 2 == 0 else 26
    s += "{}".format(h[0])
    return s

def fe51_val(h):
    val = 0
    exponent = 0
    for i, limb in enumerate(h):
        val += limb * 2**exponent
        exponent += 26 if i % 2 == 0 else 25
    return val

def make_f51(initial_value=[]):
    h = (ctypes.c_uint64 * 10)(0)
    for i, limb in enumerate(initial_value):
        h[i] = limb
    return h


class TestFE(unittest.TestCase):
    def setUp(self):
        self.F = FiniteField(P)

    def frombytes(self, bytelist):
        h = make_f51()
        c_bytes = (ctypes.c_ubyte * 32)(0)

        fe51_value = 0
        for i, b in enumerate(bytelist):
            c_bytes[i] = b
            fe51_value += b * 2**(8*i)
        fe51_frombytes(h, c_bytes)
        return h, self.F(fe51_value)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_frombytes(self, bytelist):
        h, expected = self.frombytes(bytelist)
        actual = fe51_val(h) % P
        expected %= P
        self.assertEqual(actual, expected)

    @given(st.tuples(
        st.lists(st.integers(0, 255), min_size=32, max_size=32),
        st.lists(st.integers(0, 255), min_size=32, max_size=32)))
    def test_mul(self, bytelists):
        f, f_val = self.frombytes(bytelists[0])
        g, g_val = self.frombytes(bytelists[1])
        expected = (f_val * g_val) % P
        h = make_f51()
        fe51_mul(h, f, g)
        actual = fe51_val(h) % P
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_square(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = f_val**2 % P
        h = make_f51()
        fe51_square(h, f)
        actual = fe51_val(h) % P
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0,2**64 - 1), min_size=10, max_size=10))
    def test_carry(self, fe):
        f = make_f51(fe)
        h = make_f51()
        expected = self.F(fe51_val(h))
        fe51_carry(h, f)
        actual = fe51_val(h)
        assert(actual < P)
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_invert(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = f_val**-1 if f_val != 0 else 0
        h = make_f51()
        fe51_invert(h, f)
        actual = fe51_val(h) % P
        self.assertEqual(actual, expected)


if __name__ == '__main__':
    unittest.main()
