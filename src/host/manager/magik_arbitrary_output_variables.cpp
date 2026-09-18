#include "magik_arbitrary_output_variables.h"
#include "magik_render_manager.h"

namespace magik::aov
{
    e_magik_result_types configure_framebuffer_object(magik_aov_framebuffer_object_external_t* framebuffer, e_magik_aov_config_types config_type)
    {
        magik_aov_framebuffer_object_external* buffer = new magik_aov_framebuffer_object_external();
        
        if(config_type != MAGIK_AOV_CONFIG_HOST && config_type != MAGIK_AOV_CONFIG_CUDA && config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_UNKNOWN_ENUM_TYPE;
            delete buffer;
        }

        buffer->config_type = config_type;

        *framebuffer = buffer;
        return MAGIK_SUCCESS;
    }

    e_magik_result_types fetch(magik_render_manager_t manager, bool* is_new_fetch, magik_aov_framebuffer_object_external_t framebuffer_object)
    {
        if(!manager || !framebuffer_object)
        {
            *is_new_fetch = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(!manager->is_running.load(std::memory_order_acquire))
        {
            *is_new_fetch = false;
            return MAGIK_SUCCESS;
        }

        if(manager->display_type == MAGIK_DISPLAY_HEADLESS)
        {
            *is_new_fetch = false;
            return MAGIK_ERROR_AOV_SWAPCHAIN_NOT_INITALIZED;
        }

        bool is_swapped = false;
        auto _r = magik::aov::try_swap_front_framebuffer(&manager->aov_context, &is_swapped);
        if(!is_swapped)
        {
            *is_new_fetch = false;
            return _r;
        }

        *is_new_fetch = true;
        return magik::aov::memcpy_front_framebuffer_to_dcc_framebuffer(&manager->aov_context, framebuffer_object);
    }

    e_magik_result_types extract_config_host(magik_render_manager_t manager, magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t framebuffer_object, const char* name)
    {
        if(!manager || !container || !framebuffer_object) return MAGIK_ERROR_INVALID_POINTER;

        if(!manager->is_running.load(std::memory_order_acquire))
        {
            return MAGIK_SUCCESS;
        }

        if(framebuffer_object->config_type != MAGIK_AOV_CONFIG_HOST)
        {
            return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = framebuffer_object->collection.find(name);

        if(element == framebuffer_object->collection.end())
        {
            return MAGIK_SUCCESS;
        }

        container->x_resolution = element->second.x_resolution;
        container->y_resolution = element->second.y_resolution;
        container->channels = element->second.channels;
        container->size_of_data = element->second.config_host.host_size;
        container->h_data = element->second.config_host.h_data;

        return MAGIK_SUCCESS;
    }

    e_magik_result_types extract_config_opengl_interop(magik_render_manager_t manager, magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t framebuffer_object, const char* name)
    {
        if(!manager || !container || !framebuffer_object) return MAGIK_ERROR_INVALID_POINTER;

        if(!manager->is_running.load(std::memory_order_acquire))
        {
            return MAGIK_SUCCESS;
        }

        if(framebuffer_object->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP)
        {
            return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = framebuffer_object->collection.find(name);

        if(element == framebuffer_object->collection.end())
        {
            return MAGIK_SUCCESS;
        }

        container->x_resolution = element->second.x_resolution;
        container->y_resolution = element->second.y_resolution;
        container->channels = element->second.channels;
        container->gl_buffer_id = element->second.config_open_gl_interop.gl_buffer_id;
        container->cuda_resources = element->second.config_open_gl_interop.cuda_resource;

        return MAGIK_SUCCESS;
    }

    e_magik_result_types destroy_framebuffer_object(magik_aov_framebuffer_object_external_t framebuffer_object)
    {
        if(!framebuffer_object) return MAGIK_SUCCESS;

        if(framebuffer_object->config_type != MAGIK_AOV_CONFIG_HOST && framebuffer_object->config_type != MAGIK_AOV_CONFIG_CUDA && framebuffer_object->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && framebuffer_object->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_UNKNOWN_ENUM_TYPE;
        }

        e_magik_result_types _r = MAGIK_SUCCESS;

        for(auto& [key, value] : framebuffer_object->collection)
        {
            switch(framebuffer_object->config_type)
            {
                case MAGIK_AOV_CONFIG_HOST:
                {
                    magik::bridge::host_destroy_host_memory(value.config_host.h_data);
                    break;
                }

                case MAGIK_AOV_CONFIG_CUDA:
                {
                    magik::bridge::host_destroy_device_memory(value.config_cuda.d_data);
                    break;
                }

                case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
                {
                    _r = magik::bridge::host_free_gl_buffer(&value.config_open_gl_interop.gl_buffer_id, &value.config_open_gl_interop.cuda_resource);
                    break;
                }

                case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
                {
                    break;
                }
            }
        }

        framebuffer_object->collection.clear();

        delete framebuffer_object;
        return _r;
    }

    e_magik_result_types initialize_swapchain(magik::aov::context* ctx)
    {
        if(!ctx)
        {
            return MAGIK_ERROR_INVALID_POINTER;
        }

        ctx->front_framebuffer_object = &ctx->framebuffer_object_collection[0];
        ctx->ready_framebuffer_object.store(&ctx->framebuffer_object_collection[1], std::memory_order_relaxed);
        ctx->back_framebuffer_object = &ctx->framebuffer_object_collection[2];

        return MAGIK_SUCCESS;
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

        return MAGIK_SUCCESS;
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

        return MAGIK_SUCCESS;
    }

    e_magik_result_types swap_back_framebuffer(magik::aov::context* ctx)
    {
        if(!ctx || !ctx->ready_framebuffer_object.load(std::memory_order_relaxed) || !ctx->back_framebuffer_object) return MAGIK_ERROR_INVALID_POINTER;

        ctx->back_framebuffer_object = ctx->ready_framebuffer_object.exchange(ctx->back_framebuffer_object, std::memory_order_acq_rel);
        ctx->is_ready_updated.store(true, std::memory_order_release);
        return MAGIK_SUCCESS;
    }

    e_magik_result_types try_swap_front_framebuffer(magik::aov::context* ctx, bool* is_swapped)
    {
        if(!ctx || !ctx->ready_framebuffer_object.load(std::memory_order_relaxed) || !ctx->front_framebuffer_object)
        {
            *is_swapped = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(!ctx->is_ready_updated.exchange(false, std::memory_order_acquire)) 
        {
            *is_swapped = false;
            return MAGIK_SUCCESS;
        }
        
        ctx->front_framebuffer_object = ctx->ready_framebuffer_object.exchange(ctx->front_framebuffer_object, std::memory_order_acq_rel);

        *is_swapped = true;
        return MAGIK_SUCCESS;
    }

    static e_magik_result_types memcpy_front_to_host_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* framebuffer_object)
    {
        for(auto iter = framebuffer_object->collection.begin(); iter != framebuffer_object->collection.end(); )
        {
            auto element = ctx->front_framebuffer_object->collection.find(iter->first);

            if(element == ctx->front_framebuffer_object->collection.end())
            {
                auto buffer = iter->second;
                magik::bridge::host_destroy_host_memory(buffer.config_host.h_data);
                iter = framebuffer_object->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : ctx->front_framebuffer_object->collection)
        {
            framebuffer_object->collection.try_emplace(key); 
            auto& dcc_value = framebuffer_object->collection.find(key)->second;

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

        return MAGIK_SUCCESS;
    };

    static e_magik_result_types memcpy_front_to_cuda_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* framebuffer_object)
    {
        return MAGIK_SUCCESS;
    };

    static e_magik_result_types memcpy_front_to_opengl_interop_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* framebuffer_object)
    {
        e_magik_result_types _r = MAGIK_SUCCESS;

        for(auto iter = framebuffer_object->collection.begin(); iter != framebuffer_object->collection.end(); )
        {
            auto element = ctx->front_framebuffer_object->collection.find(iter->first);

            if(element == ctx->front_framebuffer_object->collection.end())
            {
                auto buffer = iter->second;
                _r = magik::bridge::host_free_gl_buffer(&buffer.config_open_gl_interop.gl_buffer_id, &buffer.config_open_gl_interop.cuda_resource);
                iter = framebuffer_object->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : ctx->front_framebuffer_object->collection)
        {
            framebuffer_object->collection.try_emplace(key); 
            auto& dcc_value = framebuffer_object->collection.find(key)->second; 

            if((dcc_value.x_resolution != ctx_value.x_resolution) || (dcc_value.y_resolution != ctx_value.y_resolution) || (dcc_value.channels != ctx_value.channels) || (!dcc_value.config_open_gl_interop.cuda_resource) || (dcc_value.config_open_gl_interop.gl_buffer_id == 0))
            {
                dcc_value.x_resolution = ctx_value.x_resolution;
                dcc_value.y_resolution = ctx_value.y_resolution;
                dcc_value.channels = ctx_value.channels;

                _r = magik::bridge::host_free_gl_buffer(&dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
                _r = magik::bridge::host_allocate_gl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
            }

            magik::bridge::host_map_cuda_to_gl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.cuda_resource, ctx_value.d_data);
        }

        return _r;
    };

    static e_magik_result_types memcpy_front_to_vulkan_interop_config_dcc(magik::aov::context* ctx, magik_aov_framebuffer_object_external* framebuffer_object)
    {
        return MAGIK_SUCCESS;
    };

    e_magik_result_types memcpy_front_framebuffer_to_dcc_framebuffer(magik::aov::context* ctx, magik_aov_framebuffer_object_external* framebuffer_object)
    {
        if(!ctx || !framebuffer_object || !ctx->front_framebuffer_object) return MAGIK_ERROR_INVALID_POINTER;

        if( framebuffer_object->config_type != MAGIK_AOV_CONFIG_HOST && 
            framebuffer_object->config_type != MAGIK_AOV_CONFIG_CUDA && 
            framebuffer_object->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && 
            framebuffer_object->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP
        ) return MAGIK_UNKNOWN_ENUM_TYPE;

        e_magik_result_types result = MAGIK_SUCCESS;

        switch(framebuffer_object->config_type)
        {
            case MAGIK_AOV_CONFIG_HOST:
            {
                result = memcpy_front_to_host_config_dcc(ctx, framebuffer_object);
                break;
            }

            case MAGIK_AOV_CONFIG_CUDA:
            {
                result = memcpy_front_to_cuda_config_dcc(ctx, framebuffer_object);
                break;
            }

            case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
            {
                result = memcpy_front_to_opengl_interop_config_dcc(ctx, framebuffer_object);
                break;
            }

            case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
            {
                result = memcpy_front_to_vulkan_interop_config_dcc(ctx, framebuffer_object);
                break;
            }
        }

        return result;
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

        return MAGIK_SUCCESS;
    }

    e_magik_result_types destroy_render_framebuffer_object(magik::aov::context* ctx)
    {
        for(const auto& [key, value] : ctx->render_framebuffer_object.collection)
        {
            magik::bridge::host_destroy_device_memory(value.d_data);
        }

        ctx->render_framebuffer_object.collection.clear();

        return MAGIK_SUCCESS;
    }
};
