#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Provided by: Henning Seidler

from Crypto.Util import number
from Crypto.Util.number import inverse
import random


def create_secret(n, p):
    return [number.getRandomRange(0, p) for _ in range(n)]


def eval_poly(poly, arg, p):
    res = 0
    for coeff in poly:
        res = (res * arg + coeff) % p
    return res


def create_shares(secret, k, p):
    return [(arg, eval_poly(secret, arg, p)) for arg in range(1, k + 1)]


def lagrange(shares, p):
    n = len(shares)
    p0 = 0
    for j in range(n):
        Lj_zero = 1
        for k in range(n):
            if k == j:
                continue
            Lj_zero *= (-shares[k][0]) * inverse(shares[j][0] - shares[k][0], p) % p
        p0 += shares[j][1] * Lj_zero
    return p0 % p


def lagrange2(shares, p):
    n = len(shares)
    p0 = 0
    diffs = set([shares[j][0] - shares[k][0] for j in range(n) for k in range(j)])
    inv = {}
    for d in diffs:
        inv[d] = inverse(d, p)
        inv[-d] = -inv[d]
    for j in range(n):
        Lj_zero = 1
        for k in range(n):
            if k == j:
                continue
            Lj_zero *= (-shares[k][0]) * inv[shares[j][0] - shares[k][0]] % p
        p0 += shares[j][1] * Lj_zero
    return p0 % p


if __name__ == "__main__":
    p = 0x100000000000000000000000000000000000000000000000000000000000000000000007F
    secret = create_secret(7, p)
    shares = create_shares(secret, 17, p)
    collaboration = random.sample(shares, 7)
    res = lagrange(collaboration, p)
    assert res == secret[-1]
