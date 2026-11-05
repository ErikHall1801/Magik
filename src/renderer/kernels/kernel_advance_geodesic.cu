#include "kernel_advance_geodesic.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

#include "kernel_advance_geodesic.cuh"
#include "relativity_utilities.cuh"
#include "metric_minkowski.cuh"
#include "metric_schwarzschild.cuh"
#include "metric_kerr.cuh"

namespace magik
{
    template<e_magik_spacetime_metric_types T> static __global__ void kernel_advance_geodesic(typename metric<T>::params_t parameters, vec4f* d_next_four_position, vec4f* d_next_four_momentum, vec4f* d_current_four_position, vec4f* d_current_four_momentum, vec4f* d_momentum_derivative_start, vec4f* d_momentum_derivative_end, float* d_affine_parameter, float* d_delta_affine_parameter, uint32_t* d_n_geodesic_step, uint32_t* d_advance_queue_count, uint32_t* d_advance_queue_id, uint32_t* d_intersect_queue_count, uint32_t* d_intersect_queue_id)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_advance_queue_count) return;
        uint32_t ray_id = d_advance_queue_id[queue_index];

        geodesic_step_values y1, y0{d_next_four_position[ray_id], d_next_four_momentum[ray_id]};
        float h_step = d_delta_affine_parameter[ray_id];

        y1 = metric<T>::solve_step(y0, parameters, &h_step);

        d_current_four_position[ray_id] = y0.four_position;
        d_current_four_momentum[ray_id] = y0.four_momentum;
        d_next_four_position[ray_id] = y1.four_position;
        d_next_four_momentum[ray_id] = y1.four_momentum;
        d_affine_parameter[ray_id] += h_step;
        d_delta_affine_parameter[ray_id] = h_step;

        geodesic_step_values ys;
        ys = metric<T>::geodesic_rhs(y0, parameters);
        d_momentum_derivative_start[ray_id] = ys.four_momentum;

        ys = metric<T>::geodesic_rhs(y1, parameters);
        d_momentum_derivative_end[ray_id] = ys.four_momentum;

        d_n_geodesic_step[ray_id]++;

        uint32_t slot = atomicAdd(d_intersect_queue_count, 1);
        d_intersect_queue_id[slot] = ray_id;
    }

    void launch_kernel_advance_geodesic_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        vec4f* d_next_four_position = wavefront_buffer->ray_pool.get<next_four_position_t>();
        vec4f* d_next_four_momentum = wavefront_buffer->ray_pool.get<next_four_momentum_t>();
        vec4f* d_current_four_position = wavefront_buffer->ray_pool.get<current_four_position_t>();
        vec4f* d_current_four_momentum = wavefront_buffer->ray_pool.get<current_four_momentum_t>();
        vec4f* d_momentum_derivative_start = wavefront_buffer->ray_pool.get<momentum_derivative_start_t>();
        vec4f* d_momentum_derivative_end = wavefront_buffer->ray_pool.get<momentum_derivative_end_t>();
        float* d_affine_parameter = wavefront_buffer->ray_pool.get<affine_parameter_t>();
        float* d_delta_affine_parameter = wavefront_buffer->ray_pool.get<delta_affine_parameter_t>();

        uint32_t* d_n_geodesic_step = wavefront_buffer->ray_pool.get<n_geodesic_step_t>();

        uint32_t* d_advance_queue_count = wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>();
        uint32_t* d_advance_queue_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();
        uint32_t* d_intersect_queue_count = wavefront_buffer->queue_pool.get_count_ptr<intersect_queue_t>();
        uint32_t* d_intersect_queue_id = wavefront_buffer->queue_pool.get_id_ptr<intersect_queue_t>();

        bool successful = dispatch_metric(manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_advance_geodesic<T><<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(metric<T>::make_params(manager), d_next_four_position, d_next_four_momentum, d_current_four_position, d_current_four_momentum, d_momentum_derivative_start, d_momentum_derivative_end, d_affine_parameter, d_delta_affine_parameter, d_n_geodesic_step, d_advance_queue_count, d_advance_queue_id, d_intersect_queue_count, d_intersect_queue_id);
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<advance_A_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));

        if(!successful) return; // Error 
    }
}
