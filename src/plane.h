#pragma once

#include "vector.h"
#include "ray.h"
#include "color.h"
#include "texture.h"
#include "lightmap.h"

struct Plane {
    Vec3 point;
    Vec3 normal;
    Spectrum albedo;
    LightMap light_map;
    Texture* texture;

    // Precomputed value for fast intersection
    Fixed24 numerator;

    // Optional bounding box for intersection limits
    Fixed24 min_bound;
    Fixed24 max_bound;

    Plane(Vec3 _point, Vec3 _normal, Color _color, Texture *_texture)
        : point(_point),
          normal(_normal),
          albedo(_color),
          texture(_texture),
          min_bound(Fixed24(-0.01f)),
          max_bound(Fixed24(2.01f)) {}

    // Allow custom bounds
    void set_bounds(Fixed24 minv, Fixed24 maxv) {
        min_bound = minv;
        max_bound = maxv;
    }

    // Precompute numerator = dot(point - origin, normal)
    void register_camera(const Vec3 &origin) {
        // Avoid constructing a temporary Vec3
        Fixed24 ox = point.x - origin.x;
        Fixed24 oy = point.y - origin.y;
        Fixed24 oz = point.z - origin.z;

        numerator = fp_dot3(ox.n, oy.n, oz.n,
                            normal.x.n, normal.y.n, normal.z.n);
    }

    // Fast intersection using precomputed numerator
    Fixed24 ray_intersect_fast(const Ray &r) {
        // Compute denominator = dot(r.dir, normal)
        Fixed24 denom;
        denom.n = fp_dot3(r.dir.x.n, r.dir.y.n, r.dir.z.n,
                          normal.x.n, normal.y.n, normal.z.n);

        // Avoid division by zero or negative t
        if (denom.n == 0) return Fixed24(-1);

        Fixed24 t = div(numerator, denom);
        if (t.n <= 0) return Fixed24(-1);

        // Compute hit position directly without constructing Vec3
        Vec3 hit = r.origin + (r.dir * t);

        // Offset from plane point
        hit.x -= point.x;
        hit.y -= point.y;
        hit.z -= point.z;

        // Fast bounds check
        if (hit.x < min_bound || hit.x > max_bound) return Fixed24(-1);
        if (hit.y < min_bound || hit.y > max_bound) return Fixed24(-1);
        if (hit.z < min_bound || hit.z > max_bound) return Fixed24(-1);

        return t;
    }

    // Full intersection (no precomputed numerator)
    Fixed24 ray_intersect(const Ray &r) {
        // offset = point - r.origin
        Fixed24 ox = point.x - r.origin.x;
        Fixed24 oy = point.y - r.origin.y;
        Fixed24 oz = point.z - r.origin.z;

        Fixed24 num;
        num.n = fp_dot3(ox.n, oy.n, oz.n,
                        normal.x.n, normal.y.n, normal.z.n);

        Fixed24 denom;
        denom.n = fp_dot3(r.dir.x.n, r.dir.y.n, r.dir.z.n,
                          normal.x.n, normal.y.n, normal.z.n);

        if (denom.n == 0) return Fixed24(-1);

        Fixed24 t = div(num, denom);
        if (t.n <= 0) return Fixed24(-1);

        Vec3 hit = r.origin + (r.dir * t);

        hit.x -= point.x;
        hit.y -= point.y;
        hit.z -= point.z;

        if (hit.x < min_bound || hit.x > max_bound) return Fixed24(-1);
        if (hit.y < min_bound || hit.y > max_bound) return Fixed24(-1);
        if (hit.z < min_bound || hit.z > max_bound) return Fixed24(-1);

        return t;
    }
};