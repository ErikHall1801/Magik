#include "magik_worker.h"

std::atomic<double> frame_time = 0.0;

namespace magik::worker
{
    static e_magik_result_types initialize(magik_render_manager* manager)
    {
        magik::bridge::set_cuda_device(manager->cuda_device);
        magik::aov::initialize_framebuffer_collection(&manager->aov_context);

        manager->is_running.store(true, std::memory_order_release);

        set_and_return_error(MAGIK_SUCCESS);
    }

    void run(magik_render_manager* manager)
    {
        check_magik_errors(initialize(manager));

        auto frame_start = std::chrono::steady_clock::now();
        auto frame_end = std::chrono::steady_clock::now();

        while(manager->is_running.load())
        {
            frame_start = std::chrono::steady_clock::now();

            check_magik_errors(magik::aov::allocate_back_framebuffer(&manager->aov_context));

            magik::bridge::call_test_pattern_julia_set_kernel(manager->aov_context.back->d_albedo, manager->aov_context.back->x_resolution, manager->aov_context.back->y_resolution);

            check_magik_errors(magik::aov::swap_back_framebuffer(&manager->aov_context));

            frame_end = std::chrono::steady_clock::now();
            frame_time.store(std::chrono::duration_cast<std::chrono::duration<double, std::micro>>(frame_end - frame_start).count(), std::memory_order_relaxed);
        }

        check_magik_errors(magik::aov::destroy_framebuffer_collection(&manager->aov_context));
    }
}
