#include "magik_worker.h"

std::atomic<double> frame_time = 0.0;

namespace magik::worker
{
    static e_magik_result_types initialize(magik_render_manager* manager)
    {
        e_magik_result_types result = MAGIK_SUCCESS;

        magik::bridge::set_cuda_device(manager->cuda_device);

        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            result = magik::aov::initialize_swapchain(&manager->aov_context);
            if(result) { return result; }
        }

        result = magik::host_memory::arena_create(manager, &manager->host_arena, GiB(1), MiB(64), nullptr, nullptr);
        if(result) { return result; }

        manager->is_running.store(true, std::memory_order_release);

        return MAGIK_SUCCESS;
    }

    static e_magik_result_types host_work(magik_render_manager* manager)
    {
        e_magik_result_types result = MAGIK_SUCCESS;
        bool is_dirty = false;

        result = magik::cqs::consume_back_command_buffer(manager);
        if(result){ return result; }
        
        result = magik::aov::allocate_render_framebuffer_object(is_dirty, &manager->aov_context);
        if(result){ return result; }

        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN && !is_dirty)
        {
            result = magik::aov::memcpy_render_to_back_framebuffer_object(&manager->aov_context);
            if(result){ return result; }
        }

        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            result = magik::aov::swap_back_framebuffer(&manager->aov_context);
            if(result){ return result; }
        }

        return MAGIK_SUCCESS;
    }

    static e_magik_result_types device_work(magik_render_manager* manager)
    {
        auto tmp_element = manager->aov_context.render_framebuffer_object.collection.find("test");
        if(tmp_element != manager->aov_context.render_framebuffer_object.collection.end())
        {
            auto buffer = tmp_element->second;
            magik::bridge::call_test_pattern_julia_set_kernel(manager->cuda_stream, buffer.d_data, buffer.x_resolution, buffer.y_resolution, manager->render_context.c0, manager->render_context.c1, manager->render_context.c2, manager->render_context.real, manager->render_context.imag);
        }
        else
        {
            using namespace std::chrono_literals;
            std::this_thread::sleep_for(100ms);
        }

        magik::bridge::host_cuda_semaphore(&manager->cuda_stream);

        return MAGIK_SUCCESS;
    }

    void run(magik_render_manager* manager)
    {
        e_magik_result_types expected = MAGIK_SUCCESS, result = MAGIK_SUCCESS;

        result = initialize(manager);
        if(result)
        {
            manager->is_running.store(false, std::memory_order_release);
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
        }

        auto frame_start = std::chrono::steady_clock::now();
        auto frame_end = std::chrono::steady_clock::now();

        bool is_dirty = false;

        while(manager->is_running.load())
        {
            frame_start = std::chrono::steady_clock::now();

            result = host_work(manager);
            if(result)
            {
                manager->is_running.store(false, std::memory_order_release);
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                break;
            }

            result = device_work(manager);
            if(result)
            {
                manager->is_running.store(false, std::memory_order_release);
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                break;
            }

            frame_end = std::chrono::steady_clock::now();
            frame_time.store(std::chrono::duration_cast<std::chrono::duration<double, std::micro>>(frame_end - frame_start).count(), std::memory_order_relaxed);
        }

        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            result = magik::aov::destroy_swpachain(&manager->aov_context);
            if(result)
            {
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            }
        }

        result = magik::aov::destroy_render_framebuffer_object(&manager->aov_context);
        if(result)
        {
            manager->atomic_last_error_type.compare_exchange_strong(expected, result);
        }

        magik::host_memory::arena_destroy(manager, manager->host_arena, manager->user_host_mem_release_func);
    }
}
