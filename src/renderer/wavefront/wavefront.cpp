#include "wavefront.h"

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

        size_t size_of_uint32_t_buffer = x_resolution_target*y_resolution_target*sizeof(uint32_t);
        buffer->advance_queue.d_count = magik::allocate_device<uint32_t>(sizeof(uint32_t));
        buffer->advance_queue.d_id = magik::allocate_device<uint32_t>(size_of_uint32_t_buffer);
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

        magik::free_device(buffer->advance_queue.d_id);
        magik::free_device(buffer->advance_queue.d_count);
        magik::free_device(buffer->intersect_queue.d_id);
        magik::free_device(buffer->intersect_queue.d_count);
        magik::free_device(buffer->shade_queue.d_id);
        magik::free_device(buffer->shade_queue.d_count);
        magik::free_device(buffer->color_queue.d_id);
        magik::free_device(buffer->color_queue.d_count);
    }

    void reset_queue_async(uint32_t* d_count, void* user_stream)
    {
        memset_async<uint32_t>(d_count, 0x0, sizeof(uint32_t), user_stream);
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

        Alright, with all of this setup, lets imagine some pseudocode. Remember, this is all for one sample. 

        ###

        bool working = true;
        reset_queue_async(advance_queue.count);
        reset_queue_async(intersect_queue.count);
        reset_queue_async(shade_queue.count);
        reset_queue_async(color_queue.count);

        launch_kernel_generate_ray(advance_queue);

        while(working)
        {
            launch_kernel_advance(advance_queue, intersect_queue);
            reset_queue_async(advance_queue.count);

            launch_kernel_intersect(intersect_queue, advance_queue, shade_queue);
            reset_queue_async(intersect_queue.count);

            launch_kernel_shade(shade_queue, advance_queue, color_queue);
            reset_queue_async(shade_queue.count);

            is_work_done(&working, advance_queue);
        }

        launch_kernel_splat_to_color(color_queue);
        x_sample++;

        ###

        Do note, we cannot merge the advance and intersect queues because that would introduce the kind of problem 
        discussed above in the intersect kernel. 

        */
    }
}
