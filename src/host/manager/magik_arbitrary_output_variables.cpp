#include "magik_arbitrary_output_variables.h"

namespace magik::aov
{
    e_magik_result_types initialize_framebuffer_collection(magik::aov::context* ctx)
    {
        if(!ctx)
        {
            set_error(MAGIK_ERROR_INVALID_POINTER);
        }

        size_t size_of_1_float_buffer = static_cast<size_t>(ctx->x_resolution*ctx->y_resolution*1)*sizeof(float);
        size_t size_of_3_float_buffer = static_cast<size_t>(ctx->x_resolution*ctx->y_resolution*3)*sizeof(float);
        size_t size_of_N_float_buffer = static_cast<size_t>(ctx->x_resolution*ctx->y_resolution*ctx->n_spectral_bin)*sizeof(float);

        for(uint32_t i = 0; i < 3; i++)
        {
            if(ctx->framebuffer_object_collection[i].d_albedo) 
            {
                set_error(MAGIK_ERROR_AOV_ALLOCATED_BEFORE_INITIALIZATION);
            }

            ctx->framebuffer_object_collection[i].d_albedo = magik::bridge::host_allocate_device_memory(size_of_3_float_buffer);
            ctx->framebuffer_object_collection[i].size_of_d_albedo = size_of_3_float_buffer;

            ctx->framebuffer_object_collection[i].x_resolution = ctx->x_resolution;
            ctx->framebuffer_object_collection[i].y_resolution = ctx->y_resolution;
            ctx->framebuffer_object_collection[i].n_spectral_bin = ctx->n_spectral_bin;
        }


        ctx->framebuffer_object_collection[0].debug_id = 0;
        ctx->framebuffer_object_collection[1].debug_id = 1;
        ctx->framebuffer_object_collection[2].debug_id = 2;

        ctx->front = &ctx->framebuffer_object_collection[0];
        ctx->ready.store(&ctx->framebuffer_object_collection[1], std::memory_order_relaxed);
        ctx->back = &ctx->framebuffer_object_collection[2];

        set_error(MAGIK_SUCCESS);
    }

    e_magik_result_types allocate_back_framebuffer(magik::aov::context* ctx)
    {
        size_t size_of_1_float_buffer = static_cast<size_t>(ctx->back->x_resolution*ctx->back->y_resolution*1)*sizeof(float);
        size_t size_of_3_float_buffer = static_cast<size_t>(ctx->back->x_resolution*ctx->back->y_resolution*3)*sizeof(float);
        size_t size_of_N_float_buffer = static_cast<size_t>(ctx->back->x_resolution*ctx->back->y_resolution*ctx->back->n_spectral_bin)*sizeof(float);

        if(ctx->back->size_of_d_albedo != size_of_3_float_buffer)
        {
            magik::bridge::host_destroy_device_memory(ctx->back->d_albedo);
            ctx->back->d_albedo = magik::bridge::host_allocate_device_memory(size_of_3_float_buffer);
            ctx->back->size_of_d_albedo = size_of_3_float_buffer;

            ctx->back->x_resolution = ctx->x_resolution;
            ctx->back->y_resolution = ctx->y_resolution;
            ctx->back->n_spectral_bin = ctx->n_spectral_bin;
        }

        set_error(MAGIK_SUCCESS);
    }

    e_magik_result_types swap_back_framebuffer(magik::aov::context* ctx)
    {
        if(!ctx || !ctx->ready.load(std::memory_order_relaxed) || !ctx->back) set_error(MAGIK_ERROR_INVALID_POINTER);

        // uint32_t c_back_id = ctx->back->debug_id;
        // uint32_t c_ready_id = ctx->ready.load()->debug_id;

        ctx->back = ctx->ready.exchange(ctx->back, std::memory_order_acq_rel);
        ctx->is_ready_updated.store(true, std::memory_order_release);

        // uint32_t n_back_id = ctx->back->debug_id;
        // uint32_t n_ready_id = ctx->ready.load()->debug_id;
        // printf("Swapped back and ready framebuffer | Back id [ %i -> %i ] | Ready id [ %i -> %i ] \n", c_back_id, n_back_id, c_ready_id, n_ready_id);

        set_error(MAGIK_SUCCESS);
    }

