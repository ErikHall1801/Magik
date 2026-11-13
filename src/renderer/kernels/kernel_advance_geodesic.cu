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
    struct kernel_advance_geodesic_args_t
    {
        uint32_t* d_advance_queue_count = nullptr;
        uint32_t* d_advance_queue_id = nullptr;
        uint32_t* d_intersect_queue_count = nullptr;
        uint32_t* d_intersect_queue_id = nullptr;

        vec4f* d_next_four_position = nullptr;
        vec4f* d_next_four_momentum = nullptr;
        vec4f* d_current_four_position = nullptr;
        vec4f* d_current_four_momentum = nullptr;
        vec4f* d_momentum_derivative_start = nullptr;
        vec4f* d_momentum_derivative_end = nullptr;
        float* d_affine_parameter = nullptr;
        float* d_delta_affine_parameter = nullptr;
        uint32_t* d_n_geodesic_step = nullptr;

        __host__ void create(wavefront_buffer_t* wb)
        {
            d_advance_queue_count = wb->queue_pool.get_count_ptr<advance_A_queue_t>();
            d_advance_queue_id = wb->queue_pool.get_id_ptr<advance_A_queue_t>();
            d_intersect_queue_count = wb->queue_pool.get_count_ptr<intersect_queue_t>();
            d_intersect_queue_id = wb->queue_pool.get_id_ptr<intersect_queue_t>();  

            d_next_four_position = wb->ray_pool.get<next_four_position_t>();
            d_next_four_momentum = wb->ray_pool.get<next_four_momentum_t>();
            d_current_four_position = wb->ray_pool.get<current_four_position_t>();
            d_current_four_momentum = wb->ray_pool.get<current_four_momentum_t>();
            d_momentum_derivative_start = wb->ray_pool.get<momentum_derivative_start_t>();
            d_momentum_derivative_end = wb->ray_pool.get<momentum_derivative_end_t>();
            d_affine_parameter = wb->ray_pool.get<affine_parameter_t>();
            d_delta_affine_parameter = wb->ray_pool.get<delta_affine_parameter_t>();
            d_n_geodesic_step = wb->ray_pool.get<n_geodesic_step_t>(); 
        }
    };

    template<e_magik_spacetime_metric_types T> static __global__ void kernel_advance_geodesic(typename metric<T>::params_t metric_parameters, kernel_advance_geodesic_args_t args)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_advance_queue_count) return;
        uint32_t ray_id = args.d_advance_queue_id[queue_index];

        geodesic_step_values_t y1, y0{args.d_next_four_position[ray_id], args.d_next_four_momentum[ray_id]};
        float h_step = args.d_delta_affine_parameter[ray_id], h_taken;

        y1 = metric<T>::solve_step(y0, metric_parameters, &h_step, &h_taken);

        args.d_current_four_position[ray_id] = y0.four_position;
        args.d_current_four_momentum[ray_id] = y0.four_momentum;
        args.d_next_four_position[ray_id] = y1.four_position;
        args.d_next_four_momentum[ray_id] = y1.four_momentum;
        args.d_affine_parameter[ray_id] += h_taken;
        args.d_delta_affine_parameter[ray_id] = h_step;

        geodesic_step_values_t ys;
        ys = metric<T>::geodesic_rhs(y0, metric_parameters);
        args.d_momentum_derivative_start[ray_id] = ys.four_momentum;

        ys = metric<T>::geodesic_rhs(y1, metric_parameters);
        args.d_momentum_derivative_end[ray_id] = ys.four_momentum;

        args.d_n_geodesic_step[ray_id]++;

        uint32_t slot = atomicAdd(args.d_intersect_queue_count, 1);
        args.d_intersect_queue_id[slot] = ray_id;
    }

    void launch_kernel_advance_geodesic_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_advance_geodesic_args_t args;
        args.create(wavefront_buffer);
        bool time_reversed = true;

        bool successful = dispatch_metric(manager->stage.settings.metric_type, [&](auto tag)
        {
            constexpr auto T = decltype(tag)::value;
            kernel_advance_geodesic<T><<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(metric<T>::make_params(manager, time_reversed), args);
        });

        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.store_count_in_history<advance_A_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->iteration, manager->stage.settings.n_geodesic_step_limit);
        wavefront_buffer->queue_pool.zero_count_async<advance_A_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));

        if(!successful)
        {
            e_magik_result_types expected = MAGIK_SUCCESS, result = MAGIK_ERROR_UNKNOWN_METRIC;
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            manager->is_running.store(false, std::memory_order_release);
        }
    }
}
