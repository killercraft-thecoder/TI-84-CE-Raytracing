#pragma once

/* Implemented 3D vectors based on fixed point math, and some common math
 * operations for these vectors
 */

#include "fixedpoint.h"

struct Vec3 {
  Fixed24 x;
  Fixed24 y;
  Fixed24 z;

  // Constructors for various types
  Vec3() {
    x = Fixed24(0);
    y = Fixed24(0);
    z = Fixed24(0);
  }
  Vec3(int24_t _x, int24_t _y, int24_t _z) {
    x = Fixed24(_x);
    y = Fixed24(_y);
    z = Fixed24(_z);
  }
  Vec3(float _x, float _y, float _z) {
    x = Fixed24(_x);
    y = Fixed24(_y);
    z = Fixed24(_z);
  }
  Vec3(Fixed24 _x, Fixed24 _y, Fixed24 _z) {
    x = _x;
    y = _y;
    z = _z;
  }

  Vec3 operator+(Vec3 v) const {
    return Vec3(x + v.x, y + v.y, z + v.z);
  }
  Vec3 operator-(Vec3 v) const {
    return Vec3(x - v.x, y - v.y, z - v.z);
  }
  Vec3 operator*(Vec3 v) const {
    return Vec3(x * v.x, y * v.y, z * v.z);
  }


  void operator+=(Vec3 &v) {
    x += v.x;
    y += v.y;
    z += v.z;
  }


  Vec3 operator+(Fixed24 s) const {
    return Vec3(x + s, y + s, z + s);
  }
  Vec3 operator-(Fixed24 s) const {
    return Vec3(x - s, y - s, z - s);
  }
  Vec3 operator*(Fixed24 s) const {
    return Vec3(x * s, y * s, z * s);
  }

  /* Computes the squared L2 norm of this vector
   */
  Fixed24 norm_squared() {
    return sqr(x) + sqr(y) + sqr(z);
  }

  /* Computes the euclidean length of this vector
   */
  Fixed24 norm() {
    Fixed24 norm_sqr = norm_squared();
    return sqrt(norm_sqr);
  }
};

// 3D dot product
Fixed24 dot(Vec3 &l, Vec3 &r) {
  Fixed24 out;

  // locals must have storage so inline asm can reference them
  int24_t lx = l.x.n;
  int24_t ly = l.y.n;
  int24_t lz = l.z.n;

  int24_t rx = r.x.n;
  int24_t ry = r.y.n;
  int24_t rz = r.z.n;

  int24_t result;

  __asm__
      ; ---- x*x ----
      ld hl, (_lx)
      push hl
      ld hl, (_rx)
      push hl
      call _fp_mul
      pop bc
      pop bc
      ld de, hl        ; DE = partial sum

      ; ---- y*y ----
      ld hl, (_ly)
      push hl
      ld hl, (_ry)
      push hl
      call _fp_mul
      pop bc
      pop bc
      add hl, de       ; accumulate
      ld de, hl

      ; ---- z*z ----
      ld hl, (_lz)
      push hl
      ld hl, (_rz)
      push hl
      call _fp_mul
      pop bc
      pop bc
      add hl, de       ; final sum

      ld (_result), hl
  __endasm;

  out.n = result;
  return out;
}

// 3D cross product
Vec3 cross(Vec3 l, Vec3 r) {
  Vec3 out;

  int24_t lx = l.x.n, ly = l.y.n, lz = l.z.n;
  int24_t rx = r.x.n, ry = r.y.n, rz = r.z.n;

  int24_t ox, oy, oz;

  __asm__
      ; ---------------- X = ly*rz - lz*ry ----------------
      ld hl, (_ly)
      push hl
      ld hl, (_rz)
      push hl
      call _fp_mul
      pop bc
      pop bc
      ld de, hl        ; DE = ly*rz

      ld hl, (_lz)
      push hl
      ld hl, (_ry)
      push hl
      call _fp_mul
      pop bc
      pop bc

      or a
      sbc hl, de
      ld (_ox), hl

      ; ---------------- Y = lz*rx - lx*rz ----------------
      ld hl, (_lz)
      push hl
      ld hl, (_rx)
      push hl
      call _fp_mul
      pop bc
      pop bc
      ld de, hl

      ld hl, (_lx)
      push hl
      ld hl, (_rz)
      push hl
      call _fp_mul
      pop bc
      pop bc

      or a
      sbc hl, de
      ld (_oy), hl

      ; ---------------- Z = lx*ry - ly*rx ----------------
      ld hl, (_lx)
      push hl
      ld hl, (_ry)
      push hl
      call _fp_mul
      pop bc
      pop bc
      ld de, hl

      ld hl, (_ly)
      push hl
      ld hl, (_rx)
      push hl
      call _fp_mul
      pop bc
      pop bc

      or a
      sbc hl, de
      ld (_oz), hl
  __endasm;

  out.x.n = ox;
  out.y.n = oy;
  out.z.n = oz;
  return out;
}

/* Prints the three components of this vector
 */
void print_vec(Vec3 vec) {
  print_fixed(vec.x);
  print_fixed(vec.y);
  print_fixed(vec.z);
  os_NewLine();
}