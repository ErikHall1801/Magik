#include "wavefront.h"
#include "kernel_generate_ray.cuh"
#include "kernel_splat_to_render_buffer.cuh"

namespace magik
{
    void realloc_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer, uint32_t x_resolution_target, uint32_t y_resolution_target)
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
        buffer->ray_pool.d_dir = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_pos = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_rgb = magik::allocate_device<vec3f>(size_of_vec3f_buffer);
        buffer->ray_pool.d_step_distance = magik::allocate_device<float>(size_of_float_buffer);

        magik::memset_device_sync<vec3f>(buffer->ray_pool.d_rgb, 0x0, size_of_vec3f_buffer);

        size_t size_of_uint32_t_buffer = x_resolution_target*y_resolution_target*sizeof(uint32_t);
        buffer->advance_queue_A.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->advance_queue_A.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->advance_queue_B.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->advance_queue_B.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->intersect_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->intersect_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->shade_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->shade_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
        buffer->color_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->color_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
    }

    void destroy_wavefront_ray_buffer(wavefront_ray_buffer_t* buffer)
    {
        magik::free_device(buffer->ray_pool.d_dir);
        magik::free_device(buffer->ray_pool.d_pos);
        magik::free_device(buffer->ray_pool.d_rgb);
        magik::free_device(buffer->ray_pool.d_step_distance);

        magik::free_device(buffer->advance_queue_A.d_id);
        magik::free_device(buffer->advance_queue_A.d_count);
        magik::free_device(buffer->advance_queue_B.d_id);
        magik::free_device(buffer->advance_queue_B.d_count);
        magik::free_device(buffer->intersect_queue.d_id);
        magik::free_device(buffer->intersect_queue.d_count);
        magik::free_device(buffer->shade_queue.d_id);
        magik::free_device(buffer->shade_queue.d_count);
        magik::free_device(buffer->color_queue.d_id);
        magik::free_device(buffer->color_queue.d_count);
    }

    static void reset_queue_async(uint32_t* d_count, void** user_stream)
    {
        memset_device_async<uint32_t>(d_count, 0x0, sizeof(uint32_t), user_stream);
    }

    static void is_work_done_sync(bool* working, uint32_t* advance_d_count)
    {
        uint32_t h_count = 0;

        memcpy_device_to_host(advance_d_count, &h_count, sizeof(uint32_t));

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
        memset_device_async<uint32_t>(d_count, x_resolution*y_resolution, sizeof(uint32_t), user_stream);
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
        We need to think about how this is meant to work, exactly, before writing anything. To do so, let's
        consider each major question in isolation. 

        How do we know when to stop ? The termination condition. For now, the easiest idea is to add a CPU 
        syncronization point. That is, at the end of the while loop, the CPU fetches the ray count of the 
        queues in the loop, if it is zero the work is done. 
        This does add a synchronization point, and there are more advanced options like CUDA Graphs, but we 
        want something that works, then optimize it. 

        What about warp aggregated ballots ? According to Nvidia NVCC automatically aggregates atomic operation's
        in "many" cases. Again, we will just use atomicAdd() in the kernel for now. If it is to slow we can 
        always add our own aggregation logic. 

        Do we need to double buffer the ray queues ? Yes we do, consider this. We have an advance queue with a 
        million rays. It is fine that we tell the kernel to do all of this work at once, but in practice only a 
        few thousand rays are executed in parallel. Now imagine out of 1000 rays 500 end up back on the advance
        queue. This would immediatly cause issues as the kernel is fiddling with the very queue it is meant to
        process. 

        Do note, we cannot merge the advance and intersect queues because that would introduce the kind of problem 
        discussed above in the intersect kernel. 

        Here is something we should consider right now, how do we reset the color buffer ? A simple function will 
        do the job, "wavefront_reset()". 

        Another question, how do we enforce ray limits ? Well, the architecture is pretty nice. We can just check 
        what is left in the advance queue and read how many bounces each ray already did. If they are at the 
        limit we just put them on the color queue. 
        This does run into the issue from above, as we technically write to the buffer we are reading from. So this
        could justify an A/B advance buffer. Just to be clear, launch_kernel_enforce_ray_limits needs the A/B 
        queues because it looks at the A buffer and either kicks rays to B or the Color queue. The A queue is read
        only. Then we swap the two since the A buffer is what the rest of the wavefront uses. 

        We can depricate the Julia set right now and just visualize the ray position, as that should theoretically
        already change. 

        */

        bool working = true;
        reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->advance_queue_B.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->intersect_queue.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->shade_queue.d_count, &manager->cuda_stream);
        reset_queue_async(buffer->color_queue.d_count, &manager->cuda_stream);

        set_advance_queue(buffer->advance_queue_A.d_count, buffer->x_resolution, buffer->y_resolution, &manager->cuda_stream);
        launch_kernel_generate_ray_sync(    &manager->cuda_stream, 
                                            16, 
                                            16, 
                                            buffer->x_resolution, 
                                            buffer->y_resolution, 
                                            buffer->ray_pool, 
                                            buffer->advance_queue_A, 
                                            manager->stage.optical_systen.focal_length, 
                                            manager->stage.optical_systen.sensor_diagonal_mm, 
                                            manager->stage.optical_systen.position, 
                                            manager->stage.optical_systen.orientation);

        /*while(working)
        {
            // launch_kernel_advance_async(advance_queue, intersect_queue);
            reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);

            // launch_kernel_intersect_async(intersect_queue, advance_queue, shade_queue);
            reset_queue_async(buffer->intersect_queue.d_count, &manager->cuda_stream);

            // launch_kernel_shade_async(shade_queue, advance_queue, color_queue);
            reset_queue_async(buffer->shade_queue.d_count, &manager->cuda_stream);

            // launch_kernel_enforce_ray_limits_async(advance_queue_A, advance_queue_B, color_queue);
            reset_queue_async(buffer->advance_queue_A.d_count, &manager->cuda_stream);

            swap_queue(&buffer->advance_queue_A, &buffer->advance_queue_B);
            is_work_done_sync(&working, buffer->advance_queue_A.d_count); 
        }*/

        auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test"); // Eh, not ideal. 
        launch_kernel_splat_to_render_buffer_sync(&manager->cuda_stream, 16, 16, buffer->x_resolution, buffer->y_resolution, tmp_element->second.d_data, buffer->ray_pool.d_dir);

        manager->x_sample.fetch_add(1, std::memory_order_relaxed);
    }
}
