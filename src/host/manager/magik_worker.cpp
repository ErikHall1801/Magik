#include "magik_worker.h"

namespace magik::worker
{
    static e_magik_result_types initialize(magik_render_manager* manager)
    {
        magik::bridge::set_cuda_device(manager->cuda_device);
        magik::aov::initialize_framebuffer_collection(&manager->aov_context);

        manager->is_running.store(true, std::memory_order_release);

        set_error(MAGIK_SUCCESS);
    }

    void run(magik_render_manager* manager)
    {
        check_magik_errors(initialize(manager));

        auto fps_timer_start = std::chrono::steady_clock::now();
        int cycles = 0;

        while(manager->is_running.load())
        {
            check_magik_errors(magik::aov::allocate_back_framebuffer(&manager->aov_context));

            magik::bridge::call_test_pattern_mandelbrot_kernel(manager->aov_context.back->d_albedo, manager->aov_context.back->x_resolution, manager->aov_context.back->y_resolution);

            check_magik_errors(magik::aov::swap_back_framebuffer(&manager->aov_context));

            auto now = std::chrono::steady_clock::now();
            auto elapsed_seconds = std::chrono::duration_cast<std::chrono::seconds>(now - fps_timer_start).count();
            cycles++;

            if(elapsed_seconds > 1)
            {
                printf("API FPS; %i \n", (int)(cycles / elapsed_seconds));
                cycles = 0;
                fps_timer_start = std::chrono::steady_clock::now();
            }

        }

        check_magik_errors(magik::aov::destroy_framebuffer_collection(&manager->aov_context));
    }
}
