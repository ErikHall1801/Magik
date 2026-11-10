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

    static void is_work_done_sync(bool* working, uint32_t* queue_ceiling, uint32_t* advance_d_count, void** user_stream)
    {
        memcpy_device_to_host_async(advance_d_count, queue_ceiling, sizeof(uint32_t), user_stream);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
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

    static void prepair_wavefront_buffer_async(cudaStream_t user_stream, wavefront_buffer_t* wavefront_buffer)
    {
        wavefront_buffer->queue_pool.reset_all_counts(user_stream);

        wavefront_buffer->ray_pool.memset_async<spectral_radiance_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->ray_pool.memset_async<initial_four_vector_contraction_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<delta_affine_parameter_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->ray_pool.memset_async<n_geodesic_step_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);
        wavefront_buffer->ray_pool.memset_async<n_reflected_t>(static_cast<cudaStream_t>(user_stream), wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, 0x0);

        wavefront_buffer->queue_pool.set_count_async<advance_A_queue_t>(wavefront_buffer->x_resolution*wavefront_buffer->y_resolution, user_stream);
        wavefront_buffer->queue_ceiling = wavefront_buffer->x_resolution*wavefront_buffer->y_resolution;
    }

    void wavefront_sample(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        /*
        # Remaining items #
        - Wavefront performance metrics 
        - Russian roulette 
        - Host API functions 
        - h_step sorting
        - Bucket sort is simple enough to implement ourselves, so that should be next. 

        5. Sort the bxdf queue by hit-matter type slot. We want to sort the queue such that adjacent 
           elements in it point to rays which hit the same matter type. 
           We want something simple here, Bucket sort seems to be the answer. How does this work ? It
           involves several steps. First, lets define the buffers;
           - d_bxdf_queue_id & d_bxdf_queue_count; Same as we have now 
           - d_bxdf_queue_sorted
           - d_hit_matter_slot; A ray-pool member
           Then there are some related to the sort. All of these are the same size as the number of 
           matter types. 
           - d_matter_count; Rays per slot, that is how many rays hit this matter type  
           - d_matter_offset; Where each slot group starts in the sorted queue
           - d_matter_cursor; Write position during the scatter. 
           Now we can consider the three steps. The first happens during the intersection. We use 
           the matter slot from the hit object to index into the d_matter_count and increment the
           number using atomics.
           Then we generate the offsets. Now note, these offsets are only valid for the sorted 
           queue ! 
           The scatter is very simple too. We basically just look at the ray pool for each item
           of the unsorted queue and insert it based on the cursor. Which is to say, the cursor
           for each matter type starts at the first element of the sorted array, then we can 
           just use atomics to add it.  

        6. We will not get around having to launch # queue ceiling many threads and all matter kernels. 
           But we can be smarter about the rejection. We can give each kernel some info about the 
           sorted queue, most pressingly which slots there are and their range. This way the kernels 
           can pull less memory and potentially terminate faster. 
        */

        bool working = true;
        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 

        prepair_wavefront_buffer_async(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer);

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
        }

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
