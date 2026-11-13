#include "host_trace_geodesic.h"
#include "cuda_host_utilities.h"
#include "magik.h"

#include "kernel_advance_geodesic.cuh"
#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    template<e_magik_spacetime_metric_types T> static __host__ void generate_initial_conditions(typename metric<T>::params_t metric_parameters, magik_trace_geodesic_inital_conditions_t initial_conditions, magik_trace_geodesic_container_t* container)
    {
        mat3f m;
        m = m.make_identity();
        m = m.rotate(initial_conditions.x_rotation, initial_conditions.y_rotation, initial_conditions.z_rotation);

        vec3f initial_spatial_direction = m * vec3f{0.0f, 0.0f, -1.0f};

        vec3f local_basis_x = m * vec3f{1.0f, 0.0f, 0.0f};
        vec3f local_basis_y = m * vec3f{0.0f, 1.0f, 0.0f};
        vec3f local_basis_z = m * vec3f{0.0f, 0.0f, 1.0f};

        contravariant_seed_vectors_t seed_vectors;
        seed_vectors.X = { local_basis_x.x, local_basis_x.y, local_basis_x.z, 0.0f };
        seed_vectors.Y = { local_basis_y.x, local_basis_y.y, local_basis_y.z, 0.0f };
        seed_vectors.Z = { local_basis_z.x, local_basis_z.y, local_basis_z.z, 0.0f };

        float squared_norm;
        vec3f local_proper_velocity;

        if(initial_conditions.test_particle_type == MASSIVE)
        {
            squared_norm = -1.0f;
            local_proper_velocity = vec3f{initial_conditions.local_proper_velocity_x, initial_conditions.local_proper_velocity_y, initial_conditions.local_proper_velocity_z};
            initial_spatial_direction *= (initial_conditions.massive_particle_speed / magik::speed_of_light);
        }
        else
        {
            squared_norm = 0.0f;
            local_proper_velocity = vec3f{initial_conditions.local_proper_velocity_x, initial_conditions.local_proper_velocity_y, initial_conditions.local_proper_velocity_z};
        }

        vec4f initial_four_position = convert_si_position_to_dimensionless_coordinate_system(vec4f{initial_conditions.spatial_position_x, initial_conditions.spatial_position_y, initial_conditions.spatial_position_z, 0.0f}, 0.0f, metric<T>::length_scale(metric_parameters), metric<T>::length_scale(metric_parameters)/magik::speed_of_light);
        vec4f four_velocity = metric<T>::rest_frame_four_velocity(initial_four_position, seed_vectors, local_proper_velocity/magik::speed_of_light, metric_parameters);
        vec4f initial_four_momentum = metric<T>::rest_frame_direction_to_global_four_momentum(initial_four_position, contravariant_seed_vectors_t{}, initial_spatial_direction/metric<T>::length_scale(metric_parameters), four_velocity, squared_norm, metric_parameters);

        geodesic_step_values y0 = { initial_four_position, initial_four_momentum };
        geodesic_step_values ys = metric<T>::geodesic_rhs(y0, metric_parameters);

        container->n_written = 0;
        container->steps[container->n_written].four_position[0] = initial_four_position.x;
        container->steps[container->n_written].four_position[1] = initial_four_position.y;
        container->steps[container->n_written].four_position[2] = initial_four_position.z;
        container->steps[container->n_written].four_position[3] = initial_four_position.t;

        container->steps[container->n_written].four_momentum[0] = initial_four_momentum.x;
        container->steps[container->n_written].four_momentum[1] = initial_four_momentum.y;
        container->steps[container->n_written].four_momentum[2] = initial_four_momentum.z;
        container->steps[container->n_written].four_momentum[3] = initial_four_momentum.t;

        container->steps[container->n_written].moment_derivative[0] = ys.four_momentum.x;
        container->steps[container->n_written].moment_derivative[1] = ys.four_momentum.y;
        container->steps[container->n_written].moment_derivative[2] = ys.four_momentum.z;
        container->steps[container->n_written].moment_derivative[3] = ys.four_momentum.t;
        
        container->steps[container->n_written].four_vector_contraction = vector_dot_product(four_velocity, initial_four_momentum);
        container->steps[container->n_written].affine_parameter = 0.0f;
        container->steps[container->n_written].delta_affine_parameter = metric<T>::initial_h_step();
        container->n_written++;
    }

    template<e_magik_spacetime_metric_types T> static __host__ void trace_geodesic(typename metric<T>::params_t metric_parameters, magik_trace_geodesic_container_t* container)
    {
        geodesic_step_values y0, y1, ys;
        float h_step, h_taken;

        while(container->n_written < container->n_allocated_step)
        {
            auto& prev = container->steps[container->n_written - 1];
            auto& next = container->steps[container->n_written];

            y0.four_position = vec4f{prev.four_position[0], prev.four_position[1], prev.four_position[2], prev.four_position[3]};
            y0.four_momentum = vec4f{prev.four_momentum[0], prev.four_momentum[1], prev.four_momentum[2], prev.four_momentum[3]};
            h_step = prev.delta_affine_parameter, h_taken;

            y1 = metric<T>::solve_step(y0, metric_parameters, &h_step, &h_taken);
            ys = metric<T>::geodesic_rhs(y1, metric_parameters);

            next.four_position[0] = y1.four_position.x;
            next.four_position[1] = y1.four_position.y;
            next.four_position[2] = y1.four_position.z;
            next.four_position[3] = y1.four_position.t;

            next.four_momentum[0] = y1.four_momentum.x;
            next.four_momentum[1] = y1.four_momentum.y;
            next.four_momentum[2] = y1.four_momentum.z;
            next.four_momentum[3] = y1.four_momentum.t;

            next.moment_derivative[0] = ys.four_momentum.x;
            next.moment_derivative[1] = ys.four_momentum.y;
            next.moment_derivative[2] = ys.four_momentum.z;
            next.moment_derivative[3] = ys.four_momentum.t;

            next.four_vector_contraction = prev.four_vector_contraction;
            next.affine_parameter = prev.affine_parameter + h_taken;
            next.delta_affine_parameter = h_step;

            container->n_written++;

            if(metric<T>::in_domain(vec4f{next.four_position[0], next.four_position[1], next.four_position[2], next.four_position[3]}, metric_parameters))
            {
                break;
            }
        }
    }

    template<e_magik_spacetime_metric_types T> static __host__ void apply_length_scale(typename metric<T>::params_t metric_parameters, magik_trace_geodesic_container_t* container)
    {
        float m_length_scale = metric<T>::length_scale(metric_parameters);

        for(uint32_t i = 0; i < container->n_written; i++)
        {
            container->steps[i].four_position[0] *= m_length_scale;
            container->steps[i].four_position[1] *= m_length_scale;
            container->steps[i].four_position[2] *= m_length_scale;
            container->steps[i].four_position[3] *= m_length_scale;
        }
    }

    bool host_trace_geodesic(magik_trace_geodesic_container_t* container, magik_trace_geodesic_inital_conditions_t initial_conditions, magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters)
    {
        bool successful = dispatch_metric(metric_parameters.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;

            generate_initial_conditions<T>(metric<T>::make_params(metric_parameters, integrator_parameters, metric_parameters.time_reversed), initial_conditions, container);
            trace_geodesic<T>(metric<T>::make_params(metric_parameters, integrator_parameters, metric_parameters.time_reversed), container);
            apply_length_scale<T>(metric<T>::make_params(metric_parameters, integrator_parameters, metric_parameters.time_reversed), container);
        });

        return successful;
    }
}
