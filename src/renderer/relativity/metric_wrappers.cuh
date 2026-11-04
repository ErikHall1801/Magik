#pragma once

#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    struct compute_contravariant_timelike_component_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec3f dimensionless_observer_three_vector{}; 
        float squared_norm{}; 
        e_magik_spacetime_metric_types metric_type{}; 
        float kerr_spin_parameter{};    
    };

    MAGIK_DEVICE_HOST static float compute_contravariant_timelike_component(compute_contravariant_timelike_component_t args)
    {
        float result{};

        switch(args.metric_type)
        {
            case e_magik_spacetime_metric_types::MINKOWSKI:
            {
                result = minkowski_compute_timelike_component_contravariant(args.dimensionless_observer_three_vector, args.squared_norm);
                break;
            }

            case e_magik_spacetime_metric_types::SCHWARZSCHILD:
            {
                result = schwarzschild_compute_timelike_component_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.dimensionless_observer_three_vector, args.squared_norm});
                break;
            }

            case e_magik_spacetime_metric_types::KERR:
            {
                result = kerr_compute_timelike_component_contravariant({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.dimensionless_observer_three_vector, args.kerr_spin_parameter, args.squared_norm});
                break;
            }
        }

        return result;
    }

    struct compute_rest_frame_four_velocity_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{}; 
        vec4f contravariant_seed_vector_z{}; 
        vec3f dimensionless_three_velocity{}; 
        e_magik_spacetime_metric_types metric_type{}; 
        float kerr_spin_parameter{};
    };

    MAGIK_DEVICE_HOST static vec4f compute_rest_frame_four_velocity(compute_rest_frame_four_velocity_t args)
    {
        vec4f result{};

        switch(args.metric_type)
        {
            case e_magik_spacetime_metric_types::MINKOWSKI:
            {
                result = minkowski_object_velocity_from_ZAMO_to_global({args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_three_velocity});
                break;
            }

            case e_magik_spacetime_metric_types::SCHWARZSCHILD:
            {
                result = schwarzschild_object_velocity_from_ZAMO_to_global({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_three_velocity});
                break;
            }

            case e_magik_spacetime_metric_types::KERR:
            {
                result = kerr_object_velocity_from_ZAMO_to_global({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_three_velocity, args.kerr_spin_parameter});
                break;
            }
        }

        return result;
    }

    struct convert_rest_frame_direction_to_global_four_momentum_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{}; 
        vec4f contravariant_seed_vector_z{}; 
        vec3f dimensionless_spatial_vector{}; 
        vec4f dimensionless_observer_four_velocity{}; 
        float squared_norm{}; 
        e_magik_spacetime_metric_types metric_type{}; 
        float kerr_spin_parameter{};
    };

    MAGIK_DEVICE_HOST static vec4f convert_rest_frame_direction_to_global_four_momentum(convert_rest_frame_direction_to_global_four_momentum_t args)
    {
        vec4f result;

        switch(args.metric_type)
        {
            case e_magik_spacetime_metric_types::MINKOWSKI:
            {
                result = minkowski_observer_rest_frame_to_global({args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_spatial_vector, args.dimensionless_observer_four_velocity, args.squared_norm});
                result = minkowski_lower_index(result);
                break;
            }

            case e_magik_spacetime_metric_types::SCHWARZSCHILD:
            {
                result = schwarzschild_observer_rest_frame_to_global({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_spatial_vector, args.dimensionless_observer_four_velocity, args.squared_norm});
                result = schwarzschild_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, result);
                break;
            }

            case e_magik_spacetime_metric_types::KERR:
            {
                result = kerr_observer_rest_frame_to_global({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_spatial_vector, args.dimensionless_observer_four_velocity, args.kerr_spin_parameter, args.squared_norm});
                result = kerr_lower_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, result, args.kerr_spin_parameter);
                break;
            }
        }

        return result;
    }

    struct convert_global_to_rest_frame_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f contravariant_seed_vector_x{}; 
        vec4f contravariant_seed_vector_y{}; 
        vec4f contravariant_seed_vector_z{}; 
        vec4f dimensionless_four_vector{}; 
        vec4f dimensionless_observer_four_velocity{}; 
        float squared_norm{}; 
        e_magik_spacetime_metric_types metric_type{}; 
        float kerr_spin_parameter{};
    };

    MAGIK_DEVICE_HOST static vec4f convert_global_to_rest_frame(convert_global_to_rest_frame_t args)
    {
        vec4f result;

        switch(args.metric_type)
        {
            case e_magik_spacetime_metric_types::MINKOWSKI:
            {
                result = minkowski_global_to_observer_rest_frame({args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_four_vector, args.dimensionless_observer_four_velocity, args.squared_norm});
                break;
            }

            case e_magik_spacetime_metric_types::SCHWARZSCHILD:
            {
                result = schwarzschild_global_to_observer_rest_frame({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_four_vector, args.dimensionless_observer_four_velocity, args.squared_norm});
                break;
            }

            case e_magik_spacetime_metric_types::KERR:
            {
                result = kerr_global_to_observer_rest_frame({args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.contravariant_seed_vector_x, args.contravariant_seed_vector_y, args.contravariant_seed_vector_z, args.dimensionless_four_vector, args.dimensionless_observer_four_velocity, args.kerr_spin_parameter, args.squared_norm});
                break;
            }
        }

        return result;
    }

    struct raise_index_t
    {
        float dimensionless_x{}; 
        float dimensionless_y{}; 
        float dimensionless_z{}; 
        vec4f covariant_vector{}; 
        e_magik_spacetime_metric_types metric_type{}; 
        float kerr_spin_parameter{};
    };

    MAGIK_DEVICE_HOST static vec4f raise_index(raise_index_t args)
    {
        vec4f result;

        switch(args.metric_type)
        {
            case e_magik_spacetime_metric_types::MINKOWSKI:
            {
                result = minkowski_raise_index(args.covariant_vector);
                break;
            }

            case e_magik_spacetime_metric_types::SCHWARZSCHILD:
            {
                result = schwarzschild_raise_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.covariant_vector);
                break;
            }

            case e_magik_spacetime_metric_types::KERR:
            {
                result = kerr_raise_index(args.dimensionless_x, args.dimensionless_y, args.dimensionless_z, args.covariant_vector, args.kerr_spin_parameter);
                break;
            }
        }
    
        return result;
    }
}
