#include "renderer.h"
#include "wavefront.h"

namespace magik
{
    static e_magik_result_types initalize_manager(magik_render_manager* manager)
    {
        e_magik_result_types result = MAGIK_SUCCESS;

        magik::set_cuda_device(manager->cuda_device);

        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            result = magik::initialize_framebuffer_swapchain(&manager->framebuffer_swapchain);
            if(result) return result;
        }

        manager->is_running.store(true, std::memory_order_release);

        return MAGIK_SUCCESS;
    }

    void run(magik_render_manager* manager)
    {
        e_magik_result_types expected = MAGIK_SUCCESS, result = MAGIK_SUCCESS;

        size_t iteration = 0;

        // Timing stage
        auto iteration_start_time = std::chrono::steady_clock::now();
        auto iteration_end_time = std::chrono::steady_clock::now();

        bool is_dirty = false; // What is dirty ? 

        // Init stage
        result = initalize_manager(manager);
        if(result)
        {
            manager->is_running.store(false, std::memory_order_release);
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
        }

        // Wavefront initalization stage
        wavefront_ray_buffer_t ray_buffer;

        // Render stage
        while(manager->is_running)
        {
            iteration_start_time = std::chrono::steady_clock::now();

            // Command stage
            result = magik::consume_back_command_buffer(manager);

            if(result)
            {
                manager->is_running.store(false, std::memory_order_release);
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                return;
            }

            // Framebuffer stage
            result = magik::allocate_render_framebuffer_swapchain(&manager->framebuffer_swapchain, &is_dirty, manager->stage.optical_systen.x_resolution, manager->stage.optical_systen.y_resolution);

            // Wavefront realloc
            magik::realloc_wavefront_ray_buffer(&ray_buffer, manager->stage.optical_systen.x_resolution, manager->stage.optical_systen.y_resolution);

            if(result)
            {
                manager->is_running.store(false, std::memory_order_release);
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                return;
            }

            if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN && !is_dirty)
            {
                result = magik::memcpy_render_to_back_framebuffer(&manager->framebuffer_swapchain);

                if(result)
                {
                    manager->is_running.store(false, std::memory_order_release);
                    manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                    return;
                }
            }

            if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
            {
                result = magik::swap_back_framebuffer(&manager->framebuffer_swapchain);

                if(result)
                {
                    manager->is_running.store(false, std::memory_order_release);
                    manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                    return;
                }
            }

            // Rendering stage
            auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test");
            if(tmp_element != manager->framebuffer_swapchain.render_framebuffer.collection.end())
            {
                wavefront_sample(manager, &ray_buffer);
            }
            else
            {
                using namespace std::chrono_literals;
                std::this_thread::sleep_for(100ms);
            }

            iteration++;
            iteration_end_time = std::chrono::steady_clock::now();

            manager->sampled_time_point_seconds.store(std::chrono::duration<double>(iteration_start_time.time_since_epoch()).count(), std::memory_order_release);
            manager->average_sample_time_seconds.store(manager->total_render_time_seconds.load(std::memory_order_relaxed) / (double)iteration);
            manager->latest_sample_time_seconds.store(std::chrono::duration<double>(iteration_end_time - iteration_start_time).count(), std::memory_order_release);
            manager->total_render_time_seconds.fetch_add(manager->latest_sample_time_seconds.load(std::memory_order_relaxed), std::memory_order_release);
        }

        // Shutdown stage
        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            result = magik::destroy_framebuffer_swpachain(&manager->framebuffer_swapchain);
            if(result)
            {
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            }
        }

        magik::destroy_wavefront_ray_buffer(&ray_buffer);
    }
}