#include "renderer.h"

namespace magik
{
    struct initialize_t
    {
        uint32_t* cuda_device;
        void** cuda_stream;
        bool* owns_stream;
        std::atomic<bool>* is_running;
        size_t* total_iterations;
        e_magik_manager_status_types* status;
        e_magik_result_types* status_reason;
        e_magik_manager_status_types* initial_status;

        static MAGIK_HOST initialize_t create(magik_render_manager* manager)
        {
            initialize_t result;

            result.cuda_device = &manager->cuda_device;
            result.cuda_stream = &manager->cuda_stream;
            result.owns_stream = &manager->owns_stream;
            result.is_running = &manager->is_running;
            result.total_iterations = &manager->total_iterations;
            result.status = &manager->status;
            result.status_reason = &manager->status_reason;
            result.initial_status = &manager->initial_status;

            return result;
        }
    };

    static MAGIK_HOST void initialize(initialize_t args)
    {
        set_cuda_device(*args.cuda_device);

        if(!*args.owns_stream)
        {
            *args.owns_stream = true;
            create_cuda_stream(args.cuda_stream);
        }

        *args.total_iterations = 0;

        *args.status = MAGIK_STATUS_0;
        *args.status_reason = MAGIK_SUCCESS;
        *args.initial_status = MAGIK_STATUS_0;

        *args.is_running = true;
    }

    struct process_command_buffers_t
    {
        e_magik_manager_status_types& mgr_status;
        e_magik_result_types& mgr_status_reason;
        command_swapchain_t& mgr_command_swpachain;
        framebuffer_swapchain_t& mgr_framebuffer_swapchain;
        stage_t& mgr_stage;

        static MAGIK_HOST process_command_buffers_t create(magik_render_manager* manager)
        {
            process_command_buffers_t result{manager->status, manager->status_reason, manager->command_swpachain, manager->framebuffer_swapchain, manager->stage};
            return result;
        }
    };

    static MAGIK_HOST void process_command_buffers(process_command_buffers_t args)
    {
        command_context_t ctx{args.mgr_status, args.mgr_status_reason, args.mgr_command_swpachain, args.mgr_framebuffer_swapchain, args.mgr_stage};
        consume_back_command_buffer(ctx);
    }

    struct apply_update_policy_t
    {
        static MAGIK_HOST apply_update_policy_t create(magik_render_manager* manager)
        {

        }
    };

    static MAGIK_HOST void apply_update_policy(apply_update_policy_t args)
    {

    }

    struct compute_wavefront_sample_t
    {
        static MAGIK_HOST compute_wavefront_sample_t create(magik_render_manager* manager)
        {

        }
    };

    static MAGIK_HOST void compute_wavefront_sample(compute_wavefront_sample_t args)
    {

    }

    struct present_renderbuffer_t
    {
        static MAGIK_HOST present_renderbuffer_t create(magik_render_manager* manager)
        {

        }
    };

    static MAGIK_HOST void present_renderbuffer(present_renderbuffer_t args)
    {

    }

    struct release_t
    {
        static MAGIK_HOST release_t create(magik_render_manager* manager)
        {

        }
    };

    static MAGIK_HOST void release(release_t args)
    {

    }

    void run(magik_render_manager* manager)
    {
        initialize(initialize_t::create(manager));

        while(manager->is_nominal())
        {
            process_command_buffers(process_command_buffers_t::create(manager));

            apply_update_policy(apply_update_policy_t::create(manager));

            compute_wavefront_sample(compute_wavefront_sample_t::create(manager));

            present_renderbuffer(present_renderbuffer_t::create(manager));
        }

        release(release_t::create(manager));
    }
}