    bool try_swap_front_framebuffer(magik::aov::context* ctx)
    {
        if(!ctx || !ctx->ready.load(std::memory_order_relaxed) || !ctx->front)
        {
            g_last_error = MAGIK_ERROR_INVALID_POINTER;
            return false;
        }

        // uint32_t c_front_id = ctx->front->debug_id;
        // uint32_t c_ready_id = ctx->ready.load()->debug_id;

        if(!ctx->is_ready_updated.exchange(false, std::memory_order_acquire)) 
        {
            g_last_error = MAGIK_SUCCESS;
            return false;
        }
        
        ctx->front = ctx->ready.exchange(ctx->front, std::memory_order_acq_rel);

        // uint32_t n_front_id = ctx->front->debug_id;
        // uint32_t n_ready_id = ctx->ready.load()->debug_id;
        // printf("Swapped front and ready framebuffer | Back id [ %i -> %i ] | Ready id [ %i -> %i ] \n", c_front_id, n_front_id, c_ready_id, n_ready_id);

        g_last_error = MAGIK_SUCCESS;
        return true;
    }

    e_magik_result_types memcpy_front_framebuffer_to_dcc_framebuffer(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        if(!ctx || !dcc_buffer || !ctx->front) set_error(MAGIK_ERROR_INVALID_POINTER);

        if( dcc_buffer->config_type != MAGIK_AOV_CONFIG_HOST && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_CUDA && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP
        ) set_error(MAGIK_UNKNOWN_ENUM_TYPE);

        switch(dcc_buffer->config_type)
        {
            case MAGIK_AOV_CONFIG_HOST:
            {
                if(!dcc_buffer->data.config_host.h_albedo)
                {
                    dcc_buffer->x_resolution = ctx->front->x_resolution;
                    dcc_buffer->y_resolution = ctx->front->y_resolution;
                    dcc_buffer->data.config_host.host_size = static_cast<size_t>(dcc_buffer->x_resolution*dcc_buffer->y_resolution*3)*sizeof(float);
                    dcc_buffer->data.config_host.h_albedo = magik::bridge::host_allocate_host_memory(dcc_buffer->data.config_host.host_size);
                }

                if(dcc_buffer->x_resolution != ctx->front->x_resolution || dcc_buffer->y_resolution != ctx->front->y_resolution || dcc_buffer->data.config_host.host_size != ctx->front->size_of_d_albedo)
                {
                    dcc_buffer->x_resolution = ctx->front->x_resolution;
                    dcc_buffer->y_resolution = ctx->front->y_resolution;
                    dcc_buffer->data.config_host.host_size = static_cast<size_t>(dcc_buffer->x_resolution*dcc_buffer->y_resolution*3)*sizeof(float);
                    magik::bridge::host_destroy_host_memory(dcc_buffer->data.config_host.h_albedo);
                    dcc_buffer->data.config_host.h_albedo = magik::bridge::host_allocate_host_memory(dcc_buffer->data.config_host.host_size);
                }

                magik::bridge::host_memcpy_device_to_host(dcc_buffer->data.config_host.h_albedo, ctx->front->d_albedo, dcc_buffer->data.config_host.host_size);
                break;
            }

            case MAGIK_AOV_CONFIG_CUDA:
            {
                break;
            }

            case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
            {
                break;
            }

            case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
            {
                break;
            }
        }

        set_error(MAGIK_SUCCESS);
    }

    e_magik_result_types destroy_framebuffer_collection(magik::aov::context* ctx)
    {
        for(uint32_t i = 0; i < 3; i++)
        {
            magik::bridge::host_destroy_device_memory(ctx->framebuffer_object_collection[i].d_albedo);
        }

        set_error(MAGIK_SUCCESS);
    }
};
