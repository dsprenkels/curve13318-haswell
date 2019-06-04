#!/bin/echo Please execute with sage -python
# *-* encoding: utf-8 *-*

import ctypes
import io
import os
import sys
import unittest

from sage.all import *

from hypothesis import *
from hypothesis import strategies as st

P = 2**255 - 19
F = FiniteField(P)
E = EllipticCurve(F, [-3, 13318])

# Initialize hypothesis
settings.register_profile('default', settings())
settings.register_profile('ci', settings(max_examples=1000))
if os.getenv('CI') != None:
    settings.load_profile('ci')
else:
    settings.load_profile('default')

# Load shared libcurve13318 library
curve13318 = ctypes.CDLL(os.path.join(os.path.abspath('.'), 'libcurve13318.so'))

# Define types
fe10_type = ctypes.c_uint64 * 10
fe51_type = ctypes.c_uint64 * 5
ge_type = ctypes.c_uint64 * 30

# Define functions
fe10_frombytes = curve13318.crypto_scalarmult_curve13318_avx2_fe10_frombytes
fe10_frombytes.argtypes = [fe10_type, ctypes.c_ubyte * 32]
fe10_tobytes = curve13318.crypto_scalarmult_curve13318_avx2_fe10_tobytes
fe10_tobytes.argtypes = [ctypes.c_ubyte * 32, fe10_type]
fe10_carry = curve13318.crypto_scalarmult_curve13318_avx2_fe10_carry
fe10_carry.argtypes = [fe10_type]
fe10_mul = curve13318.crypto_scalarmult_curve13318_avx2_fe10_mul
fe10_mul.argtypes = [fe10_type] * 3
fe10_square = curve13318.crypto_scalarmult_curve13318_avx2_fe10_square
fe10_square.argtypes = [fe10_type] * 2
fe10_invert = curve13318.crypto_scalarmult_curve13318_avx2_fe10_invert
fe10_invert.argtypes = [fe10_type] * 2
fe10_reduce = curve13318.crypto_scalarmult_curve13318_avx2_fe10_reduce
fe10_reduce.argtypes = [fe10_type]

fe51_mul = curve13318.crypto_scalarmult_curve13318_avx2_fe51_mul
fe51_mul.argtypes = [fe51_type] * 3

ge_frombytes = curve13318.crypto_scalarmult_curve13318_avx2_ge_frombytes
ge_frombytes.argtypes = [ge_type, ctypes.c_ubyte * 64]
ge_tobytes = curve13318.crypto_scalarmult_curve13318_avx2_ge_tobytes
ge_tobytes.argtypes = [ctypes.c_ubyte * 64, ge_type]
ge_double = curve13318.crypto_scalarmult_curve13318_avx2_ge_double
ge_double.argtypes = [ge_type] * 2
ge_add = curve13318.crypto_scalarmult_curve13318_avx2_ge_add
ge_add.argtypes = [ge_type] * 3

fe10x4_carry = curve13318.crypto_scalarmult_curve13318_avx2_fe10x4_carry
fe10x4_carry.argtypes = [ctypes.c_uint64 * 40]
fe10x4_carry2 = curve13318.crypto_scalarmult_curve13318_avx2_fe10x4_carry2
fe10x4_carry2.argtypes = [ctypes.c_uint64 * 40]
fe10x4_mul = curve13318.crypto_scalarmult_curve13318_avx2_fe10x4_mul_asm
fe10x4_mul.argtypes = [ctypes.c_uint64 * 40] * 3
fe10x4_square = curve13318.crypto_scalarmult_curve13318_avx2_fe10x4_square_asm
fe10x4_square.argtypes = [ctypes.c_uint64 * 40] * 2

ge_add_asm = curve13318.crypto_scalarmult_curve13318_avx2_ge_add_asm
ge_add_asm.argtypes = [ge_type] * 3
ge_double_asm = curve13318.crypto_scalarmult_curve13318_avx2_ge_double_asm
ge_double_asm.argtypes = [ge_type] * 2

scalarmult = curve13318.crypto_scalarmult_curve13318_avx2_scalarmult
scalarmult.argtypes = [ctypes.c_ubyte * 64, ctypes.c_ubyte * 32, ctypes.c_ubyte * 64]
select = curve13318.crypto_scalarmult_curve13318_avx2_select
select.argtypes = [ge_type, ctypes.c_uint64, ge_type * 16]

