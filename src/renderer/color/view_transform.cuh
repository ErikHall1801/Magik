#pragma once

#include "magik.h"
#include "cuda_host_device_utilities.h"
#include "internal_math.h"

namespace magik
{
    struct view_transform_params_t
    {
        float reinhard_extended_white_luminance;
        vec3f reinhard_extended_luminance_weights;

        float khronos_pbr_neutral_start_compression;
        float khronos_pbr_neutral_desaturation;
    };

    template<e_magik_view_transform_types T_map> struct generic_view_transform_t;

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_NONE>
    {
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const view_transform_params_t& p) { return c; }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE>
    {
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const view_transform_params_t& p) 
        { 
            return c / (c + vec3f{1.0f, 1.0f, 1.0f}); 
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED>
    {
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const view_transform_params_t& p)
        {
            float L = vector_dot_product(p.reinhard_extended_luminance_weights, c); 
            float L0 = L * (1.0f + L/(p.reinhard_extended_white_luminance * p.reinhard_extended_white_luminance)) / (1.0f + L);
            return L > 0.0f ? c * (L0/L) : vec3f{0.0f, 0.0f, 0.0f};
        }
    };

    template<> struct generic_view_transform_t<MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL>
    {
        static constexpr bool does_gamut_mapping = false;
        
        static MAGIK_DEVICE_HOST vec3f apply(vec3f c, const view_transform_params_t& p)
        {
            // Requieres Linear Rec 709 input !!! 
            vec3f color = c;
            float start_compression = p.khronos_pbr_neutral_start_compression - 0.04f;

            float x = fminf(c.x, fminf(c.y, c.z));
            float offset = x < 0.08f ? x - 6.25f * x * x : 0.04f;
            color -= vec3f{offset, offset, offset};

            float peak = fmaxf(color.x, fmaxf(color.y, color.z));
            if(peak < start_compression) return color;

            float d = 1.0f - start_compression;
            float new_peak = 1.0f - d * d / (peak + d - start_compression);
            color *= new_peak / peak;

            float g = 1.0f - 1.0f/(p.khronos_pbr_neutral_desaturation * (peak - new_peak) + 1.0f);
            return magik::lerp(color, vec3f{new_peak, new_peak, new_peak}, g);
        }
    };

    struct view_transform_descriptor_t
    {
        e_magik_view_transform_types type;
        view_transform_params_t params;

        static __host__ view_transform_descriptor_t create(e_magik_view_transform_types view_transform, float white_luminance, vec3f luminance_weights, float khronos_pbr_neutral_start_compression, float khronos_pbr_neutral_desaturation)
        {
            view_transform_descriptor_t result;

            result.type = view_transform;
            result.params.reinhard_extended_white_luminance = white_luminance;
            result.params.reinhard_extended_luminance_weights = luminance_weights;
            result.params.khronos_pbr_neutral_start_compression = khronos_pbr_neutral_start_compression;
            result.params.khronos_pbr_neutral_desaturation = khronos_pbr_neutral_desaturation;

            return result;
        }
    };

    using supported_view_transforms = value_list
    <
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_NONE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED,
        e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL
        // e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_GRAN_TURISMO_7
        // e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_ACES_2,
        // e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_AGX,
        // e_magik_view_transform_types::MAGIK_VIEW_TRANSFORM_EXPONENTIAL
    >;
}
