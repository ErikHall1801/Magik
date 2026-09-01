#include "magik_worker.h"

namespace magik::worker
{
    using namespace std::chrono_literals;

    void run(magik_render_manager* manager)
    {
        magik::bridge::set_cuda_device(manager->cuda_device);

        while(manager->is_running.load())
        {
            auto start = std::chrono::high_resolution_clock::now();
            std::this_thread::sleep_for(2000ms);
            auto end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> elapsed = end - start;

            std::cout << "Waited " << elapsed << '\n';
        }
    }
}
