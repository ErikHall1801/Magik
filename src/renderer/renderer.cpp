#include "renderer.h"

namespace magik
{
    struct initialize_t
    {
        magik_render_manager::sub_system_update_policies_t& pending_policies;
        framebuffer_swapchain_t& swapchain;

        size_t& iterations;
        e_magik_manager_status_types& worker_status;
        e_magik_result_types& worker_status_reason;

        uint32_t& worker_cuda_device;

        std::atomic<bool>& worker_running;

        static MAGIK_HOST initialize_t create(magik_render_manager* manager)
        {
            return
            {
                manager->pending,
                manager->framebuffer_swapchain,
                manager->total_iterations,
                manager->status,
                manager->status_reason,
                manager->cuda_device,
                manager->is_running
            };
        }
    };

    static MAGIK_HOST void initialize(initialize_t args)
    {
        initialize_framebuffer_swapchain(args.swapchain);

        args.pending_policies.framebuffer = MAGIK_FRAMEBUFFER_UPDATE_POLICY_REALLOC_RENDERBUFFER;
        args.pending_policies.wavefront = MAGIK_WAVEFRONT_UPDATE_POLICY_REALLOC;
        args.pending_policies.color_pipeline = MAGIK_COLOR_PIPELINE_UPDATE_POLICY_STRICT;

        args.iterations = 0;
        args.worker_status = MAGIK_STATUS_0;
        args.worker_status_reason = MAGIK_RESULT_SUCCESS;

        set_cuda_device(args.worker_cuda_device); 

        args.worker_running = true;
    }

    struct process_command_buffers_t
    {
        e_magik_manager_status_types& mgr_status;
        e_magik_result_types& mgr_status_reason;
        command_swapchain_t& mgr_command_swpachain;
        framebuffer_swapchain_t& mgr_framebuffer_swapchain;
        stage_t& mgr_stage;
        e_magik_framebuffer_update_policy_types& framebuffer_update_policy;
        e_magik_wavefront_buffer_update_policy_types& wavefront_update_policy;
        e_magik_color_pipeline_update_policy_types& color_pipeline_update_policy;

        static MAGIK_HOST process_command_buffers_t create(magik_render_manager* manager)
        {
            process_command_buffers_t result{manager->status, manager->status_reason, manager->command_swpachain, manager->framebuffer_swapchain, manager->stage, manager->pending.framebuffer, manager->pending.wavefront, manager->pending.color_pipeline};
            return result;
        }
    };

    static MAGIK_HOST void process_command_buffers(process_command_buffers_t args)
    {
        command_context_t ctx{args.framebuffer_update_policy, args.wavefront_update_policy, args.color_pipeline_update_policy, args.mgr_status, args.mgr_status_reason, args.mgr_command_swpachain, args.mgr_framebuffer_swapchain, args.mgr_stage};
        consume_back_command_buffer(ctx);
    }

    struct apply_update_policy_t
    {
        update_framebuffer_swapchain_t framebuffer;
        update_wavefront_buffer_t wavefront;
        update_color_pipeline_t color_pipeline;

        static MAGIK_HOST apply_update_policy_t create(magik_render_manager* manager)
        {
            return
            {
                .framebuffer =
                {
                    .update_policy = manager->pending.framebuffer,
                    .framebuffer_swapchain = manager->framebuffer_swapchain,
                    .x_resolution_target = manager->stage.optical_system_settings.x_resolution,
                    .y_resolution_target = manager->stage.optical_system_settings.y_resolution,
                },
                .wavefront =
                {
                    .update_policy = manager->pending.wavefront,
                    .wavefront_buffer = manager->wavefront_buffer,
                    .x_sample = manager->x_sample,
                    .user_stream = static_cast<cudaStream_t>(manager->cuda_stream),
                    .x_resolution_target = manager->stage.optical_system_settings.x_resolution,
                    .y_resolution_target = manager->stage.optical_system_settings.y_resolution,
                    .n_geodesic_step_limit = manager->stage.render_settings.n_geodesic_step_limit,
                    .n_isi_bin = manager->stage.color_settings.n_isi_bin,
                },
                .color_pipeline
                {
                    .update_policy = manager->pending.color_pipeline,
                    .pipeline = manager->color_pipeline_descriptor,
                    .color_settings = manager->stage.color_settings,
                },
            };
        }
    };

    static MAGIK_HOST void apply_update_policy(apply_update_policy_t args)
    {
        update_framebuffer_swapchain(args.framebuffer);
        update_wavefront_buffer(args.wavefront);
        update_color_pipeline(args.color_pipeline);
    }

    struct compute_wavefront_sample_t
    {
        wavefront_sample_args_t wavefront_args;

        static MAGIK_HOST compute_wavefront_sample_t create(magik_render_manager* manager)
        {
            auto temp = manager->framebuffer_swapchain.render_framebuffer.collection.find("test");

            return
            {
                .wavefront_args = 
                {
                    .d_renderbuffer = temp->second.d_data,
                    .wavefront_buffer = manager->wavefront_buffer,
                    .x_sample = manager->x_sample,
                    .stage = manager->stage,
                    .color_pipeline = manager->color_pipeline_descriptor,
                    .user_stream = static_cast<cudaStream_t>(manager->cuda_stream)
                },
            };
        }
    };

    static MAGIK_HOST void compute_wavefront_sample(compute_wavefront_sample_t args)
    {
        wavefront_sample(args.wavefront_args);
    }

    struct release_t
    {
        framebuffer_swapchain_t& framebuffer_swapchain;
        device_mem_arena* wavefront_buffer_arena;
        cudaStream_t user_stream;

        static MAGIK_HOST release_t create(magik_render_manager* manager)
        {
            return
            {
                manager->framebuffer_swapchain,
                &manager->wavefront_buffer.arena,
                static_cast<cudaStream_t>(manager->cuda_stream)
            };
        }
    };

    static MAGIK_HOST void release(release_t args)
    {
        release_framebuffer_swapchain(args.framebuffer_swapchain);
        release_wavefront_buffer(args.wavefront_buffer_arena, args.user_stream);
    }

    void run(magik_render_manager* manager)
    {
        initialize(initialize_t::create(manager));

        while(manager->is_nominal())
        {
            process_command_buffers(process_command_buffers_t::create(manager));

            apply_update_policy(apply_update_policy_t::create(manager));

            // We have to do this for now, just so it does not immediatly blow up. 
            // We will have to think about a proper way to handle the lack of a renderbuffer. I.e what if
            // the d_ ptr is null ? That is not strictly an error. 
            auto tmp_element = manager->framebuffer_swapchain.render_framebuffer.collection.find("test");
            if(tmp_element != manager->framebuffer_swapchain.render_framebuffer.collection.end())
            {
                compute_wavefront_sample(compute_wavefront_sample_t::create(manager));
            }
        }

        release(release_t::create(manager));
    }
}
