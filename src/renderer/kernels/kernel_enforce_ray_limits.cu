#include "kernel_enforce_ray_limits.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    struct kernel_enforce_ray_limits_args_t
    {
        uint32_t* d_n_geodesic_step = nullptr;
        uint32_t* d_n_reflected = nullptr;
        uint32_t* d_advance_A_queue_count = nullptr;
        uint32_t* d_advance_A_queue_id = nullptr;
        uint32_t* d_advance_B_queue_count = nullptr;
        uint32_t* d_advance_B_queue_id = nullptr;
        uint32_t* d_splat_queue_count = nullptr;
        uint32_t* d_splat_queue_id = nullptr;

        uint32_t n_geodesic_step_limit;
        uint32_t n_reflected_limit;

        __host__ void create(magik_render_manager* manager, wavefront_buffer_t* wb)
        {
            d_n_geodesic_step = wb->ray_pool.get<n_geodesic_step_t>();
            d_n_reflected = wb->ray_pool.get<n_reflected_t>();
            d_advance_A_queue_count = wb->queue_pool.get_count_ptr<advance_A_queue_t>();
            d_advance_A_queue_id = wb->queue_pool.get_id_ptr<advance_A_queue_t>();
            d_advance_B_queue_count = wb->queue_pool.get_count_ptr<advance_B_queue_t>();
            d_advance_B_queue_id = wb->queue_pool.get_id_ptr<advance_B_queue_t>();
            d_splat_queue_count = wb->queue_pool.get_count_ptr<splat_queue_t>();
            d_splat_queue_id = wb->queue_pool.get_id_ptr<splat_queue_t>();

            n_geodesic_step_limit = manager->stage.settings.n_geodesic_step_limit;
            n_reflected_limit = manager->stage.settings.n_reflected_limit;
        }
    };

    static __global__ void kernel_enforce_ray_limits(kernel_enforce_ray_limits_args_t args)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_advance_A_queue_count) return;
        uint32_t ray_id = args.d_advance_A_queue_id[queue_index];

        uint32_t n_geodesic_step = args.d_n_geodesic_step[ray_id];
        uint32_t n_reflected = args.d_n_reflected[ray_id];

        bool terminate = false;

        if(n_geodesic_step > args.n_geodesic_step_limit) { terminate = true; }

        if(n_reflected > args.n_reflected_limit) { terminate = true; }

        uint32_t slot = 0;

        if(terminate)
        {
            slot = atomicAdd(args.d_splat_queue_count, 1);
            args.d_splat_queue_id[slot] = ray_id;
        }
        else
        {
            slot = atomicAdd(args.d_advance_B_queue_count, 1);
            args.d_advance_B_queue_id[slot] = ray_id;
        }
    }

    void launch_kernel_enforce_ray_limits_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_enforce_ray_limits_args_t args;
        args.create(manager, wavefront_buffer);

        kernel_enforce_ray_limits<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(args);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<advance_A_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
