#include "kernel_generate_initial_conditions.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

#include "kernel_advance_geodesic.cuh"
#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    template<e_magik_spacetime_metric_types T> static __global__ void kernel_generate_initial_conditions(typename metric<T>::params_t parameters, uint32_t x_resolution, uint32_t y_resolution, vec4f* d_initial_observer_three_direction, vec4f* d_initial_observer_three_position, vec4f* d_current_four_position, vec4f* d_current_four_momentum, vec4f* d_next_four_position, vec4f* d_next_four_momentum, float* d_initial_four_vector_contraction, float* d_delta_affine_parameter, contravariant_seed_vectors_t seed_vector, vec3f global_three_velocity)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);

        vec4f observer_three_direction = d_initial_observer_three_direction[thread_id];
        vec4f observer_three_position = d_initial_observer_three_position[thread_id];

        float m_length_scale = metric<T>::length_scale(parameters);
        vec4f initial_four_position = convert_si_position_to_dimensionless_coordinate_system(observer_three_position, 1.0f, m_length_scale, m_length_scale/magik::speed_of_light);
        vec4f four_velocity = metric<T>::rest_frame_four_velocity(initial_four_position, seed_vector, global_three_velocity/magik::speed_of_light, parameters);
        vec4f initial_four_momentum = metric<T>::rest_frame_direction_to_global_four_momentum(initial_four_position, seed_vector, vec3f{observer_three_position.x, observer_three_position.y, observer_three_position.z}/m_length_scale, four_velocity, 0.0f, parameters);

        d_current_four_position[thread_id] = initial_four_position;
        d_current_four_momentum[thread_id] = initial_four_momentum;
        d_next_four_position[thread_id] = initial_four_position;
        d_next_four_momentum[thread_id] = initial_four_momentum;
        d_initial_four_vector_contraction[thread_id] = vector_dot_product(four_velocity, initial_four_momentum);
        d_delta_affine_parameter[thread_id] = metric<T>::initial_h_step();
    }

    void launch_kernel_generate_initial_conditions_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        dim3 threads_per_block = dim3(manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y, 1);
        dim3 n_block = magik::compute_n_blocks(wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y);

        vec4f* d_initial_observer_three_direction = wavefront_buffer->ray_pool.get<initial_observer_three_direction_t>();
        vec4f* d_initial_observer_three_position = wavefront_buffer->ray_pool.get<initial_observer_three_position_t>();
        vec4f* d_current_four_position = wavefront_buffer->ray_pool.get<current_four_position_t>();
        vec4f* d_current_four_momentum = wavefront_buffer->ray_pool.get<current_four_momentum_t>();
        vec4f* d_next_four_position = wavefront_buffer->ray_pool.get<next_four_position_t>();
        vec4f* d_next_four_momentum = wavefront_buffer->ray_pool.get<next_four_momentum_t>();
        float* d_initial_four_vector_contraction = wavefront_buffer->ray_pool.get<initial_four_vector_contraction_t>();
        float* d_delta_affine_parameter = wavefront_buffer->ray_pool.get<delta_affine_parameter_t>();

        contravariant_seed_vectors_t seed_vector;
        vec3f global_three_velocity;

        vec3f local_basis_x = manager->stage.optical_systen.orientation * vec3f{1.0f, 0.0f, 0.0f};
        vec3f local_basis_y = manager->stage.optical_systen.orientation * vec3f{0.0f, 1.0f, 0.0f};
        vec3f local_basis_z = manager->stage.optical_systen.orientation * vec3f{0.0f, 0.0f, 1.0f};

        seed_vector.X = { local_basis_x.x, local_basis_x.y, local_basis_x.z, 0.0f };
        seed_vector.Y = { local_basis_y.x, local_basis_y.y, local_basis_y.z, 0.0f };
        seed_vector.Z = { local_basis_z.x, local_basis_z.y, local_basis_z.z, 0.0f };

        global_three_velocity = manager->stage.optical_systen.orientation * -manager->stage.optical_systen.local_three_velocity;

        bool successful = dispatch_metric(manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_generate_initial_conditions<T><<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(metric<T>::make_params(manager), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, d_initial_observer_three_direction, d_initial_observer_three_position, d_current_four_position, d_current_four_momentum, d_next_four_position, d_next_four_momentum, d_initial_four_vector_contraction, d_delta_affine_parameter, seed_vector, global_three_velocity);
        });

        check_cuda_errors(cudaGetLastError());

        if(!successful) return; // Error 
    }
}