class TestFE10(unittest.TestCase):
    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_identity(self, limbs):
        fe10 = make_fe10(limbs)
        self.assertEqual(fe10_val(fe10), fe10_val(limbs))
    
    @staticmethod
    def frombytes(bytelist):
        h = make_fe10([])
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
        h = make_fe10([])
        fe10_mul(h, f, g)
        actual = F(fe10_val(h))
        self.assertEqual(actual, expected)

    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_square(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = F(f_val**2)
        h = make_fe10([])
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

    @example([218, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
              255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255])
    @given(st.lists(st.integers(0, 255), min_size=32, max_size=32))
    def test_invert(self, bytelist):
        f, f_val = self.frombytes(bytelist)
        expected = F(f_val)**-1 if F(f_val) != 0 else 0
        h = make_fe10([])
        fe10_invert(h, f)
        actual = F(fe10_val(h))
        self.assertEqual(actual, expected)

    # Value that that is in [p, 2^255⟩
    @example([2**26 -19, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**25 - 1 ])
    # Value that that is in [2*p, 2^256⟩
    @example([2**26 -38, 2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1,
              2**25 - 1, 2**26 - 1, 2**25 - 1, 2**26 - 1, 2**26 - 1 ])
    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10))
    def test_reduce(self, limbs):
        f = make_fe10(limbs)
        expected = F(fe10_val(f))
        fe10_carry(f)
        fe10_reduce(f)
        actual = fe10_val(f)
        self.assertEqual(actual, expected)

class TestFE51(unittest.TestCase):
    @given(st.lists(st.integers(0, 2**52 - 1), min_size=5, max_size=5),
           st.lists(st.integers(0, 2**52 - 1), min_size=5, max_size=5))
    def test_mul(self, limbs_x, limbs_y):
        vx = make_fe51(limbs_x)
        vy = make_fe51(limbs_y)
        vz = make_fe51([])
        note("mul got:      {} * {}".format([hex(x) for x in vx], [hex(x) for x in vy]))
        fe51_mul(vz, vx, vy)
        actual = fe51_val(vz)
        expected = fe51_val(vx) * fe51_val(vy)
        note("mul returned: {}".format([hex(x) for x in vz]))
        # note("actual value:   0x{:32X}".format(F(actual)))
        # note("expected value: 0x{:32X}".format(F(expected)))
        self.assertEqual(F(actual), F(expected))

class TestFE10x4(unittest.TestCase):
    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10), st.integers(0, 3))
    def test_identity(self, limbs, lane):
        fe10 = make_fe10x4(limbs, lane)
        self.assertEqual(fe10x4_val(fe10, lane), fe10_val(limbs))
    
    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10), st.integers(0, 3))
    def test_carry(self, limbs, lane):
        self.do_test_carry(limbs, lane, fe10x4_carry)

    @given(st.lists(st.integers(0, 2**63 - 1), min_size=10, max_size=10), st.integers(0, 3))
    def test_carry2(self, limbs, lane):
        self.do_test_carry(limbs, lane, fe10x4_carry2)
    
    def do_test_carry(self, limbs, lane, fn):
        vz = make_fe10x4(limbs, lane)
        note("carry got:      {}".format([hex(x) for x in vz[lane::4]]))
        fe10x4_carry(vz)
        actual = fe10x4_val(vz, lane)
        expected = fe10_val(limbs)
        note("carry returned: {}".format([hex(x) for x in vz[lane::4]]))
        note("actual value:   0x{:32X}".format(actual))
        note("expected value: 0x{:32X}".format(expected))
        self.assertEqual(F(actual), F(expected))
        for i, x in list(enumerate(vz[lane::4]))[0::1]:
            assert(0 <= x <= 1.01 * 2**26), "limb {} out of bounds: 0x{:X}".format(i, x)
        for i, x in list(enumerate(vz[lane::4]))[1::1]:
            assert(0 <= x <= 1.01 * 2**26), "limb {} out of bounds: 0x{:X}".format(i, x)

    @given(st.lists(st.integers(0, 2**27 - 1), min_size=10, max_size=10),
           st.lists(st.integers(0, 2**27 - 1), min_size=10, max_size=10),
           st.integers(0, 3))
    def test_mul(self, limbs_x, limbs_y, lane):
        vx = make_fe10x4(limbs_x, lane)
        vy = make_fe10x4(limbs_y, lane)
        vz = make_fe10x4([], lane)
        note("mul got:      {} * {}".format([hex(x) for x in vx[lane::4]], [hex(x) for x in vy[lane::4]]))
        fe10x4_mul(vz, vx, vy)
        actual = fe10x4_val(vz, lane)
        expected = fe10_val(limbs_x) * fe10_val(limbs_y)
        note("mul returned: {}".format([hex(x) for x in vz[lane::4]]))
        # note("actual value:   0x{:32X}".format(F(actual)))
        # note("expected value: 0x{:32X}".format(F(expected)))
        self.assertEqual(F(actual), F(expected))

    @given(st.lists(st.integers(0, 2**27 - 1), min_size=10, max_size=10),
           st.integers(0, 3))
    def test_square(self, limbs_x, lane):
        vx = make_fe10x4(limbs_x, lane)
        vz = make_fe10x4([], lane)
        note("square got:      {} ** 2".format([hex(x) for x in vx[lane::4]]))
        fe10x4_square(vz, vx)
        actual = fe10x4_val(vz, lane)
        expected = fe10_val(limbs_x) ** 2
        note("square returned: {}".format([hex(x) for x in vz[lane::4]]))
        # note("actual value:   0x{:32X}".format(F(actual)))
        # note("expected value: 0x{:32X}".format(F(expected)))
        self.assertEqual(F(actual), F(expected))

