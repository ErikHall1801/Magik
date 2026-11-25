#include "command.h"

namespace magik
{
    template<typename F> struct command_traits_t;

    template<typename F, typename P> struct command_traits_t<command_result_t (F::*)(command_context_t, const P&) const> { using payload_t = P; };

    template<e_magik_cqs_command_types cmd_id, typename F> consteval command_element_t command(F)
    {
        using P = typename command_traits_t<decltype(&F::operator())>::payload_t;

        static_assert(std::is_empty_v<F>, "Command lambdas must not capture anything");
        static_assert(std::is_trivially_copyable_v<P> && std::is_standard_layout_v<P>, "Payload must be a plain C struct");
        static_assert(sizeof(P) % 4 == 0, "Payload size must be a multiple of 4");

        return
        {
            static_cast<uint32_t>(cmd_id), 
            sizeof(P), 
            [](command_context_t ctx, const void* raw) -> command_result_t
            {
                P cmd; std::memcpy(&cmd, raw, sizeof(P));
                return F{}(ctx, cmd);
            }
        };
    }

    template<typename E> constexpr void raise_update_policy(E& current, E level)
    {
        static_assert(std::is_enum_v<E>, "raise() is for update-policy enums");
        if(level > current) current = level;
    }

    constexpr command_result_t ok() { return {MAGIK_RESULT_SEVERITY_NONE, MAGIK_SUCCESS}; }

    constexpr command_result_t warning(e_magik_result_types c) { return { MAGIK_RESULT_SEVERITY_WARNING, c}; }

    constexpr command_result_t fatal(e_magik_result_types c) { return {MAGIK_RESULT_SEVERITY_FATAL, c }; }

