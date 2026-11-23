#pragma once

#include "magik.h"
#include "internal_math.h"
#include <cstdint>

namespace magik
{
    struct color_settings_t
    {
        uint32_t n_isi_bin = 24;
        float isi_max_wavelength_nm = 830.0f;
        float isi_min_wavelength_nm = 360.0f;
        float redistribution_standard_deviation_nm = 10.0f;

        e_magik_color_matching_function_types cmf_type = MAGIK_CMF_CIE_1931;
        e_magik_scene_colorspace_types scene_colorspace_type = MAGIK_SCENE_COLORSPACE_LINEAR_REC709;
        e_magik_view_transform_types view_transform_type = MAGIK_VIEW_TRANSFORM_GRAN_TURISMO_7;
        e_magik_display_colorspace_types display_colorspace_type = MAGIK_DISPLAY_COLORSPACE_REC709;
        e_magik_output_format_types output_format = MAGIK_OUTPUT_FORMAT_FLOAT32;

        float white_point = 5600.0f;
        float tint = 0.0f;
    };
}
