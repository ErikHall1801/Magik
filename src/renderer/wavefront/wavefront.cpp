#include "wavefront.h"
#include "kernel_generate_ray.cuh"
#include "kernel_splat_to_render_buffer.cuh"
#include "kernel_tmp_advance.cuh"
#include "kernel_intersect.cuh"
#include "kernel_bxdf.cuh"
#include "kernel_enforce_ray_limits.cuh"
#include "kernel_reset_ray_state.cuh"
#include "kernel_initialize_random_device.cuh"

namespace magik
{
    void realloc_wavefront_ray_buffer(magik_render_manager* manager, wavefront_ray_buffer_t* buffer, uint32_t x_resolution_target, uint32_t y_resolution_target)
    {
        /*
        We need a way to automate this. realloc and destruction. 
        A map would work, but its not a good match. We want a list of 
        similar types. An array ? Well, we still want them to be 
        named. 
        I think the solution here will be a device arena. 
        */

        if(buffer->x_resolution == x_resolution_target && buffer->y_resolution == y_resolution_target) return;

        destroy_wavefront_ray_buffer(buffer);

        buffer->x_resolution = x_resolution_target;
        buffer->y_resolution = y_resolution_target;

        size_t size_of_vec3f_buffer = x_resolution_target*y_resolution_target*sizeof(vec3f);
        size_t size_of_float_buffer = x_resolution_target*y_resolution_target*sizeof(float);
        size_t size_of_uint32_t_buffer = x_resolution_target*y_resolution_target*sizeof(uint32_t);
        size_t size_of_curandState_t_buffer = x_resolution_target*y_resolution_target*sizeof(curandState_t);

        buffer->ray_pool.d_dir = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_pos = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_rgb = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_step_distance = magik::allocate_device<float>(size_of_float_buffer);
        buffer->ray_pool.n_step = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->ray_pool.hit_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->ray_pool.hit_normal = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_random_device = magik::allocate_device<curandState_t>(size_of_curandState_t_buffer);

        magik::memset_device_sync<vec3f>(buffer->ray_pool.d_rgb, 0x0, size_of_vec3f_buffer);
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
        buffer->color_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->color_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
    }

    void destroy_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer)
    {
        magik::free_device(buffer->ray_pool.d_dir);
        magik::free_device(buffer->ray_pool.d_pos);
        magik::free_device(buffer->ray_pool.d_rgb);
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
        magik::free_device(buffer->color_queue.d_id);
        magik::free_device(buffer->color_queue.d_count);
    }

    static void reset_queue_async(uint32_t* d_count, void** user_stream)
    {
        memset_device_async<uint32_t>(d_count, 0x0, sizeof(uint32_t), user_stream);
    }

    static void is_work_done_sync(bool* working, uint32_t* advance_d_count, void** user_stream)
    {
        uint32_t h_count = 0;

        memcpy_device_to_host_async(advance_d_count, &h_count, sizeof(uint32_t), user_stream);

        if(h_count == 0)
        {
            *working = false;
        }
        else
        {
            *working = true;
        }
    }

    static void swap_queue(ray_queue_t* queue_A, ray_queue_t* queue_B)
    {
        // We should investigate if an async option works too.
        magik::mswap(*queue_A, *queue_B);
    }

    static void set_advance_queue(uint32_t* d_count, uint32_t x_resolution, uint32_t y_resolution, void** user_stream)
    {
        uint32_t h_count = x_resolution*y_resolution;
        memcpy_host_to_device_async(&h_count, d_count, sizeof(uint32_t), user_stream);
    }

    void wavefront_reset(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        size_t size_of_color_buffer = buffer->x_resolution*buffer->y_resolution*sizeof(float)*3;
        magik::memset_device_sync<vec3f>(buffer->ray_pool.d_rgb, 0x0, size_of_color_buffer);
        manager->x_sample.store(0, std::memory_order_release);
    }

    void wavefront_sample(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        /*
        Alright, look at us. We have a random buffer and at least something pathtracy seems 
        to be happening. I think right now the biggest obstical to seeing anything is the lack
        of averaging. And the light is very bright. 

        Well, it could be much worse. The basic wavefront is working. The primary issue is that
        rays just go through the wall. Oh well, not really. It seems the sides just eat rays ? 
        */

        bool working = true;
        reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->advance_queue_B.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->intersect_queue.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->bxdf_queue.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->color_queue.d_count, &manager->cuda_stream);

        launch_kernel_reset_ray_state_sync(&manager->cuda_stream, buffer->ray_pool, buffer->x_resolution, buffer->y_resolution);

        set_advance_queue(buffer->advance_queue_A.d_count, buffer->x_resolution, buffer->y_resolution, &manager->cuda_stream);
        launch_kernel_generate_ray_sync(&manager->cuda_stream, 16, 16, buffer->x_resolution, buffer->y_resolution, buffer->ray_pool, buffer->advance_queue_A, manager->stage.optical_systen.focal_length, manager->stage.optical_systen.sensor_diagonal_mm, manager->stage.optical_systen.position, manager->stage.optical_systen.orientation);

        while(working)
        {
            launch_kernel_tmp_advance_async(&manager->cuda_stream, buffer->x_resolution, buffer->y_resolution, buffer->ray_pool, buffer->advance_queue_A, buffer->intersect_queue);
            reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);

            launch_kernel_intersect_async(&manager->cuda_stream, buffer->x_resolution, buffer->y_resolution, buffer->ray_pool, buffer->intersect_queue, buffer->advance_queue_A, buffer->bxdf_queue, manager->stage.box_min, manager->stage.box_max, manager->stage.light_min, manager->stage.light_max);
            reset_queue_async(buffer->intersect_queue.d_count, &manager->cuda_stream);

            launch_kernel_bxdf_async(&manager->cuda_stream, buffer->x_resolution, buffer->y_resolution, buffer->ray_pool, buffer->bxdf_queue, buffer->advance_queue_A, buffer->color_queue);
            reset_queue_async(buffer->bxdf_queue.d_count, &manager->cuda_stream); 

            launch_kernel_enforce_ray_limits_async(&manager->cuda_stream, buffer->x_resolution, buffer->y_resolution, buffer->ray_pool, buffer->advance_queue_A, buffer->advance_queue_B, buffer->color_queue);
            reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);

            swap_queue(&buffer->advance_queue_A, &buffer->advance_queue_B);
            is_work_done_sync(&working, buffer->advance_queue_A.d_count, &manager->cuda_stream); 
        }

        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 
        launch_kernel_splat_to_render_buffer_sync(&manager->cuda_stream, 16, 16, buffer->x_resolution, buffer->y_resolution, tmp_element->second.d_data, buffer->ray_pool.d_rgb, manager->x_sample.load(std::memory_order_acquire));

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
