#include "color_pipeline.h"

namespace magik
{
    static void update_relaxed(color_pipeline_descriptor_t& pipeline, color_settings_t& settings)
    {
        auto scene_colorspace_info = fetch_scene_colorspace(settings.scene_colorspace_type);
        auto display_colorspace_info = fetch_display_colorspace(settings.display_colorspace_type);
        vec3f white_point_dst_cie_xyz = cie_xy_to_cie_XYZ(scene_colorspace_info.white_point_cie_xy);
        pipeline.display_colorspace_type = settings.display_colorspace_type;
        pipeline.peak_nits = display_colorspace_info.peak_luminance;
        pipeline.output_format = settings.output_format;
        pipeline.scene_to_display_referred = display_colorspace_info.cie_XYZ_to_colorspace * chromatic_adaptation(white_point_dst_cie_xyz, cie_xy_to_cie_XYZ(display_colorspace_info.white_point_cie_xy)) * scene_colorspace_info.colorspace_to_cie_XYZ;
        pipeline.view_transform_type = settings.view_transform_type;
    }

    static void update_strict(color_pipeline_descriptor_t& pipeline, color_settings_t& settings)
    {
        auto scene_colorspace_info = fetch_scene_colorspace(settings.scene_colorspace_type);
        auto display_colorspace_info = fetch_display_colorspace(settings.display_colorspace_type);
        auto cmf_info = fetch_cmf_info(settings.cmf_type);

        pipeline.display_colorspace_type = settings.display_colorspace_type;
        pipeline.peak_nits = display_colorspace_info.peak_luminance;
        pipeline.output_format = settings.output_format;
        pipeline.n_spectral_bin = settings.n_isi_bin > MAGIK_N_MAX_SPECTRAL_BIN ? MAGIK_N_MAX_SPECTRAL_BIN : settings.n_isi_bin; // This should be replaced by a command-level constraint !

        compute_normalized_isi_cmf_weights(pipeline.isi_to_scene_referred_weights, pipeline.n_spectral_bin, settings.isi_min_wavelength_nm, settings.isi_max_wavelength_nm, cmf_info);

        compute_tabulated_cmf_inverse_cdf(pipeline.cmf_inverse_cdf_values, 0.05f, settings.isi_min_wavelength_nm, settings.isi_max_wavelength_nm, cmf_info);

        vec3f white_point_src_cie_xyz = compute_white_point_xyz(settings.white_point, settings.tint, cmf_info);
        vec3f white_point_dst_cie_xyz = cie_xy_to_cie_XYZ(scene_colorspace_info.white_point_cie_xy);
        mat3f XYZ_to_scene_white_balanced = scene_colorspace_info.cie_XYZ_to_colorspace * chromatic_adaptation(white_point_src_cie_xyz, white_point_dst_cie_xyz);
        fold_XYZ_to_scene_matrix_into_isi(pipeline.isi_to_scene_referred_weights, pipeline.n_spectral_bin, XYZ_to_scene_white_balanced);

        pipeline.scene_to_display_referred = display_colorspace_info.cie_XYZ_to_colorspace * chromatic_adaptation(white_point_dst_cie_xyz, cie_xy_to_cie_XYZ(display_colorspace_info.white_point_cie_xy)) * scene_colorspace_info.colorspace_to_cie_XYZ;

        pipeline.view_transform_type = settings.view_transform_type;
    }

    void update_color_pipeline(update_color_pipeline_t args)
    {
        switch(args.update_policy)
        {
            case MAGIK_COLOR_PIPELINE_UPDATE_POLICY_NONE:
            {
                break;
            }

            case MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED:
            {
                update_relaxed(args.pipeline, args.color_settings);
                break;
            }

            case MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT:
            {
                update_strict(args.pipeline, args.color_settings);
                break;
            }
        }

        args.update_policy = MAGIK_COLOR_PIPELINE_UPDATE_POLICY_NONE;
    }
}
