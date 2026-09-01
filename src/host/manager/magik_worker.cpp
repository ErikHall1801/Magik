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

        while(manager->is_running.load())
        {
            check_magik_errors(magik::aov::allocate_back_framebuffer(&manager->aov_context));

            using namespace std::chrono_literals;
            auto start = std::chrono::high_resolution_clock::now();
            std::this_thread::sleep_for(2000ms);
            auto end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> elapsed = end - start;
            // std::cout << "Waited " << elapsed << '\n';
            // std::cout << "Albedo size " << manager->aov_context.back->size_of_d_albedo << '\n';

            check_magik_errors(magik::aov::swap_back_framebuffer(&manager->aov_context));
        }

        check_magik_errors(magik::aov::destroy_framebuffer_collection(&manager->aov_context));
    }
}
