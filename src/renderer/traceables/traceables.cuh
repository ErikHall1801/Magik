#pragma once

#include "internal_math.h"

namespace magik
{
    // So in the future we would extend this like the other files. We might have affine.cuh, hermite.cuh etc.
    // But for the moment we just need a single function here. The big issue here is the ray class, in 
    // particular with respect to the internal math. Nothing stops us from making ray.h, but it has to be 
    // includable for ordinary C++ as well, so we can allocate the correct sizes. Well, we can just kinda 
    // try it ? Because ray.h is just a header file, its not compiled. 
    // It truly depends on how we want to approach this. We want to make a wavefront renderer. This, in 
    // practice means we need things like a ray pool and queue. The queue is easy, the pool ? The ray
    // pool is, if we think about it, just the "framebuffer" struct  we have in VMEC. Big ol chunk of
    // memory with all the ray. 

    __device__ static bool affine_aabb_intersection(float* hit_interpolation_parameter, vec3f* hit_normal, const vec3f spatial_dir, const vec3f spatial_pos, const float inv_chord_length, const vec3f bounds_min, const vec3f bounds_max)
    {
        vec3f bounds[2] = { bounds_min, bounds_max };
        vec3f inv_dir = vec3f{1.0f / spatial_dir.x, 1.0f / spatial_dir.y, 1.0f / spatial_dir.z};
            
        int sign[3] = { inv_dir.x < 0.0f, inv_dir.y < 0.0f, inv_dir.z < 0.0f };

        float tmin, tmax, tymin, tymax, tzmin, tzmax;

        int axis_min = 0;
        int axis_max = 0;

        tmin = (bounds[sign[0]].x - spatial_pos.x) * inv_dir.x;
        tmax = (bounds[1 - sign[0]].x - spatial_pos.x) * inv_dir.x;

        tymin = (bounds[sign[1]].y - spatial_pos.y) * inv_dir.y;
        tymax = (bounds[1 - sign[1]].y - spatial_pos.y) * inv_dir.y;
            
        if ((tmin > tymax) || (tymin > tmax)) return false;

        if (tymin > tmin) { tmin = tymin; axis_min = 1; }
        if (tymax < tmax) { tmax = tymax; axis_max = 1; }
            
        tzmin = (bounds[sign[2]].z - spatial_pos.z) * inv_dir.z;
        tzmax = (bounds[1 - sign[2]].z - spatial_pos.z) * inv_dir.z;
            
        if ((tmin > tzmax) || (tzmin > tmax)) return false;

        if (tzmin > tmin) { tmin = tzmin; axis_min = 2; }
        if (tzmax < tmax) { tmax = tzmax; axis_max = 2; }

        if (tmax < 0.0f) return false;

        bool inside = tmin < 0.0f;

        float t = (inside ? tmax : tmin) * inv_chord_length;

        if(t > 1.0f) return false;
            
        int hit_axis = inside ? axis_max : axis_min;
        float n_sign = sign[hit_axis] ? 1.0f : -1.0f;
        if (inside) n_sign = -n_sign;
        vec3f normal = vec3f{0.0f, 0.0f, 0.0f};            
            
        if (hit_axis == 0) normal.x = n_sign;
        else if (hit_axis == 1) normal.y = n_sign;
        else normal.z = n_sign;

        *hit_interpolation_parameter = t;
        *hit_normal = normal;

        return true;
    }
}
