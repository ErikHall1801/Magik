#include "command.h"
#include "renderer.h"
#include <string> // ???

namespace magik
{
    void fetch_command_info(e_magik_cqs_command_types type, bool* is_valid_command, size_t* command_size)
    {
        bool is_valid_ = false;
        size_t size_ = 0;

        switch(type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER: { is_valid_ = true; size_ = sizeof(magik_command_set_state_render_t); break; }

            case MAGIK_COMMAND_SET_STATE_PAUSE: { is_valid_ = true; size_ = sizeof(magik_command_set_state_pause_t); break; }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER: { is_valid_ = true; size_ = sizeof(magik_command_clear_render_buffer_t); break; }

            case MAGIK_COMMAND_ADD_AOV: { is_valid_ = true; size_ = sizeof(magik_command_add_aov_t); break; }

            case MAGIK_COMMAND_REMOVE_AOV: { is_valid_ = true; size_ = sizeof(magik_command_remove_aov_t); break; }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF: { is_valid_ = true; size_ = sizeof(magik_command_printf_t); break; }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // ############################
            // ### 4000-4999 Relativity ###
            // ############################
            case MAGIK_COMMAND_SET_METRIC_MINKOWSKI: { is_valid_ = true; size_ = sizeof(magik_command_set_metric_minkowski_t); break; }

            case MAGIK_COMMAND_SET_METRIC_SCHWARZSCHILD: { is_valid_ = true; size_ = sizeof(magik_command_set_metric_schwarzschild_t); break; }

            case MAGIK_COMMAND_SET_METRIC_KERR: { is_valid_ = true; size_ = sizeof(magik_command_set_metric_kerr_t); break; }

            case MAGIK_COMMAND_SET_ABSOLUTE_ERROR_TOLERANCE: { is_valid_ = true; size_ = sizeof(magik_command_set_absolute_error_tolerance_t); break; }

            case MAGIK_COMMAND_SET_RELATIVE_ERROR_TOLERANCE: { is_valid_ = true; size_ = sizeof(magik_command_set_relative_error_tolerance_t); break; }

            case MAGIK_COMMAND_SET_MAX_SUBSTEPS: { is_valid_ = true; size_ = sizeof(magik_command_set_max_substeps_t); break; }

            case MAGIK_COMMAND_SET_OBSERVER_LOCAL_PROPER_VELOCITY: { is_valid_ = true; size_ = sizeof(magik_command_set_observer_local_proper_velocity_t); break; }

            case MAGIK_COMMAND_SET_CELESTIAL_SPHERE_RADIUS: { is_valid_ = true; size_ = sizeof(magik_command_set_celestial_sphere_radius_t); break; }

            case MAGIK_COMMAND_SET_SCHWARZSCHILD_EVENT_HORIZON_SCALAR: { is_valid_ = true; size_ = sizeof(magik_command_set_schwarzschild_event_horizon_scalar_t); break; }

            case MAGIK_COMMAND_SET_SCHWARZSCHILD_MASS_PARAMETER: { is_valid_ = true; size_ = sizeof(magik_command_set_schwarzschild_mass_parameter_t); break; }

            case MAGIK_COMMAND_SET_KERR_EVENT_HORIZON_SCALAR: { is_valid_ = true; size_ = sizeof(magik_command_set_kerr_event_horizon_scalar_t); break; }

            case MAGIK_COMMAND_SET_KERR_MASS_PARAMETER: { is_valid_ = true; size_ = sizeof(magik_command_set_kerr_mass_parameter_t); break; }

            case MAGIK_COMMAND_SET_KERR_DIMENSIONLESS_SPIN_PARAMETER: { is_valid_ = true; size_ = sizeof(magik_command_set_kerr_dimensionless_spin_parameter_t); break; }


            
            // ########################
            // ### 5000-5999 Camera ###
            // ########################
            case MAGIK_COMMAND_SET_ACTIVE_CAMERA: { is_valid_ = true; size_ = sizeof(magik_command_set_active_camera_t); break; }

            case MAGIK_COMMAND_SET_CAMERA_POSITION: { is_valid_ = true; size_ = sizeof(magik_command_set_camera_position_t); break; }

            case MAGIK_COMMAND_SET_CAMERA_ORIENTATION: { is_valid_ = true; size_ = sizeof(magik_command_set_camera_orientation_t); break; }

            case MAGIK_COMMAND_SET_CAMERA_RESOLUTION: { is_valid_ = true; size_ = sizeof(magik_command_set_camera_resolution_t); break; }



            // #######################
            // ### 6000-6999 Color ###
            // #######################
            case MAGIK_COMMAND_SET_N_INTRINSIC_SPECTRAL_IRRADIANCE_BIN: { is_valid_ = true; size_ = sizeof(magik_command_set_n_intrinsic_spectral_irradiance_bin_t); break; }

            case MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MAXIMUM_WAVELENGTH_NM: { is_valid_ = true; size_ = sizeof(magik_command_set_sample_domain_maximum_wavelength_nm_t); break; }

            case MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MINIMUM_WAVELENGTH_NM: { is_valid_ = true; size_ = sizeof(magik_command_set_sample_domain_minimum_wavelength_nm_t); break; }

            case MAGIK_COMMAND_SET_REDISTRIBUTION_STANDARD_DEVIATION_NM: { is_valid_ = true; size_ = sizeof(magik_command_set_redistribution_standard_deviation_nm_t); break; }

            case MAGIK_COMMAND_SET_COLOR_MATCHING_FUNCTION: { is_valid_ = true; size_ = sizeof(magik_command_set_color_matching_function_t); break; }

            case MAGIK_COMMAND_SET_SCENE_COLORSPACE: { is_valid_ = true; size_ = sizeof(magik_command_set_scene_colorspace_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_t); break; }

            case MAGIK_COMMAND_SET_DISPLAY_COLORSPACE: { is_valid_ = true; size_ = sizeof(magik_command_set_display_colorspace_t); break; }

            case MAGIK_COMMAND_SET_OUTPUT_FORMAT: { is_valid_ = true; size_ = sizeof(magik_command_set_output_format_t); break; }

            case MAGIK_COMMAND_SET_WHITE_BALANCE_WHITE_POINT: { is_valid_ = true; size_ = sizeof(magik_command_set_white_balance_white_point_t); break; }

            case MAGIK_COMMAND_SET_WHITE_BALANCE_TINT: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_reinhard_extended_white_luminance_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_START_COMPRESSION: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_khronos_pbr_neutral_start_compression_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_DESATURATION: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_khronos_pbr_neutral_desaturation_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_MODE: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_gt7_mode_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_SDR_PAPER_WHITE_BALANCE: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_gt7_sdr_paper_white_balance_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_REFERENCE_LUMINANCE: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_gt7_reference_luminance_t); break; }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_JZAZBZ_EXPONENT_SCALE_FACTOR: { is_valid_ = true; size_ = sizeof(magik_command_set_view_transform_gt7_jzazbz_exponent_scale_factor_t); break; }



