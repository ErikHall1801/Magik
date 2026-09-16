#include "magik_arbitrary_output_variables.h"

namespace magik::aov
{
    e_magik_result_types initialize_swapchain(magik::aov::context* ctx)
    {
        if(!ctx)
        {
            set_and_return_error(MAGIK_ERROR_INVALID_POINTER);
        }

        ctx->front_framebuffer_object = &ctx->framebuffer_object_collection[0];
        ctx->ready_framebuffer_object.store(&ctx->framebuffer_object_collection[1], std::memory_order_relaxed);
        ctx->back_framebuffer_object = &ctx->framebuffer_object_collection[2];

        set_and_return_error(MAGIK_SUCCESS);
    }

    e_magik_result_types allocate_render_framebuffer_object(bool& is_dirty, magik::aov::context* ctx)
    {
        if(ctx->x_resolution_target <= 0) {ctx->x_resolution_target = 2;}
        if(ctx->y_resolution_target <= 0) {ctx->y_resolution_target = 2;}

        size_t size_of_nth_buffer = 0;

        is_dirty = false;

        for(auto& [key, value] : ctx->render_framebuffer_object.collection)
        {
            if((ctx->x_resolution_target != value.x_resolution) || (ctx->y_resolution_target != value.y_resolution))
            {
                is_dirty = true;

                size_of_nth_buffer = static_cast<size_t>(ctx->x_resolution_target*ctx->y_resolution_target*value.channels) * sizeof(float);

                magik::bridge::host_destroy_device_memory(value.d_data);

                value.x_resolution = ctx->x_resolution_target;
                value.y_resolution = ctx->y_resolution_target;
                value.d_data = magik::bridge::host_allocate_device_memory(size_of_nth_buffer);
            }
        }

        set_and_return_error(MAGIK_SUCCESS);
    }

    e_magik_result_types memcpy_render_to_back_framebuffer_object(magik::aov::context* ctx)
    {
        for(auto iter = ctx->back_framebuffer_object->collection.begin(); iter != ctx->back_framebuffer_object->collection.end();)
        {
            auto render_element = ctx->render_framebuffer_object.collection.find(iter->first);

            if(render_element == ctx->render_framebuffer_object.collection.end())
            {
                magik::bridge::host_destroy_device_memory(iter->second.d_data);
                iter = ctx->back_framebuffer_object->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(auto& [target_key, target_value] : ctx->render_framebuffer_object.collection)
        {
            ctx->back_framebuffer_object->collection.emplace(target_key, raw_buffer());

            auto& back_element = ctx->back_framebuffer_object->collection.find(target_key)->second;

            size_t size_of_target = static_cast<size_t>(target_value.x_resolution*target_value.y_resolution*target_value.channels)*sizeof(float);

            if((back_element.x_resolution != target_value.x_resolution) || (back_element.y_resolution != target_value.y_resolution) || (back_element.channels != target_value.channels) || !back_element.d_data)
            {
                magik::bridge::host_destroy_device_memory(back_element.d_data);

                back_element.x_resolution = target_value.x_resolution;
                back_element.y_resolution = target_value.y_resolution;
                back_element.channels = target_value.channels;
                back_element.d_data = magik::bridge::host_allocate_device_memory(size_of_target);
            }

            magik::bridge::host_memcpy_device_to_device(back_element.d_data, target_value.d_data, size_of_target);
        }

        set_and_return_error(MAGIK_SUCCESS);
    }

    e_magik_result_types swap_back_framebuffer(magik::aov::context* ctx)
    {
        if(!ctx || !ctx->ready_framebuffer_object.load(std::memory_order_relaxed) || !ctx->back_framebuffer_object) set_and_return_error(MAGIK_ERROR_INVALID_POINTER);

        ctx->back_framebuffer_object = ctx->ready_framebuffer_object.exchange(ctx->back_framebuffer_object, std::memory_order_acq_rel);
        ctx->is_ready_updated.store(true, std::memory_order_release);
        set_and_return_error(MAGIK_SUCCESS);
    }

    bool try_swap_front_framebuffer(magik::aov::context* ctx)
    {
        if(!ctx || !ctx->ready_framebuffer_object.load(std::memory_order_relaxed) || !ctx->front_framebuffer_object)
        {
            g_last_error = MAGIK_ERROR_INVALID_POINTER;
            return false;
        }

        if(!ctx->is_ready_updated.exchange(false, std::memory_order_acquire)) 
        {
            g_last_error = MAGIK_SUCCESS;
            return false;
        }
        
        ctx->front_framebuffer_object = ctx->ready_framebuffer_object.exchange(ctx->front_framebuffer_object, std::memory_order_acq_rel);

        g_last_error = MAGIK_SUCCESS;
        return true;
    }

    static e_magik_result_types memcpy_front_to_host_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        for(auto iter = dcc_buffer->collection.begin(); iter != dcc_buffer->collection.end(); )
        {
            auto element = ctx->front_framebuffer_object->collection.find(iter->first);

            if(element == ctx->front_framebuffer_object->collection.end())
            {
                auto buffer = iter->second;
                magik::bridge::host_destroy_host_memory(buffer.config_host.h_data);
                iter = dcc_buffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : ctx->front_framebuffer_object->collection)
        {
            dcc_buffer->collection.try_emplace(key); 
            auto& dcc_value = dcc_buffer->collection.find(key)->second;

            size_t size_of_buffer = static_cast<size_t>(ctx_value.x_resolution*ctx_value.y_resolution*ctx_value.channels)*sizeof(float);

            if((!dcc_value.config_host.h_data) || (dcc_value.x_resolution != ctx_value.x_resolution) || (dcc_value.y_resolution != ctx_value.y_resolution) || (dcc_value.channels != ctx_value.channels))
            {
                magik::bridge::host_destroy_host_memory(dcc_value.config_host.h_data);

                dcc_value.x_resolution = ctx_value.x_resolution;
                dcc_value.y_resolution = ctx_value.y_resolution;
                dcc_value.channels = ctx_value.channels;
                dcc_value.config_host.h_data = magik::bridge::host_allocate_host_memory(size_of_buffer);
                dcc_value.config_host.host_size = size_of_buffer;
            }

            magik::bridge::host_memcpy_device_to_host(dcc_value.config_host.h_data, ctx_value.d_data, size_of_buffer);
        }

        set_and_return_error(MAGIK_SUCCESS);
    };

    static e_magik_result_types memcpy_front_to_cuda_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        set_and_return_error(MAGIK_SUCCESS);
    };

    static e_magik_result_types memcpy_front_to_opengl_interop_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        for(auto iter = dcc_buffer->collection.begin(); iter != dcc_buffer->collection.end(); )
        {
            auto element = ctx->front_framebuffer_object->collection.find(iter->first);

            if(element == ctx->front_framebuffer_object->collection.end())
            {
                auto buffer = iter->second;
                magik::bridge::host_free_gl_buffer(&buffer.config_open_gl_interop.gl_buffer_id, &buffer.config_open_gl_interop.cuda_resource);
                iter = dcc_buffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : ctx->front_framebuffer_object->collection)
        {
            dcc_buffer->collection.try_emplace(key); 
            auto& dcc_value = dcc_buffer->collection.find(key)->second; 

            if((dcc_value.x_resolution != ctx_value.x_resolution) || (dcc_value.y_resolution != ctx_value.y_resolution) || (dcc_value.channels != ctx_value.channels) || (!dcc_value.config_open_gl_interop.cuda_resource) || (dcc_value.config_open_gl_interop.gl_buffer_id == 0))
            {
                dcc_value.x_resolution = ctx_value.x_resolution;
                dcc_value.y_resolution = ctx_value.y_resolution;
                dcc_value.channels = ctx_value.channels;

                magik::bridge::host_free_gl_buffer(&dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
                magik::bridge::host_allocate_gl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
            }

            magik::bridge::host_map_cuda_to_gl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.cuda_resource, ctx_value.d_data);
        }

        set_and_return_error(MAGIK_SUCCESS);
    };

    static e_magik_result_types memcpy_front_to_vulkan_interop_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        set_and_return_error(MAGIK_SUCCESS);
    };