class TestGE(unittest.TestCase):
    @staticmethod
    def encode_ge(x, y, z, fx=1, fy=None, fz=None):
        """Encode a point in its C representation"""
        if fy is None: fy = fx
        if fz is None: fz = fx
        shift = 0
        x_limbs, y_limbs, z_limbs = [0]*10, [0]*10, [0]*10
        for i in range(10):
            mask_width = 26 if i % 2 == 0 else 25
            x_limbs[i] = fx * ((2**mask_width - 1) & (x.lift() >> shift))
            y_limbs[i] = fy * ((2**mask_width - 1) & (y.lift() >> shift))
            z_limbs[i] = fz * ((2**mask_width - 1) & (z.lift() >> shift))
            shift += mask_width

        stashed = []
        p = ge_type(0)
        while ctypes.addressof(p) % 32 != 0:
            stashed.append(p)
            p = ge_type(0)
            
        for i, limb in enumerate(x_limbs + y_limbs + z_limbs):
            p[i] = limb
        return p

    @staticmethod
    def decode_ge(point):
        x = fe10_val(point[ 0:10])
        y = fe10_val(point[10:20])
        z = fe10_val(point[20:30])
        return (x, y, z)

    @staticmethod
    def decode_bytes(c_bytes):
        x, y = F(0), F(0)
        for i, b in enumerate(c_bytes[0:32]):
            x += b * 2**(8*i)
        for i, b in enumerate(c_bytes[32:64]):
            y += b * 2**(8*i)
        return x, y

    @staticmethod
    def ge_to_bytes(x, y):
        """Encode the numbers as byte input"""
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

        c_bytes = self.ge_to_bytes(x.lift(), y.lift())
        c_point = ge_type(0)
        ret = ge_frombytes(c_point, c_bytes)
        actual_x, actual_y, actual_z = self.decode_ge(c_point)
        self.assertEqual(ret, expected)
        self.assertEqual(fe10_val(c_point[ 0:10]), x)
        self.assertEqual(fe10_val(c_point[10:20]), expected_y)
        self.assertEqual(fe10_val(c_point[20:30]), z)

    @example(0, 0, 1) # a point at infinity
    @example(0, P, 1)
    @example(0, 2*P, 1)
    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]))
    def test_identity(self, x, z, sign):
        (x, y, z), point = make_ge(x, z, sign)
        c_point = self.encode_ge(x, y, z)
        x2, y2, z2 = self.decode_ge(c_point)
        self.assertEqual(x, x2)
        self.assertEqual(y, y2)
        self.assertEqual(z, z2)

    @example(0, 0, 1) # a point at infinity
    @example(0, P, 1)
    @example(0, 2*P, 1)
    @given(st.integers(0, 2**255 - 1), st.integers(0, 2**255 - 1),
           st.sampled_from([1, -1]))
    def test_tobytes(self, x, z, sign):
        (x, y, z), point = make_ge(x, z, sign)
        c_point = self.encode_ge(x, y, z)
        c_bytes = (ctypes.c_ubyte * 64)(0)
        ge_tobytes(c_bytes, c_point)
        note("point:      %s" % point)
        note("c_point:    0x%s" % ''.join("%02x" % x for x in c_point))
        note("c_bytes:    0x%s" % ''.join("%02x" % x for x in c_bytes))

        if z != 0:
            expected_x, expected_y = point.xy()
        else:
            expected_x, expected_y = F(0), F(0)

        actual_x, actual_y = self.decode_bytes(c_bytes)
        note("actual_x:   0x%s" % actual_x.lift().hex())
        note("expected_x: 0x%s" % expected_x.lift().hex())
        note("actual_y:   0x%s" % actual_y.lift().hex())
        note("expected_y: 0x%s" % expected_y.lift().hex())
        self.assertEqual(actual_x, expected_x)
        self.assertEqual(actual_y, expected_y)

    @example(0, 0, 1)
    @example(0, 1, 1)
    @example(0, 1, -1)
    @given(st.integers(0, 2**256 - 1), st.integers(0, 2**256 - 1), st.sampled_from([1, -1]))
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_double(self, x, z, sign):
        (x, y, z), point = make_ge(x, z, sign)
        c_point = self.encode_ge(x, y, z)
        c_point3 = ge_type(0)
        ge_double(c_point3, c_point)
        x3, y3, z3 = self.decode_ge(c_point3)
        expected = 2*point
        note("Expected: {}".format(expected))
        note("Actual: ({} : {} : {})".format(x3, y3, z3))
        if expected == E(0):
            self.assertEqual(F(z3), 0)
            return
        actual = E([F(x3), F(y3), F(z3)])
        self.assertEqual(actual, expected)

    @example(0, 0, 1)
    @example(0, 1, 1)
    @example(0, 1, -1)
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

    @example(0, 0, 1, 1, 1, 1)  
    @example(0, 1, 1, 1, 1, 1)  
    @example(0, 1, -1, 1, 1, 1) 
    @given(st.integers(0, 2**255 - 1),
           st.integers(0, 2**255 - 1),
           st.sampled_from([1, -1]),
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
    )
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_double_asm(self, x, z, sign, fx, fy, fz):
        assume(fx * fz <= 2)
        (x, y, z), point = make_ge(x, z, sign)
        c_point = self.encode_ge(x, y, z, fx, fy, fz)
        c_point3 = self.encode_ge(F(0), F(0), F(0))
        ge_double_asm(c_point3, c_point)
        actual_x3, actual_y3, actual_z3 = self.decode_ge(c_point3)
        expected = 2*point
        note("Expected: {}".format(expected))
        note("Actual: ({} : {} : {})".format(F(actual_x3), F(actual_y3), F(actual_z3)))
        # note("c_point: (Y = {})".format([_limb for _limb in c_point[0:10]]))

        x *= fx
        y *= fy
        z *= fz

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
        
        self.assertEqual(F(actual_x3), x3)
        self.assertEqual(F(actual_y3), y3)
        self.assertEqual(F(actual_z3), z3)

        # Check the bounds for X, Y and Z
        for limb in c_point3[0:10]:
            self.assertLessEqual(limb, 1.01 * 2**26)
        for limb in c_point3[10:20]:
            self.assertLessEqual(limb, 1.01 * 2**27)
        for limb in c_point3[20:30]:
            self.assertLessEqual(limb, 1.01 * 2**26)

    @example(0, 0, 1, 0, 0, 1)
    @example(0, 1, 1, 0, 0, 1)
    @example(0, 1, -1, 0, 0, 1)
    @given(st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),
           st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),
    ) 
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_add(self, x1, z1, sign1, x2, z2, sign2):
        (x1, y1, z1), point1 = make_ge(x1, z1, sign1)
        (x2, y2, z2), point2 = make_ge(x2, z2, sign2)
        c_point1 = self.encode_ge(x1, y1, z1)
        c_point2 = self.encode_ge(x2, y2, z2)
        c_point3 = ge_type(0)
        ge_add(c_point3, c_point1, c_point2)
        x3, y3, z3 = self.decode_ge(c_point3)
        expected = point1 + point2
        note("Expected: {}".format(expected))
        note("Actual: ({} : {} : {})".format(x3, y3, z3))
        if expected == E(0):
            self.assertEqual(F(z3), 0)
            return
        actual = E([F(x3), F(y3), F(z3)])
        self.assertEqual(actual, expected)

    @example(0, 0, 1, 0, 0, 1)
    @example(0, 1, 1, 0, 0, 1)
    @example(0, 1, -1, 0, 0, 1)
    @given(st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),
           st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1),
           st.sampled_from([1, -1]),
    )
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

    @example(0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1)
    @example(0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1)
    @example(0, 1, -1, 1, 1, 1, 0, 0, 1, 1, 1, 1)
    @given(st.integers(0, 2**255 - 1),
           st.integers(0, 2**255 - 1),
           st.sampled_from([1, -1]),
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(0, 2**255 - 1),
           st.integers(0, 2**255 - 1),
           st.sampled_from([1, -1]),
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
           st.integers(1, 2), # s.t. P_1 ≤ 2^27
    )
    @settings(suppress_health_check=[HealthCheck.filter_too_much])
    def test_add_asm(self, x1, z1, sign1, fx1, fy1, fz1, x2, z2, sign2, fx2, fy2, fz2):
        assume(fx1 * fy1 * fz1 <= 2)
        assume(fx2 * fy2 * fz2 <= 2)

        (x1, y1, z1), point1 = make_ge(x1, z1, sign1)
        (x2, y2, z2), point2 = make_ge(x2, z2, sign2)
        
        c_point1 = self.encode_ge(x1, y1, z1, fx1, fy1, fz1)
        c_point2 = self.encode_ge(x2, y2, z2, fx2, fy2, fz2)
        c_point3 = self.encode_ge(F(0), F(0), F(0))
        ge_add_asm(c_point3, c_point1, c_point2)
        actual_x3, actual_y3, actual_z3 = self.decode_ge(c_point3)
        expected = point1 + point2
        note("Expected: {}".format(expected))
        note("Actual: ({} : {} : {})".format(F(actual_x3), F(actual_y3), F(actual_z3)))

        # Simulate using larger limbs
        x1 *= fx1
        y1 *= fy1
        z1 *= fz1
        x2 *= fx2
        y2 *= fy2
        z2 *= fz2

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

        self.assertEqual(F(actual_x3), x3)
        self.assertEqual(F(actual_y3), y3)
        self.assertEqual(F(actual_z3), z3)

        # Check the bounds for X, Y and Z
        for limb in c_point3[0:10]:
            self.assertLessEqual(limb, 1.01 * 2**26)
        for limb in c_point3[10:20]:
            self.assertLessEqual(limb, 1.01 * 2**27)
        for limb in c_point3[20:30]:
            self.assertLessEqual(limb, 1.01 * 2**26)
        
