#include "wavefront.h"
#include "kernel_generate_thin_lens_ray.cuh"
#include "kernel_splat_to_renderbuffer.cuh"
#include "kernel_generate_initial_conditions.cuh"
#include "kernel_advance_geodesic.cuh"
#include "kernel_intersect.cuh"
#include "kernel_bxdf.cuh"
#include "kernel_enforce_ray_limits.cuh"
#include "kernel_initialize_random_device.cuh"
#include "kernel_redistribute_radiance.cuh"
#include "kernel_utility.cuh"

namespace magik
{
    void realloc_wavefront_buffer(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer, uint32_t n_bin, uint32_t x_resolution_target, uint32_t y_resolution_target, uint32_t n_geodesic_step_limit)
    {
        if(wavefront_buffer->x_resolution == x_resolution_target && wavefront_buffer->y_resolution == y_resolution_target) return;

        wavefront_buffer->x_resolution = x_resolution_target;
        wavefront_buffer->y_resolution = y_resolution_target;

        wavefront_buffer->release_async(static_cast<cudaStream_t>(user_stream));

        wavefront_buffer->allocate_async(user_stream, n_bin, x_resolution_target, y_resolution_target, n_geodesic_step_limit, true);

        launch_kernel_initialize_random_device_async(user_stream, wavefront_buffer, x_resolution_target, y_resolution_target);

        check_cuda_errors(cudaStreamSynchronize(user_stream));
        check_cuda_errors(cudaGetLastError());
    }

    static void is_work_done_sync(bool* working, uint32_t* queue_ceiling, uint32_t* advance_d_count, void** user_stream)
    {
        memcpy_device_to_host_async(advance_d_count, queue_ceiling, sizeof(uint32_t), user_stream);
        // check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());

        if(*queue_ceiling == 0)
        {
            *working = false;
        }
        else
        {
            *working = true;
        }
    }

    void reset_wavefront_process_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        wavefront_buffer->ray_pool.memset_async<sensor_wavelength_nm_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<monte_carlo_weight_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<spectral_radiance_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<intrinsic_spectral_irradiance_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        manager->x_sample.store(0, std::memory_order_release);
    }

    static void prepair_wavefront_buffer_async(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer, uint32_t n_geodesic_step_limit)
    {
        wavefront_buffer->queue_pool.reset_all_counts(user_stream);
        wavefront_buffer->queue_pool.reset_all_count_histories(user_stream, n_geodesic_step_limit);

        wavefront_buffer->ray_pool.memset_async<spectral_radiance_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->ray_pool.memset_async<initial_four_vector_contraction_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<delta_affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->ray_pool.memset_async<n_geodesic_step_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<n_reflected_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->queue_pool.set_count_async<advance_A_queue_t>(wavefront_buffer->x_resolution*wavefront_buffer->y_resolution, user_stream);
        wavefront_buffer->queue_ceiling = wavefront_buffer->x_resolution*wavefront_buffer->y_resolution;

        wavefront_buffer->iteration = 0;
    }

    void wavefront_sample(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        /*
        ### Goal for tomorrow
        - Wavefront performance metrics 
            - The data will be supplied to the DCC in a similar manner to the framebuffer. Magik 
              writes to a tripple buffered queue and the DCC can request the latest capture. 
            - What data do we actually want to capture ? 
            - The biggest one is how quickly each queue drains. So we ideally want to have a 
              histogram of the ID count in each queue over all iterations. Not even an average, 
              as that is kinda meaningless with a moving camera.
            - This should be part of the queue pool itself. We can make a function that stores 
              the count to a parallel array created for each queue. Then we can gobble up the 
              history at the end and send it to the buffer. 

        - h_step sorting (Radix sort ?)

        - Matter slot sorting (Bucket sort) 
            - We can move the sync point to just before the bxdf kernels are launched. This way the 
              Host can only launch kernels which are present in the queue. 
            - What is the idea ? 
            - We start with a scrambled bxdf queue. 
            - A small kernel scans through the queue and records how many times each matter type is 
              present. It is literally an array of size M (M = N matter slots) where each element 
              represents the slot's count. 
            - This data has to be sent to the scheduler as any slot with 0 members means "No launch". 
            - The next step is to scatter. Another kernel the size of the bxdf queue reads the unsorted
              queue and atomically adds it to a sorted one. Where we use the number of elements as an
              offset. So for example if there are 200 0th elements, then the first "1" slot starts at
              id 200. 
              This way the bxdf queue gets sorted. 
        */

        bool working = true;
        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 

        prepair_wavefront_buffer_async(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer, manager->stage.settings.n_geodesic_step_limit);
 
        launch_kernel_generate_thin_lens_ray_async(manager, wavefront_buffer);

        launch_kernel_generate_initial_conditions_async(manager, wavefront_buffer);

        while(working)
        {
            launch_kernel_advance_geodesic_async(manager, wavefront_buffer);

            // launch_kernel_intersect_tlas_affine_async

            // launch_kernel_intersect_tlas_hermite_async

            // launch_kernel_intersect_blas_affine_async

            // launch_kernel_intersect_blas_hermite_async

            launch_kernel_intersect_async(manager, wavefront_buffer);

            launch_kernel_bxdf_async(manager, wavefront_buffer);

            launch_kernel_redistribute_radiance_async(manager, wavefront_buffer);

            launch_kernel_enforce_ray_limits_async(manager, wavefront_buffer);

            wavefront_buffer->queue_pool.swap_advance_queues();

            launch_kernel_splat_to_renderbuffer_async(manager, wavefront_buffer, tmp_element->second.d_data);

            is_work_done_sync(&working, &wavefront_buffer->queue_ceiling, wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>(), &manager->cuda_stream);

            wavefront_buffer->iteration++; // This is safe despite the Async kernels for two reasons. 1. The sync point is above us; 2. When a kernel is launched all arguments are captured. 
        }

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