    constexpr auto command_registry = std::to_array<command_element_t>
    ({
        // ##################################
        // ### 1000-1999 Basic operations ###
        // ##################################
        command<MAGIK_COMMAND_SET_STATE_RENDER>
        (
            [](command_context_t ctx, const magik_command_set_state_render_t& cmd)
            {
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_STATE_PAUSE>
        (
            [](command_context_t ctx, const magik_command_set_state_pause_t& cmd)
            {
                return ok();
            }
        ),

        command<MAGIK_COMMAND_CLEAR_RENDER_BUFFER>
        (
            [](command_context_t ctx, const magik_command_clear_render_buffer_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                return ok();
            }
        ),

        command<MAGIK_COMMAND_ADD_AOV>
        (
            [](command_context_t ctx, const magik_command_add_aov_t& cmd)
            {
                std::string aov_name(cmd.name, cmd.length_of_name);
                magik::framebuffer_t fb;
                fb.channels = cmd.channels;
                ctx.framebuffer_swapchain.render_framebuffer.collection.emplace(aov_name, fb);
                return ok();
            }
        ),

        command<MAGIK_COMMAND_REMOVE_AOV>
        (
            [](command_context_t ctx, const magik_command_remove_aov_t& cmd)
            {
                std::string aov_name(cmd.name, cmd.length_of_name);
                ctx.framebuffer_swapchain.render_framebuffer.collection.erase(aov_name);
                return ok();
            }
        ),

        // ################################
        // ### 2000-2999 Built-in tests ###
        // ################################
        command<MAGIK_COMMAND_PRINTF>
        (
            [](command_context_t ctx, const magik_command_printf_t& cmd)
            {
                if(cmd.length_of_text < 512) printf("%.*s \n", cmd.length_of_text, cmd.text);
                return ok();
            }
        ),

        // ##########################
        // ### 3000-3999 Settings ###
        // ##########################

        // ############################
        // ### 4000-4999 Relativity ###
        // ############################
        command<MAGIK_COMMAND_SET_METRIC_MINKOWSKI>
        (
            [](command_context_t ctx, const magik_command_set_metric_minkowski_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.metric_type = MINKOWSKI;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_METRIC_SCHWARZSCHILD>
        (
            [](command_context_t ctx, const magik_command_set_metric_schwarzschild_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.metric_type = SCHWARZSCHILD;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_METRIC_KERR>
        (
            [](command_context_t ctx, const magik_command_set_metric_kerr_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.metric_type = KERR;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_ABSOLUTE_ERROR_TOLERANCE>
        (
            [](command_context_t ctx, const magik_command_set_absolute_error_tolerance_t& cmd)
            {
                if(cmd.absolute_error_tolerance <= 0.0f) {  return warning(MAGIK_ERROR_INVALID_VALUE_RANGE); }
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.integrator_absolute_error_tolerance = cmd.absolute_error_tolerance;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_RELATIVE_ERROR_TOLERANCE>
        (
            [](command_context_t ctx, const magik_command_set_relative_error_tolerance_t& cmd)
            {
                if(cmd.relative_error_tolerance<= 0.0f) { return warning(MAGIK_ERROR_INVALID_VALUE_RANGE); }
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.integrator_relative_error_tolerance = cmd.relative_error_tolerance;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_MAX_SUBSTEPS>
        (
            [](command_context_t ctx, const magik_command_set_max_substeps_t& cmd)
            {
                if(cmd.max_substeps < 2) { return warning(MAGIK_ERROR_INSUFFICIENT_SUBSTEPS); }
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.n_integrator_max_substep = cmd.max_substeps;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_OBSERVER_LOCAL_PROPER_VELOCITY>
        (
            [](command_context_t ctx, const magik_command_set_observer_local_proper_velocity_t& cmd)
            {
                if(isnan(cmd.velocity_x*cmd.velocity_y*cmd.velocity_z) || isinf(cmd.velocity_x*cmd.velocity_y*cmd.velocity_z)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.observer_local_proper_velocity = vec3f{cmd.velocity_x, cmd.velocity_y, cmd.velocity_z};
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_CELESTIAL_SPHERE_RADIUS>
        (
            [](command_context_t ctx, const magik_command_set_celestial_sphere_radius_t& cmd)
            {
                if(isnan(cmd.celestial_sphere_radius) || isinf(cmd.celestial_sphere_radius) || cmd.celestial_sphere_radius < 0.0f) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.celestial_sphere_radius = cmd.celestial_sphere_radius;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_SCHWARZSCHILD_EVENT_HORIZON_SCALAR>
        (
            [](command_context_t ctx, const magik_command_set_schwarzschild_event_horizon_scalar_t& cmd)
            {
                if(isnan(cmd.scalar) || isinf(cmd.scalar) || cmd.scalar < 1.0f) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.schwarzschild_event_horizon_scalar = cmd.scalar;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_SCHWARZSCHILD_MASS_PARAMETER>
        (
            [](command_context_t ctx, const magik_command_set_schwarzschild_mass_parameter_t& cmd)
            {
                if(isnan(cmd.mass_parameter) || isinf(cmd.mass_parameter)) return warning(MAGIK_ERROR_INVALID_METRIC_PARAMETER);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.schwarzschild_mass_parameter = cmd.mass_parameter;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_KERR_EVENT_HORIZON_SCALAR>
        (
            [](command_context_t ctx, const magik_command_set_kerr_event_horizon_scalar_t& cmd)
            {
                if(isnan(cmd.scalar) || isinf(cmd.scalar) || cmd.scalar < 1.0f) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.kerr_event_horizon_scalar = cmd.scalar;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_KERR_MASS_PARAMETER>
        (
            [](command_context_t ctx, const magik_command_set_kerr_mass_parameter_t& cmd)
            {
                if(isnan(cmd.mass_parameter) || isinf(cmd.mass_parameter)) return warning(MAGIK_ERROR_INVALID_METRIC_PARAMETER);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.kerr_mass_parameter = cmd.mass_parameter;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_KERR_DIMENSIONLESS_SPIN_PARAMETER>
        (
            [](command_context_t ctx, const magik_command_set_kerr_dimensionless_spin_parameter_t& cmd)
            {
                if(isnan(cmd.dimensionless_spin_parameter) || isinf(cmd.dimensionless_spin_parameter)) return warning(MAGIK_ERROR_INVALID_METRIC_PARAMETER);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.relativity_settings.kerr_dimensionless_spin_parameter = cmd.dimensionless_spin_parameter;
                return ok();
            }
        ),

        // ########################
        // ### 5000-5999 Camera ###
        // ########################
        command<MAGIK_COMMAND_SET_ACTIVE_CAMERA>
        (
            [](command_context_t ctx, const magik_command_set_active_camera_t& cmd)
            {
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_CAMERA_POSITION>
        (
            [](command_context_t ctx, const magik_command_set_camera_position_t& cmd)
            {
                vec3f p = vec3f{cmd.position_x, cmd.position_y, cmd.position_z};
                if(isnan(p.length2()) || isinf(p.length2())) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.optical_system_settings.position = p;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_CAMERA_ORIENTATION>
        (
            [](command_context_t ctx, const magik_command_set_camera_orientation_t& cmd)
            {
                if(isnan(cmd.rotation_x*cmd.rotation_y*cmd.rotation_z) || isinf(cmd.rotation_x*cmd.rotation_y*cmd.rotation_z)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                mat3f m;
                m.make_identity();
                m = m.rotate(cmd.rotation_z, cmd.rotation_y, cmd.rotation_x);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.optical_system_settings.orientation = m;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_CAMERA_RESOLUTION>
        (
            [](command_context_t ctx, const magik_command_set_camera_resolution_t& cmd)
            {
                uint32_t x_ = cmd.x_resolution, y_ = cmd.y_resolution;
                if(isnan(x_*y_) || isinf(x_*y_) || (x_ <= 2) || (y_ <= 2)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC);
                raise_update_policy(ctx.framebuffer_update_policy, MAGIK_FRAMEBUFFER_UPDATE_POLICY_REALLOC_RENDERBUFFER);
                ctx.stage.optical_system_settings.x_resolution = x_;
                ctx.stage.optical_system_settings.y_resolution = y_;
                return ok();
            }
        ),

        // #######################
        // ### 6000-6999 Color ###
        // #######################
        command<MAGIK_COMMAND_SET_N_INTRINSIC_SPECTRAL_IRRADIANCE_BIN>
        (
            [](command_context_t ctx, const magik_command_set_n_intrinsic_spectral_irradiance_bin_t& cmd)
            {
                if(isnan(cmd.n_isi_bin) || isinf(cmd.n_isi_bin) || (cmd.n_isi_bin > 64) || (cmd.n_isi_bin == 0)) return warning(MAGIK_ERROR_INVALID_BIN_COUNT);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.n_isi_bin = cmd.n_isi_bin;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MAXIMUM_WAVELENGTH_NM>
        (
            [](command_context_t ctx, const magik_command_set_sample_domain_maximum_wavelength_nm_t& cmd)
            {
                if(isnan(cmd.maximum_wavelength_nm) || isinf(cmd.maximum_wavelength_nm) || (ctx.stage.color_settings.isi_min_wavelength_nm > cmd.maximum_wavelength_nm) || (cmd.maximum_wavelength_nm < 0.0f)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.isi_max_wavelength_nm = cmd.maximum_wavelength_nm;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MINIMUM_WAVELENGTH_NM>
        (
            [](command_context_t ctx, const magik_command_set_sample_domain_minimum_wavelength_nm_t& cmd)
            {
                if(isnan(cmd.minimum_wavelength_nm) || isinf(cmd.minimum_wavelength_nm) || (ctx.stage.color_settings.isi_max_wavelength_nm < cmd.minimum_wavelength_nm) || (cmd.minimum_wavelength_nm < 0.0f)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.isi_min_wavelength_nm = cmd.minimum_wavelength_nm;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_REDISTRIBUTION_STANDARD_DEVIATION_NM>
        (
            [](command_context_t ctx, const magik_command_set_redistribution_standard_deviation_nm_t& cmd)
            {
                if(isnan(cmd.standard_deviation_nm) || isinf(cmd.standard_deviation_nm) || (cmd.standard_deviation_nm < 0.0f)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.color_settings.redistribution_standard_deviation_nm = cmd.standard_deviation_nm;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_COLOR_MATCHING_FUNCTION>
        (
            [](command_context_t ctx, const magik_command_set_color_matching_function_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.cmf_type = cmd.cmf_type;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_SCENE_COLORSPACE>
        (
            [](command_context_t ctx, const magik_command_set_scene_colorspace_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.scene_colorspace_type = cmd.scene_colorspace;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_t& cmd)
            {
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.view_transform_type = cmd.view_transform;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_DISPLAY_COLORSPACE>
        (
            [](command_context_t ctx, const magik_command_set_display_colorspace_t& cmd)
            {
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.display_colorspace_type = cmd.display_colorspace;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_OUTPUT_FORMAT>
        (
            [](command_context_t ctx, const magik_command_set_output_format_t& cmd)
            {
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.output_format = cmd.output_format;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_WHITE_BALANCE_WHITE_POINT>
        (
            [](command_context_t ctx, const magik_command_set_white_balance_white_point_t& cmd)
            {
                if(isnan(cmd.white_point_kelvin) || isinf(cmd.white_point_kelvin)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.white_point = cmd.white_point_kelvin;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_WHITE_BALANCE_TINT>
        (
            [](command_context_t ctx, const magik_command_set_white_balance_tint_t& cmd)
            {
                if(isnan(cmd.tint) || isinf(cmd.tint)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT);
                ctx.stage.color_settings.tint = cmd.tint;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_REINHARD_EXTENDED_WHITE_LUMINANCE>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_reinhard_extended_white_luminance_t& cmd)
            {
                if(isnan(cmd.white_luminance) || isinf(cmd.white_luminance)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_reinhard_extended_white_luminance = cmd.white_luminance;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_START_COMPRESSION>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_khronos_pbr_neutral_start_compression_t& cmd)
            {
                if(isnan(cmd.start_compression) || isinf(cmd.start_compression)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_khronos_pbr_neutral_start_compression = cmd.start_compression;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_DESATURATION>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_khronos_pbr_neutral_desaturation_t& cmd)
            {
                if(isnan(cmd.desaturation) || isinf(cmd.desaturation)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_khronos_pbr_neutral_desaturation = cmd.desaturation;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_MODE>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_gt7_mode_t& cmd)
            {
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_gt7_mode = cmd.mode;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_SDR_PAPER_WHITE_BALANCE>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_gt7_sdr_paper_white_balance_t& cmd)
            {
                if(isnan(cmd.sdr_paper_white_balance) || isinf(cmd.sdr_paper_white_balance)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_gt7_sdr_paper_white = cmd.sdr_paper_white_balance;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_REFERENCE_LUMINANCE>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_gt7_reference_luminance_t& cmd)
            {
                if(isnan(cmd.reference_luminance) || isinf(cmd.reference_luminance)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_gt7_reference_luminance = cmd.reference_luminance;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_JZAZBZ_EXPONENT_SCALE_FACTOR>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_gt7_jzazbz_exponent_scale_factor_t& cmd)
            {
                if(isnan(cmd.jzazbz_exponent_scale_factor) || isinf(cmd.jzazbz_exponent_scale_factor) || (cmd.jzazbz_exponent_scale_factor < 1.0f)) return warning(MAGIK_ERROR_INVALID_VALUE_RANGE);
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_gt7_jzazbz_exponent_scale_factor = cmd.jzazbz_exponent_scale_factor;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_VIEW_TRANSFORM_AGX_LOOK>
        (
            [](command_context_t ctx, const magik_command_set_view_transform_agx_look_t& cmd)
            {
                raise_update_policy(ctx.color_pipeline_update_policy, MAGIK_COLOR_PIPELINE_UPDATE_POLICY_RELAXED);
                ctx.stage.color_settings.vt_agx_look = cmd.look;
                return ok();
            }
        ),

        // ########################
        // ### 7000-7999 Render ###
        // ######################## 
        command<MAGIK_COMMAND_SET_N_GEODESIC_STEP_LIMIT>
        (
            [](command_context_t ctx, const magik_command_set_n_geodesic_step_limit_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC);
                ctx.stage.render_settings.n_geodesic_step_limit = cmd.n_geodesic_step_limit;
                return ok();
            }
        ),

        command<MAGIK_COMMAND_SET_N_REFLECTED_LIMIT>
        (
            [](command_context_t ctx, const magik_command_set_n_reflected_limit_t& cmd)
            {
                raise_update_policy(ctx.wavefront_update_policy, MAGIK_WAVEFRONT_UPDATE_POLICY_RESET);
                ctx.stage.render_settings.n_reflected_limit = cmd.n_reflected_limit;
                return ok();
            }
        ),
    });

    static const command_element_t* find_command(uint32_t type)
    {
        for(const auto& e : command_registry) { if(e.id == type) return &e; }
        return nullptr;
    }

    // As is this. 
    e_magik_result_types push_command(command_buffer_t* front_command_buffer, uint32_t n_reserved_chunk, bool drop_overflows, const void* command)
    {
        if(!front_command_buffer || !command) return MAGIK_ERROR_INVALID_POINTER;

        if(reinterpret_cast<uintptr_t>(command) % alignof(uint32_t) != 0) return MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED;

        magik_command_header_t header;
        memcpy(&header, command, sizeof(magik_command_header_t));

        const command_element_t* element = find_command(header.type);
        if(!element) return MAGIK_ERROR_INVALID_COMMAND;
        if(element->size != header.size) return MAGIK_ERROR_COMMAND_SIZE_MISMATCH;

        size_t occupancy = size_t(front_command_buffer->n_occupied_chunk) * sizeof(uint32_t);
        size_t capacity = size_t(n_reserved_chunk) * sizeof(uint32_t);

        if(occupancy + header.size > capacity) return drop_overflows ? MAGIK_SUCCESS : MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW;

        uint32_t* head = front_command_buffer->data.get() + front_command_buffer->n_occupied_chunk;
        memcpy(head, command, header.size);
        front_command_buffer->n_occupied_chunk += header.size / sizeof(uint32_t);

        return MAGIK_SUCCESS;
    }

    bool dispatch_command_buffer(command_swapchain_t& swpc)
    {
        if(!swpc.is_swap_ready.load(std::memory_order_acquire)) return false;
        swpc.front.swap(swpc.back);
        swpc.is_swap_ready.store(false, std::memory_order_release);
        return true;
    }

    static void consume_command_buffer(command_context_t ctx, command_buffer_t* command_buffer)
    {
        command_result_t result;

        size_t command_buffer_occupancy = (size_t)(command_buffer->n_occupied_chunk);
        uint32_t* playhead = command_buffer->data.get();
        size_t playhead_offset = 0;

        while(command_buffer_occupancy > playhead_offset)
        {
            if((command_buffer_occupancy - playhead_offset) < sizeof(magik_command_header_t) / sizeof(uint32_t)) { result.error = MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ; break; }

            magik_command_header_t header;
            memcpy(&header, playhead + playhead_offset, sizeof(magik_command_header_t));
            size_t command_chunks = header.size / sizeof(uint32_t);
            if(command_chunks == 0 || command_chunks > (command_buffer_occupancy - playhead_offset)) { result.error = MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ; break; }

            const command_element_t* entry = find_command(header.type);

            if(entry)
            {
                command_result_t r = entry->apply(ctx, playhead + playhead_offset);
            }

            playhead_offset += command_chunks;
        }

        command_buffer->n_occupied_chunk = 0;
    }

    void consume_back_command_buffer(command_context_t ctx)
    {
        consume_command_buffer(ctx, ctx.command_swapchain.back.get());
        ctx.command_swapchain.is_swap_ready.store(true, std::memory_order_release);
    }
}
