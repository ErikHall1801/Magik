#include "renderer.h"
#include "kernel_julia_set.cuh"

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

        bool is_dirty = false; // What is dirty ? 

        // Init stage
        result = initalize_manager(manager);
        if(result)
        {
            manager->is_running.store(false, std::memory_order_release);
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
        }

        // Render stage
        while(manager->is_running)
        {
            // Command stage
            result = magik::consume_back_command_buffer(manager);

            if(result)
            {
                manager->is_running.store(false, std::memory_order_release);
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                return;
            }

            // Framebuffer stage
            result = magik::allocate_render_framebuffer_swapchain(&manager->framebuffer_swapchain, &is_dirty);

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
                auto tmp_buffer = tmp_element->second;
                magik::launch_kernel_julia_set(manager->cuda_stream, tmp_buffer.d_data, tmp_buffer.x_resolution, tmp_buffer.y_resolution, 16, 16, manager->stage.c0, manager->stage.c1, manager->stage.c2, manager->stage.imag, manager->stage.real);
            }
            else
            {
                using namespace std::chrono_literals;
                std::this_thread::sleep_for(100ms);
            }
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
    }
}