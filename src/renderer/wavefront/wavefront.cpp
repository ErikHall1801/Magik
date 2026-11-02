#include "wavefront.h"
#include "kernel_generate_thin_lens_ray.cuh"
#include "kernel_splat_to_renderbuffer.cuh"
#include "kernel_tmp_advance.cuh"
#include "kernel_intersect.cuh"
#include "kernel_bxdf.cuh"
#include "kernel_enforce_ray_limits.cuh"
#include "kernel_initialize_random_device.cuh"
#include "kernel_redistribute_radiance.cuh"
#include "kernel_utility.cuh"

namespace magik
{
    void realloc_wavefront_buffer(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer, uint32_t n_bin, uint32_t x_resolution_target, uint32_t y_resolution_target)
    {
        if(wavefront_buffer->x_resolution == x_resolution_target && wavefront_buffer->y_resolution == y_resolution_target) return;

        wavefront_buffer->x_resolution = x_resolution_target;
        wavefront_buffer->y_resolution = y_resolution_target;

        wavefront_buffer->release_async(static_cast<cudaStream_t>(user_stream));

        wavefront_buffer->allocate_async(user_stream, n_bin, x_resolution_target, y_resolution_target, true);

        launch_kernel_initialize_random_device_async(user_stream, wavefront_buffer, x_resolution_target, y_resolution_target);

        check_cuda_errors(cudaStreamSynchronize(user_stream));
        check_cuda_errors(cudaGetLastError());
    }

    static void is_work_done_sync(bool* working, uint32_t* advance_d_count, void** user_stream)
    {
        uint32_t h_count = 0;

        memcpy_device_to_host_async(advance_d_count, &h_count, sizeof(uint32_t), user_stream);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
        check_cuda_errors(cudaGetLastError());

        if(h_count == 0)
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

    static void prepair_wavefront_buffer_async(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer)
    {
        wavefront_buffer->queue_pool.reset_all_counts(user_stream);

        wavefront_buffer->ray_pool.memset_async<spectral_radiance_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<step_distance_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<n_step_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->queue_pool.set_count_async<advance_A_queue_t>(wavefront_buffer->x_resolution*wavefront_buffer->y_resolution, user_stream);
    }

    void wavefront_sample(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        /*
        What do we want to do tomorrow ? 

        - Once it works again, the biggest priority is using h_count in the kenrel launch ! 

        - Header cleanup
            - Basically, we should try to not include everything everywhere. 
            - Not sure exactly how. 

        - Wavefromt statistics
            - These will be very important for debugging purposes. 
            - The golden quantity we would like to have is a per-sample queue history
              That is, each time a queue is reset, we record its current count. This
              will tell us how the wavefront drains rays. Or does not. 
            - Other metrics to measure are the total iterations. 
            - We naturally keep the most recent sample and the average for all of these. 
            - Each queue should track its own statistics. This way we can update the 
              stats whenever a queue is reset. 
        */

        bool working = true;
        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 

        prepair_wavefront_buffer_async(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer);

        launch_kernel_generate_thin_lens_ray_async(manager, wavefront_buffer);

        // launch_kernel_generate_initial_geodesic_async

        while(working)
        {
            // launch_kernel_advance_minkowski_async

            // launch_kernel_advance_schwarzschild_async

            // launch_kernel_advance_kerr_async

            launch_kernel_tmp_advance_async(manager, wavefront_buffer); // To replace this

            // launch_kernel_intersect_tlas_affine_async

            // launch_kernel_intersect_tlas_hermite_async

            // launch_kernel_intersect_blas_affine_async

            // launch_kernel_intersect_blas_hermite_async

            launch_kernel_intersect_async(manager, wavefront_buffer); // To replace this

            launch_kernel_bxdf_async(manager, wavefront_buffer);

            launch_kernel_redistribute_radiance_async(manager, wavefront_buffer);

            launch_kernel_enforce_ray_limits_async(manager, wavefront_buffer);

            wavefront_buffer->queue_pool.swap_advance_queues();

            launch_kernel_splat_to_renderbuffer_async(manager, wavefront_buffer, tmp_element->second.d_data);

            is_work_done_sync(&working, wavefront_buffer->queue_pool.get_count_ptr<advance_A_queue_t>(), &manager->cuda_stream); 
        }

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