    e_magik_result_types memcpy_front_framebuffer_to_dcc_framebuffer(magik::aov::context* ctx, magik_aov_framebuffer_object_external* dcc_buffer)
    {
        if(!ctx || !dcc_buffer || !ctx->front_framebuffer_object) set_and_return_error(MAGIK_ERROR_INVALID_POINTER);

        if( dcc_buffer->config_type != MAGIK_AOV_CONFIG_HOST && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_CUDA && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && 
            dcc_buffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP
        ) set_and_return_error(MAGIK_UNKNOWN_ENUM_TYPE);

        e_magik_result_types result = MAGIK_SUCCESS;

        switch(dcc_buffer->config_type)
        {
            case MAGIK_AOV_CONFIG_HOST:
            {
                result = memcpy_front_to_host_config_dcc(ctx, dcc_buffer);
                break;
            }

            case MAGIK_AOV_CONFIG_CUDA:
            {
                result = memcpy_front_to_cuda_config_dcc(ctx, dcc_buffer);
                break;
            }

            case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
            {
                result = memcpy_front_to_opengl_interop_config_dcc(ctx, dcc_buffer);
                break;
            }

            case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
            {
                result = memcpy_front_to_vulkan_interop_config_dcc(ctx, dcc_buffer);
                break;
            }
        }

        set_and_return_error(result);
    }

    e_magik_result_types destroy_swpachain(magik::aov::context* ctx)
    {
        for(uint32_t i = 0; i < 3; i++)
        {
            for(const auto& [key, ctx_value] : ctx->framebuffer_object_collection[i].collection)
            {
                magik::bridge::host_destroy_device_memory(ctx_value.d_data);
            }

            ctx->framebuffer_object_collection[i].collection.clear();
        }

        set_and_return_error(MAGIK_SUCCESS);
    }

    e_magik_result_types destroy_render_framebuffer_object(magik::aov::context* ctx)
    {
        for(const auto& [key, value] : ctx->render_framebuffer_object.collection)
        {
            magik::bridge::host_destroy_device_memory(value.d_data);
        }

        ctx->render_framebuffer_object.collection.clear();

        set_and_return_error(MAGIK_SUCCESS);
    }
};
