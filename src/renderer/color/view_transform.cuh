#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"

namespace magik
{
    template<e_magik_view_transform_types T_map> struct generic_view_transform_t;

    template<auto... T> struct view_transform_list {};

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_NONE>
    {
        struct params_t{};
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) { return c; }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE>
    {
        struct params_t{};
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p) 
        { 
            return c / (c + vec3f{1.0f, 1.0f, 1.0f}); 
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED>
    {
        struct params_t{ float white_luminance; vec3f luminance_weights; };
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const params_t& p)
        {
            float L = vector_dot_product(p.luminance_weights, c); 
            float L0 = L * (1.0f + L/(p.white_luminance * p.white_luminance)) / (1.0f + L);
            return L > 0.0f ? c * (L0/L) : vec3f{0.0f, 0.0f, 0.0f};
        }
    };

    struct view_transform_params_t
    {
        e_magik_view_transform_types view_transform_type;

        union
        {
            generic_view_transform_t<MAGIK_VIEW_TRANSFORM_NONE>::params_t none{};
            generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE>::params_t reinhard_simple;
            generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED>::params_t reinhard_extended;
        };

        static __host__ view_transform_params_t create(e_magik_view_transform_types view_transform, float white_luminance, vec3f luminance_weights)
        {
            view_transform_params_t result;

            result.view_transform_type = view_transform;
            result.reinhard_extended = { white_luminance, luminance_weights };

            return result;
        }
    };

    using supported_view_transforms = view_transform_list
    <
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_NONE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED
    >;

    template<class F, e_magik_view_transform_types... Ts> bool match_view_transforms(e_magik_view_transform_types type, F&& f, view_transform_list<Ts...>)
    {
        return ((type == Ts ? (f(std::integral_constant<e_magik_view_transform_types, Ts>{}), true) : false) || ...);
    }

    template<class F> bool dispatch_view_transforms(e_magik_view_transform_types type, F&& f)
    {
        return match_view_transforms(type, std::forward<F>(f), supported_view_transforms{});
    }

}
