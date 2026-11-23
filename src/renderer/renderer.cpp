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
        // A lot of this logic is more than suspect. 
        // The error callback needs to be part of the manager ??? 
        // Some of these names need to be modified. 

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
        wavefront_buffer_t wavefront_buffer;

        color_pipeline_settings_t pipeline_settings;
        pipeline_settings.n_isi_bin = manager->stage.color_settings.n_isi_bin;
        pipeline_settings.scene_colorspace_type = manager->stage.color_settings.scene_colorspace_type;
        pipeline_settings.display_colorspace_type = manager->stage.color_settings.display_colorspace_type;
        pipeline_settings.view_transform = manager->stage.color_settings.view_transform_type;
        pipeline_settings.output_format = manager->stage.color_settings.output_format;
        pipeline_settings.white_point = manager->stage.color_settings.white_point;
        pipeline_settings.tint = manager->stage.color_settings.tint;
        pipeline_settings.isi_max_wavelength_nm = manager->stage.color_settings.isi_max_wavelength_nm;
        pipeline_settings.isi_min_wavelength_nm = manager->stage.color_settings.isi_min_wavelength_nm;
        pipeline_settings.cmf_type = manager->stage.color_settings.cmf_type;
        manager->color_pipeline_descriptor = manager->color_pipeline_descriptor.create(pipeline_settings);

        // Render stage
        while(manager->is_running.load(std::memory_order_relaxed))
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
            // Why is this not a member function ????
            result = allocate_render_framebuffer_swapchain(&manager->framebuffer_swapchain, &is_dirty, manager->stage.optical_system_settings.x_resolution, manager->stage.optical_system_settings.y_resolution);

            // Wavefront realloc
            // Why is this not a member function ? 
            realloc_wavefront_buffer(static_cast<cudaStream_t>(manager->cuda_stream), &wavefront_buffer, manager->stage.color_settings.n_isi_bin, manager->stage.optical_system_settings.x_resolution, manager->stage.optical_system_settings.y_resolution, manager->stage.render_settings.n_geodesic_step_limit);

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
                result = swap_back_framebuffer(&manager->framebuffer_swapchain);

                if(result)
                {
                    manager->is_running.store(false, std::memory_order_release);
                    manager->atomic_last_error_type.compare_exchange_strong(expected, result);
                    return;
                }
            }

            // Rendering stage
            if(manager->framebuffer_swapchain.clear_render_buffer)
            {
                reset_render_buffer(&manager->framebuffer_swapchain);
                reset_wavefront_process_async(manager, &wavefront_buffer);
                manager->framebuffer_swapchain.clear_render_buffer = false;
            }

            auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test");
            if(tmp_element != manager->framebuffer_swapchain.render_framebuffer.collection.end())
            {
                wavefront_sample(manager, &wavefront_buffer);
            }
            else
            {
                using namespace std::chrono_literals;
                std::this_thread::sleep_for(100ms);
            }

            iteration++;
            iteration_end_time = std::chrono::steady_clock::now();

            // Update performance statistics "work" buffer, which incldues swapping the buffers. 
        }

        // Shutdown stage
        if(manager->display_type == MAGIK_DISPLAY_SWAPCHAIN)
        {
            // why is this not a member function ?
            result = destroy_framebuffer_swpachain(&manager->framebuffer_swapchain);
            if(result)
            {
                manager->atomic_last_error_type.compare_exchange_strong(expected, result);
            }
        }

        wavefront_buffer.release_async(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}