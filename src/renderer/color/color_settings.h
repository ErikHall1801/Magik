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

        float vt_reinhard_extended_white_luminance = 4.0f;

        float vt_khronos_pbr_neutral_start_compression = 0.8f;
        float vt_khronos_pbr_neutral_desaturation = 0.15f;

        e_magik_gran_turismo_7_mode_types vt_gt7_mode = MAGIK_GRAN_TURISMO_7_MODE_JZAZBZ;
        float vt_gt7_sdr_paper_white = 250.0f;
        float vt_gt7_reference_luminance = 100.0f;
        float vt_gt7_jzazbz_exponent_scale_factor = 1.7f;
    };
}