class TestScalarmult(unittest.TestCase):
    @staticmethod
    def encode_k(k):
        k_bytes = (ctypes.c_ubyte * 32)(0)
        for i in range(32):
            k_bytes[i] = (k >> (8*i)) & 0xFF
        return k_bytes
    
    @given(st.integers(0, 2**255 - 1), st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1), st.sampled_from([1, -1]))
    # @example(0, 1, 0, 1)
    def test_scalarmult(self, k, x, z, sign):
        note('k: 0x{:02x}'.format(k))
        
        _, point = make_ge(x, z, sign)
        note('Initial point: ' + str(point))
        if point.is_zero():
            (x, y) = F(0), F(0)
        else:
            (x, y) = point.xy()
        c_bytes_in = TestGE.ge_to_bytes(x.lift(), y.lift())

        # Assert that TestGE.ge_to_bytes and TestGE.decode_bytes are correct
        c_bytes_in_sanity_x, c_bytes_in_sanity_y = TestGE.decode_bytes(c_bytes_in)
        self.assertEqual(c_bytes_in_sanity_x, x)
        self.assertEqual(c_bytes_in_sanity_y, y)
        
        k_bytes = self.encode_k(k)
        c_bytes_out = (ctypes.c_ubyte * 64)(0)
        
        ret = scalarmult(c_bytes_out, k_bytes, c_bytes_in)
        c_bytes_out_x, c_bytes_out_y = TestGE.decode_bytes(c_bytes_out)
        
        note('INPUTS:')
        note('const uint8_t out[64] = {' + ', '.join([hex(x) for x in c_bytes_out]).replace("'", '') + '};')
        note('const uint8_t key[32] = {' + ', '.join([hex(x) for x in k_bytes]).replace("'", '') + '};')
        note('const uint8_t in[64] =  {' + ', '.join([hex(x) for x in c_bytes_in]).replace("'", '') + '};')
        note('----------------------------------------------------------------------')        
        if c_bytes_out_x != c_bytes_out_y != 0:
            note('  - point: {}'.format(point))
            point_out = E(c_bytes_out_x, c_bytes_out_y)
            note('  - point_out: {}'.format(point_out))
        
        self.assertEqual(ret, 0)
        actual = [int(x) for x in c_bytes_out]
        expected_point = k * point
        if expected_point.is_zero():
            expected_x, expected_y = F(0), F(0)
        else:
            expected_x, expected_y = expected_point.xy()
        expected = TestGE.ge_to_bytes(expected_x.lift(), expected_y.lift())
        expected = [int(x) for x in expected]
        # note('actual:   ' + str([hex(x) for x in actual]))
        # note('expected: ' + str([hex(x) for x in expected]))
        
        for k2 in range(0, 100):
            expected2_point = k2 * point
            if expected2_point.is_zero():
                expected2_x, expected2_y = F(0), F(0)
            else:
                expected2_x, expected2_y = expected2_point.xy()
            expected2 = TestGE.ge_to_bytes(expected2_x.lift(), expected2_y.lift())
            expected2 = [int(x) for x in expected2]
            if actual == expected2:
                note("MARK: k = {}; k2 = {}; x = {}; expected2 = {}".format(k, k2, x, expected2))
        
        self.assertEqual(actual, expected)

    @given(st.integers(0, 2**255 - 1), st.integers(0, 2**256 - 1),
           st.integers(0, 2**256 - 1))
    @example(0, 0, 0)
    def test_scalarmult_invalid_point(self, k, x, y):
        if (x, y) in E or (x, y) == (0, 0):
            expected = 0
        else:
            expected = -1
        c_bytes_in = TestGE.ge_to_bytes(x, y)
        k_bytes = self.encode_k(k)
        c_bytes_out = (ctypes.c_ubyte * 64)(0)
        ret = scalarmult(c_bytes_out, k_bytes, c_bytes_in)
        self.assertEqual(ret, expected)
    

    
    @given(st.integers(-1, 15), st.one_of(st.none(), st.data()))
    def test_select(self, idx, random_numbers):
        dest_c = allocate_aligned(ge_type, 32)
        ptable_c = allocate_aligned(ge_type * 16, 32)
        for i,_ in enumerate(ptable_c):
            for j,_ in enumerate(ptable_c[i]):
                if random_numbers: 
                    ptable_c[i][j] = random_numbers.draw(st.integers(0, 2**53-1))

        if idx == -1:
            # Load neutral element
            expected = ge_type(0)
            expected[10] = 1
            idx = 31
        else:
            expected = ptable_c[idx]
        expected = list(expected)

        select(dest_c, idx, ptable_c)
        actual = list(dest_c)

        note('idx = %s' % idx)
        note('expected: %s' % expected)
        note('actual:   %s' % actual)
        note('ptable_c: %s' % list(list(x) for x in ptable_c))
        self.assertEqual(actual, expected)
        