            // ########################
            // ### 7000-7999 Render ###
            // ########################
            case MAGIK_COMMAND_SET_N_GEODESIC_STEP_LIMIT: { is_valid_ = true; size_ = sizeof(magik_command_set_n_geodesic_step_limit_t); break; }

            case MAGIK_COMMAND_SET_N_REFLECTED_LIMIT: { is_valid_ = true; size_ = sizeof(magik_command_set_n_reflected_limit_t); break; }



            default: { break; }
        }

        *is_valid_command = is_valid_;
        *command_size = size_;
    }

    static void apply_command(magik_render_manager* manager, uint32_t* playhead, command_buffer_t* command_buffer, e_magik_cqs_command_types command_type, size_t command_size)
    {
        switch(command_type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER:
            {
                break;
            }

            case MAGIK_COMMAND_SET_STATE_PAUSE:
            {
                break;
            }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER:
            {
                break;
            }

            case MAGIK_COMMAND_ADD_AOV:
            {
                magik_command_add_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                magik::framebuffer_t fb;
                fb.channels = cmd.channels;
                manager->framebuffer_swapchain.render_framebuffer.collection.emplace(aov_name, fb);
                break;
            }

            case MAGIK_COMMAND_REMOVE_AOV:
            {
                magik_command_remove_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                manager->framebuffer_swapchain.render_framebuffer.collection.erase(aov_name);
                break;
            }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF:
            {
                magik_command_printf_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.length_of_text < 512) printf("%.*s \n", cmd.length_of_text, cmd.text);
                break;
            }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // #######################
            // ### 4000-4999 Relativity ###
            // #######################
            case MAGIK_COMMAND_SET_METRIC_MINKOWSKI:
            {
                magik_command_set_metric_minkowski_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.metric_type = MINKOWSKI;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_METRIC_SCHWARZSCHILD:
            {
                magik_command_set_metric_schwarzschild_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.metric_type = SCHWARZSCHILD;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_METRIC_KERR:
            {
                magik_command_set_metric_kerr_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.metric_type = KERR;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_ABSOLUTE_ERROR_TOLERANCE:
            {
                magik_command_set_absolute_error_tolerance_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.absolute_error_tolerance > 0.0f) 
                {
                    manager->stage.relativity_settings.integrator_absolute_error_tolerance = cmd.absolute_error_tolerance;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_RELATIVE_ERROR_TOLERANCE:
            {
                magik_command_set_relative_error_tolerance_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.relative_error_tolerance > 0.0f)
                {
                    manager->stage.relativity_settings.integrator_relative_error_tolerance = cmd.relative_error_tolerance;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_MAX_SUBSTEPS:
            {
                magik_command_set_max_substeps_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.max_substeps > 0)
                {
                    manager->stage.relativity_settings.n_integrator_max_substep = cmd.max_substeps;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_OBSERVER_LOCAL_PROPER_VELOCITY:
            {
                magik_command_set_observer_local_proper_velocity_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.relativity_settings.observer_local_proper_velocity = vec3f{cmd.velocity_x, cmd.velocity_y, cmd.velocity_z};
                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_CELESTIAL_SPHERE_RADIUS:
            {
                magik_command_set_celestial_sphere_radius_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.celestial_sphere_radius > 0.0f)
                {
                    manager->stage.relativity_settings.celestial_sphere_radius = cmd.celestial_sphere_radius;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_SCHWARZSCHILD_EVENT_HORIZON_SCALAR:
            {
                magik_command_set_schwarzschild_event_horizon_scalar_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.scalar > 1.0f)
                {
                    manager->stage.relativity_settings.schwarzschild_event_horizon_scalar = cmd.scalar;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_SCHWARZSCHILD_MASS_PARAMETER:
            {
                magik_command_set_schwarzschild_mass_parameter_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.schwarzschild_mass_parameter = cmd.mass_parameter;
                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_KERR_EVENT_HORIZON_SCALAR:
            {
                magik_command_set_kerr_event_horizon_scalar_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.scalar > 1.0f)
                {
                    manager->stage.relativity_settings.kerr_event_horizon_scalar = cmd.scalar;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_KERR_MASS_PARAMETER:
            {
                magik_command_set_kerr_mass_parameter_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.kerr_mass_parameter = cmd.mass_parameter;
                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_KERR_DIMENSIONLESS_SPIN_PARAMETER:
            {
                magik_command_set_kerr_dimensionless_spin_parameter_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.relativity_settings.kerr_dimensionless_spin_parameter = cmd.dimensionless_spin_parameter;
                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }



            // ########################
            // ### 5000-5999 Camera ###
            // ########################
            case MAGIK_COMMAND_SET_ACTIVE_CAMERA:
            {
                magik_command_set_active_camera_t cmd;
                memcpy(&cmd, playhead, command_size);
                break;
            }

            case MAGIK_COMMAND_SET_CAMERA_POSITION:
            {
                magik_command_set_camera_position_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.optical_system_settings.position.x = cmd.position_x;
                manager->stage.optical_system_settings.position.y = cmd.position_y;
                manager->stage.optical_system_settings.position.z = cmd.position_z;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_CAMERA_ORIENTATION:
            {
                magik_command_set_camera_orientation_t cmd;
                memcpy(&cmd, playhead, command_size);
                mat3f m;
                m.make_identity();
                m = m.rotate(cmd.rotation_z, cmd.rotation_y, cmd.rotation_x);
                manager->stage.optical_system_settings.orientation = m;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }

            case MAGIK_COMMAND_SET_CAMERA_RESOLUTION:
            {
                magik_command_set_camera_resolution_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.x_resolution <= 0) {cmd.x_resolution = 2;}
                if(cmd.y_resolution <= 0) {cmd.y_resolution = 2;}

                manager->stage.optical_system_settings.x_resolution = cmd.x_resolution;
                manager->stage.optical_system_settings.y_resolution = cmd.y_resolution;

                manager->framebuffer_swapchain.clear_render_buffer = true;
                break;
            }



            // #######################
            // ### 6000-6999 Color ###
            // #######################
            case MAGIK_COMMAND_SET_N_INTRINSIC_SPECTRAL_IRRADIANCE_BIN:
            {
                magik_command_set_n_intrinsic_spectral_irradiance_bin_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.n_isi_bin > 0 && cmd.n_isi_bin <= 64)
                {
                    manager->stage.color_settings.n_isi_bin = cmd.n_isi_bin;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MAXIMUM_WAVELENGTH_NM:
            {
                magik_command_set_sample_domain_maximum_wavelength_nm_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.maximum_wavelength_nm > 0.0f)
                {
                    manager->stage.color_settings.isi_max_wavelength_nm = cmd.maximum_wavelength_nm;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MINIMUM_WAVELENGTH_NM:
            {
                magik_command_set_sample_domain_minimum_wavelength_nm_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.minimum_wavelength_nm > 0.0f)
                {
                    manager->stage.color_settings.isi_min_wavelength_nm = cmd.minimum_wavelength_nm;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_REDISTRIBUTION_STANDARD_DEVIATION_NM:
            {
                magik_command_set_redistribution_standard_deviation_nm_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.standard_deviation_nm > 0.0f)
                {
                    manager->stage.color_settings.redistribution_standard_deviation_nm = cmd.standard_deviation_nm;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_COLOR_MATCHING_FUNCTION:
            {
                magik_command_set_color_matching_function_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.cmf_type = cmd.cmf_type;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_SCENE_COLORSPACE:
            {
                magik_command_set_scene_colorspace_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.scene_colorspace_type = cmd.scene_colorspace;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM:
            {
                magik_command_set_view_transform_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.view_transform_type = cmd.view_transform;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_DISPLAY_COLORSPACE:
            {
                magik_command_set_display_colorspace_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.display_colorspace_type = cmd.display_colorspace;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_OUTPUT_FORMAT:
            {
                magik_command_set_output_format_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.output_format = cmd.output_format;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_WHITE_BALANCE_WHITE_POINT:
            {
                magik_command_set_white_balance_white_point_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.white_point = cmd.white_point_kelvin;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_WHITE_BALANCE_TINT:
            {
                magik_command_set_white_balance_tint_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.tint = cmd.tint;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_REINHARD_EXTENDED_WHITE_LUMINANCE:
            {
                magik_command_set_view_transform_reinhard_extended_white_luminance_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.vt_reinhard_extended_white_luminance = cmd.white_luminance;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_START_COMPRESSION:
            {
                magik_command_set_view_transform_khronos_pbr_neutral_start_compression_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.vt_khronos_pbr_neutral_start_compression = cmd.start_compression;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_DESATURATION:
            {
                magik_command_set_view_transform_khronos_pbr_neutral_desaturation_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.vt_khronos_pbr_neutral_desaturation = cmd.desaturation;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_MODE:
            {
                magik_command_set_view_transform_gt7_mode_t cmd;
                memcpy(&cmd, playhead, command_size);

                manager->stage.color_settings.vt_gt7_mode= cmd.mode;
                manager->framebuffer_swapchain.clear_render_buffer = true;

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_SDR_PAPER_WHITE_BALANCE:
            {
                magik_command_set_view_transform_gt7_sdr_paper_white_balance_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.sdr_paper_white_balance > 0.0f)
                {
                    manager->stage.color_settings.vt_gt7_sdr_paper_white = cmd.sdr_paper_white_balance;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_REFERENCE_LUMINANCE:
            {
                magik_command_set_view_transform_gt7_reference_luminance_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.reference_luminance > 0.0f)
                {
                    manager->stage.color_settings.vt_gt7_reference_luminance = cmd.reference_luminance;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_JZAZBZ_EXPONENT_SCALE_FACTOR:
            {
                magik_command_set_view_transform_gt7_jzazbz_exponent_scale_factor_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.jzazbz_exponent_scale_factor > 1.0f)
                {
                    manager->stage.color_settings.vt_gt7_jzazbz_exponent_scale_factor = cmd.jzazbz_exponent_scale_factor;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }



            // ########################
            // ### 7000-7999 Render ###
            // ######################## 
            case MAGIK_COMMAND_SET_N_GEODESIC_STEP_LIMIT:
            {
                magik_command_set_n_geodesic_step_limit_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.n_geodesic_step_limit > 0)
                {
                    manager->stage.render_settings.n_geodesic_step_limit = cmd.n_geodesic_step_limit;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }

            case MAGIK_COMMAND_SET_N_REFLECTED_LIMIT:
            {
                magik_command_set_n_reflected_limit_t cmd;
                memcpy(&cmd, playhead, command_size);

                if(cmd.n_reflected_limit > 0)
                {
                    manager->stage.render_settings.n_reflected_limit = cmd.n_reflected_limit;
                    manager->framebuffer_swapchain.clear_render_buffer = true;
                }

                break;
            }



            default:
            {
                break;
            }
        }
    }

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command)
    {
        if(!manager || !command) return MAGIK_ERROR_INVALID_POINTER;

        if(reinterpret_cast<uintptr_t>(command) % sizeof(uint32_t) != 0) return MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED;

        e_magik_cqs_command_types command_type;
        memcpy(&command_type, command, sizeof(e_magik_cqs_command_types)); 
        
        bool is_valid = false;
        size_t command_size = 0;
        fetch_command_info(command_type, &is_valid, &command_size);

        if(!is_valid) return MAGIK_ERROR_INVALID_COMMAND;

        if(command_size % sizeof(uint32_t) != 0) return MAGIK_ERROR_COMMAND_SIZE_NOT_A_MULTIPLE_OF_4;

        size_t command_buffer_occupancy = (size_t)(manager->command_context.front->n_occupied_chunk)*sizeof(uint32_t);
        size_t command_buffer_capacity = (size_t)(manager->command_context.n_reserved_chunk)*sizeof(uint32_t);

        if((command_buffer_occupancy+command_size) > command_buffer_capacity)
        {
            if(manager->command_context.drop_overflows)
            {
                return MAGIK_SUCCESS;
            }
            else
            {
                return MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW;
            }
        }

        uint32_t* head_ptr = manager->command_context.front->data.get() + manager->command_context.front->n_occupied_chunk;
        memcpy(head_ptr, command, command_size);
        manager->command_context.front->n_occupied_chunk += static_cast<uint32_t>(command_size / sizeof(uint32_t));

        return MAGIK_SUCCESS;
    }

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
    {
        if(!manager) 
        {
            *is_dispatched = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(manager->command_context.is_swap_ready.load(std::memory_order_acquire))
        {
            manager->command_context.front.swap(manager->command_context.back);
            manager->command_context.is_swap_ready.store(false, std::memory_order_release);

            *is_dispatched = true;
            return MAGIK_SUCCESS;
        }
        else
        {
            *is_dispatched = false;
            return MAGIK_SUCCESS;
        }
    }

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, command_buffer_t* command_buffer)
    {
        /*
        * We ultimately want to apply the commands on the DCC as well to maintain a 
        * mirror copy of the render graph. This can be done with this function, we 
        * just need to copy the buffer before consuming it. 
        * And, once it exists, pass in the correct render graph. 
        */

        if(!manager) return MAGIK_ERROR_INVALID_POINTER;

        size_t command_buffer_occupancy = (size_t)(command_buffer->n_occupied_chunk);
        uint32_t* playhead = command_buffer->data.get();
        size_t playhead_offset = 0;

        e_magik_cqs_command_types command_type;
        bool is_valid = false;
        size_t command_size = 0;

        while(command_buffer_occupancy > playhead_offset)
        {
            memcpy(&command_type, (playhead + playhead_offset), sizeof(e_magik_cqs_command_types));

            fetch_command_info(command_type, &is_valid, &command_size);

            if(!is_valid || command_size == 0 || (command_size % sizeof(uint32_t) != 0)) return MAGIK_ERROR_INVALID_COMMAND;

            if(((playhead_offset + command_size) / sizeof(uint32_t)) > command_buffer_occupancy) return MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ;

            apply_command(manager, (playhead + playhead_offset), command_buffer, command_type, command_size);

            playhead_offset += (command_size/sizeof(uint32_t));
        }

        command_buffer->n_occupied_chunk = 0;
        return MAGIK_SUCCESS;
    }

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager)
    {
        e_magik_result_types error = consume_command_buffer(manager, manager->command_context.back.get());
        manager->command_context.is_swap_ready.store(true, std::memory_order_release);
        return error;
    }
}
