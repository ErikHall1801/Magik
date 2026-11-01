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
    void realloc_wavefront_ray_buffer(magik_render_manager* manager, wavefront_ray_buffer_t* buffer, uint32_t x_resolution_target, uint32_t y_resolution_target)
    {
        if(buffer->x_resolution == x_resolution_target && buffer->y_resolution == y_resolution_target) return;

        destroy_wavefront_ray_buffer(buffer);

        buffer->x_resolution = x_resolution_target;
        buffer->y_resolution = y_resolution_target;

        size_t size_of_vec3f_buffer = x_resolution_target*y_resolution_target*sizeof(vec3f);
        size_t size_of_float_buffer = x_resolution_target*y_resolution_target*sizeof(float);
        size_t size_of_uint32_t_buffer = x_resolution_target*y_resolution_target*sizeof(uint32_t);
        size_t size_of_curandState_t_buffer = x_resolution_target*y_resolution_target*sizeof(curandState_t);
        size_t size_of_redistribute_buffer = static_cast<size_t>(x_resolution_target*y_resolution_target*manager->stage.settings.n_spectral_irradiance_bin)*sizeof(float);

        // bxdf
        buffer->ray_pool.d_sensor_wavelength_nm = magik::allocate_device<float>(size_of_float_buffer);
        buffer->ray_pool.d_monte_carlo_weight = magik::allocate_device<float>(size_of_float_buffer);
        buffer->ray_pool.d_spectral_radiance = magik::allocate_device<float>(size_of_float_buffer);
        buffer->ray_pool.d_intrinsic_spectral_irradiance = magik::allocate_device<float>(size_of_redistribute_buffer);

        magik::memset_device_sync<float>(buffer->ray_pool.d_sensor_wavelength_nm, 0x0, size_of_float_buffer);
        magik::memset_device_sync<float>(buffer->ray_pool.d_monte_carlo_weight, 0x0, size_of_float_buffer);
        magik::memset_device_sync<float>(buffer->ray_pool.d_spectral_radiance, 0x0, size_of_float_buffer);
        magik::memset_device_sync<float>(buffer->ray_pool.d_intrinsic_spectral_irradiance, 0x0, size_of_redistribute_buffer);



        // bah !!!
        buffer->ray_pool.d_dir = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_pos = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_step_distance = magik::allocate_device<float>(size_of_float_buffer);
        buffer->ray_pool.n_step = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->ray_pool.hit_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->ray_pool.hit_normal = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_random_device = magik::allocate_device<curandState_t>(size_of_curandState_t_buffer);

        magik::memset_device_sync<uint32_t>(buffer->ray_pool.n_step, 0x0, size_of_uint32_t_buffer);
        magik::memset_device_sync<float>(buffer->ray_pool.d_step_distance, 0x0, size_of_float_buffer);
        magik::launch_kernel_initialize_random_device_sync(&manager->cuda_stream, buffer->ray_pool, buffer->x_resolution, buffer->y_resolution);

        buffer->advance_queue_A.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->advance_queue_A.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->advance_queue_B.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->advance_queue_B.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->intersect_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->intersect_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->bxdf_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->bxdf_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->redistribute_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->redistribute_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->splat_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->splat_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
    }

    void destroy_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer)
    {
        // bxdf
        magik::free_device(buffer->ray_pool.d_sensor_wavelength_nm);
        magik::free_device(buffer->ray_pool.d_monte_carlo_weight);
        magik::free_device(buffer->ray_pool.d_spectral_radiance);
        magik::free_device(buffer->ray_pool.d_intrinsic_spectral_irradiance);

        magik::free_device(buffer->ray_pool.d_dir);
        magik::free_device(buffer->ray_pool.d_pos);
        magik::free_device(buffer->ray_pool.d_step_distance);
        magik::free_device(buffer->ray_pool.n_step);
        magik::free_device(buffer->ray_pool.hit_id);
        magik::free_device(buffer->ray_pool.hit_normal);
        magik::free_device(buffer->ray_pool.d_random_device);

        magik::free_device(buffer->advance_queue_A.d_id);
        magik::free_device(buffer->advance_queue_A.d_count);
        magik::free_device(buffer->advance_queue_B.d_id);
        magik::free_device(buffer->advance_queue_B.d_count);
        magik::free_device(buffer->intersect_queue.d_id);
        magik::free_device(buffer->intersect_queue.d_count);
        magik::free_device(buffer->bxdf_queue.d_id);
        magik::free_device(buffer->bxdf_queue.d_count);
        magik::free_device(buffer->redistribute_queue.d_id);
        magik::free_device(buffer->redistribute_queue.d_count);
        magik::free_device(buffer->splat_queue.d_id);
        magik::free_device(buffer->splat_queue.d_count);
    }

    void reset_queue_async(uint32_t* d_count, void** user_stream)
    {
        memset_device_async<uint32_t>(d_count, 0x0, sizeof(uint32_t), user_stream);
    }

    static void is_work_done_sync(bool* working, uint32_t* advance_d_count, void** user_stream)
    {
        uint32_t h_count = 0;

        memcpy_device_to_host_async(advance_d_count, &h_count, sizeof(uint32_t), user_stream);
        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));

        if(h_count == 0)
        {
            *working = false;
        }
        else
        {
            *working = true;
        }
    }

    void wavefront_reset(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        size_t size_of_float_buffer = buffer->x_resolution*buffer->y_resolution*sizeof(float);
        size_t size_of_redistribute_buffer = static_cast<size_t>(buffer->x_resolution*buffer->y_resolution*manager->stage.settings.n_spectral_irradiance_bin)*sizeof(float);

        magik::memset_device_async<float>(buffer->ray_pool.d_sensor_wavelength_nm, 0x0, size_of_float_buffer, &manager->cuda_stream);
        magik::memset_device_async<float>(buffer->ray_pool.d_monte_carlo_weight, 0x0, size_of_float_buffer, &manager->cuda_stream);
        magik::memset_device_async<float>(buffer->ray_pool.d_spectral_radiance, 0x0, size_of_float_buffer, &manager->cuda_stream);
        magik::memset_device_async<float>(buffer->ray_pool.d_intrinsic_spectral_irradiance, 0x0, size_of_redistribute_buffer, &manager->cuda_stream);

        manager->x_sample.store(0, std::memory_order_release);
    }

    static void reset_wavefront_buffer_async(magik_render_manager* manager, wavefront_ray_buffer_t* ray_buffer)
    {
        reset_queue_async(ray_buffer->advance_queue_A.d_count, &manager->cuda_stream);
        reset_queue_async(ray_buffer->advance_queue_B.d_count, &manager->cuda_stream);
        reset_queue_async(ray_buffer->intersect_queue.d_count, &manager->cuda_stream);
        reset_queue_async(ray_buffer->bxdf_queue.d_count, &manager->cuda_stream);
        reset_queue_async(ray_buffer->redistribute_queue.d_count, &manager->cuda_stream);
        reset_queue_async(ray_buffer->splat_queue.d_count, &manager->cuda_stream);

        size_t size_of_float_buffer = ray_buffer->x_resolution*ray_buffer->y_resolution*sizeof(float);
        size_t size_of_uint32_t_buffer = ray_buffer->x_resolution*ray_buffer->y_resolution*sizeof(uint32_t);
        memset_device_async<float>(ray_buffer->ray_pool.d_spectral_radiance, 0x0, size_of_float_buffer, &manager->cuda_stream);
        memset_device_async<float>(ray_buffer->ray_pool.d_step_distance, 0x0, size_of_float_buffer, &manager->cuda_stream);
        memset_device_async<uint32_t>(ray_buffer->ray_pool.n_step, 0x0, size_of_uint32_t_buffer, &manager->cuda_stream);

        uint32_t h_count = ray_buffer->x_resolution*ray_buffer->y_resolution;
        memcpy_host_to_device_async(&h_count, ray_buffer->advance_queue_A.d_count, sizeof(uint32_t), &manager->cuda_stream);
    }

    void wavefront_sample(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        /*
        What do we want to do tomorrow ? 

        - Header cleanup
            - Basically, we should try to not include everything everywhere. 
            - Not sure exactly how. 

        - Device arena 
            - The basics are not hard. The real difficulty of this is automation
            - We need an architecture that allows us to automatically update how 
              memory is allocated based on the struct. 
            - X Macro is the one approach i keep hearing about. 

        - Wavefromt statistics
            - These will be very important for debugging purposes. 
            - The golden quantity we would like to have is a per-sample queue history
              That is, each time a queue is reset, we record its current count. This
              will tell us how the wavefront drains rays. Or does not. 
            - Other metrics to measure are the total iterations. 
            - We naturally keep the most recent sample and the average for all of these. 
        */

        bool working = true;
        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 

        reset_wavefront_buffer_async(manager, buffer);

        launch_kernel_generate_thin_lens_ray_async(manager, buffer);

        // launch_kernel_generate_initial_geodesic_async

        while(working)
        {
            // launch_kernel_advance_minkowski_async

            // launch_kernel_advance_schwarzschild_async

            // launch_kernel_advance_kerr_async

            launch_kernel_tmp_advance_async(manager, buffer); // To replace this

            // launch_kernel_intersect_tlas_affine_async

            // launch_kernel_intersect_tlas_hermite_async

            // launch_kernel_intersect_blas_affine_async

            // launch_kernel_intersect_blas_hermite_async

            launch_kernel_intersect_async(manager, buffer); // To replace this

            launch_kernel_bxdf_async(manager, buffer);

            launch_kernel_redistribute_radiance_async(manager, buffer);

            launch_kernel_enforce_ray_limits_async(manager, buffer);

            launch_kernel_swap_queues_async(manager, buffer->advance_queue_A, buffer->advance_queue_B);

            launch_kernel_splat_to_renderbuffer_async(manager, buffer, tmp_element->second.d_data);

            is_work_done_sync(&working, buffer->advance_queue_A.d_count, &manager->cuda_stream); 
        }

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