def allocate_aligned(ty, align):
    """
    Python does not do any aligned allocations by default. At least, not
    most of the time. The does not seem to be a good API to force an
    allocation to be aligned, so this function implements one.

    We allocate the type and wait until its address value is divisible by
    the desired allocation which will happen if we try long enough.
    """
    stashed = []
    cval = ty()
    for _ in range(1000):
        if ctypes.addressof(cval) % align == 0:
            return cval

        # Try until we have a properly aligned array
        stashed.append(cval) # save the old one or else Python is going to be smart on us
        cval = ty()
    else:
        raise RuntimeError('failed to allocate an aligned piece of ram')
        
def make_fe10(limbs):
    h = fe10_type(0)
    for i, limb in enumerate(limbs):
        h[i] = limb
    return h
    
def fe10_val(h):
    val = 0
    exponent = 0
    for i, limb in enumerate(h):
        val += limb * 2**exponent
        exponent += 26 if i % 2 == 0 else 25
    return val

def fe10_dumps(h):
    s = ''
    exponent = 230
    for i in range(9, 0, -1):
        s += "{}*2^{} + ".format(h[i], exponent)
        exponent -= 25 if i % 2 == 0 else 26
    s += "{}".format(h[0])
    return s

def make_fe51(limbs):
    h = allocate_aligned(fe51_type, 32)
    for i, limb in enumerate(limbs):
        h[i] = limb
    return h

def fe51_val(h):
    val = 0
    exponent = 0
    for i, limb in enumerate(h):
        val += limb * 2**exponent
        exponent += 51
    return val

def make_fe10x4(limbs, lane):
    assert 0 <= lane < 4
    z = make_fe10(limbs)
    stashed = []
    vz = allocate_aligned(ctypes.c_uint64 * 40, 32)
    for i, limb in enumerate(z):
        vz[4*i + lane] = limb
    return vz

def fe10x4_val(vz, lane):
    return fe10_val(vz[lane::4])

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
