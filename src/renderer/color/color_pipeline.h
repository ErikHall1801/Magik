#pragma once

#include "cuda_host_device_utilities.h"
#include "host_color_utilities.h" 
#include "color_settings.h"
#include "view_transform.cuh"

namespace magik
{
    typedef enum e_magik_color_pipeline_update_policy_types : uint32_t
    {
        MAGIK_COLOR_PIPELINE_UPDATE_POLICY_NONE = 0,
        MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED = 1,
        MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT = 2
    } e_magik_color_pipeline_update_policy_types;

    struct color_pipeline_descriptor_t
    {
        uint32_t n_spectral_bin;
        vec3f isi_to_scene_referred_weights[MAGIK_N_MAX_SPECTRAL_BIN];
        float cmf_inverse_cdf_values[MAGIK_N_CMF_INVERSE_CDF_BIN];
        e_magik_display_colorspace_types display_colorspace_type;
        float peak_nits;
        mat3f scene_to_display_referred;
        e_magik_output_format_types output_format;
        e_magik_view_transform_types view_transform_type;
        e_magik_color_pipeline_update_policy_types update_policy;
    };

    struct update_color_pipeline_t
    {
        e_magik_color_pipeline_update_policy_types& update_policy;
        color_pipeline_descriptor_t& pipeline;
        color_settings_t& color_settings;
    };

    void update_color_pipeline(update_color_pipeline_t args);
}
