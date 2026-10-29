#include "framebuffer.h"
#include "renderer.h"

namespace magik
{
    e_magik_result_types configure_external_framebuffer_collection(magik_aov_framebuffer_object_external_t* external_collection_framebuffer, e_magik_aov_config_types config_type)
    {
        magik_aov_framebuffer_object_external* buffer = new magik_aov_framebuffer_object_external();
        
        if(config_type != MAGIK_AOV_CONFIG_HOST && config_type != MAGIK_AOV_CONFIG_CUDA && config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_UNKNOWN_ENUM_TYPE;
            delete buffer;
        }

        buffer->config_type = config_type;

        *external_collection_framebuffer = buffer;
        return MAGIK_SUCCESS;
    }

    e_magik_result_types fetch_framebuffer_collection(magik_render_manager_t manager, magik_aov_framebuffer_object_external_t external_collection_framebuffer, bool* is_new_fetch)
    {
        if(!manager || !external_collection_framebuffer)
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
        auto _r = try_swap_front_framebuffer(&manager->framebuffer_swapchain, &is_swapped);
        if(!is_swapped)
        {
            *is_new_fetch = false;
            return _r;
        }

        *is_new_fetch = true;
        return memcpy_front_framebuffer_to_external_framebuffer(&manager->framebuffer_swapchain, external_collection_framebuffer);
    }

    e_magik_result_types extract_config_host(magik_render_manager_t manager, magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t external_collection_framebuffer, const char* name)
    {
        if(!manager || !container || !external_collection_framebuffer) return MAGIK_ERROR_INVALID_POINTER;

        if(!manager->is_running.load(std::memory_order_acquire))
        {
            return MAGIK_SUCCESS;
        }

        if(external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_HOST)
        {
            return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = external_collection_framebuffer->collection.find(name);

        if(element == external_collection_framebuffer->collection.end())
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

    e_magik_result_types extract_config_opengl_interop(magik_render_manager_t manager, magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t external_collection_framebuffer, const char* name)
    {
        if(!manager || !container || !external_collection_framebuffer) return MAGIK_ERROR_INVALID_POINTER;

        if(!manager->is_running.load(std::memory_order_acquire))
        {
            return MAGIK_SUCCESS;
        }

        if(external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP)
        {
            return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = external_collection_framebuffer->collection.find(name);

        if(element == external_collection_framebuffer->collection.end())
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

    e_magik_result_types destroy_external_framebuffer_collection(magik_aov_framebuffer_object_external_t external_collection_framebuffer)
    {
        if(!external_collection_framebuffer) return MAGIK_SUCCESS;

        if( external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_HOST && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_CUDA && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_UNKNOWN_ENUM_TYPE;
        }

        e_magik_result_types _r = MAGIK_SUCCESS;

        for(auto& [key, value] : external_collection_framebuffer->collection)
        {
            switch(external_collection_framebuffer->config_type)
            {
                case MAGIK_AOV_CONFIG_HOST:
                {
                    magik::free_host(value.config_host.h_data);
                    break;
                }

                case MAGIK_AOV_CONFIG_CUDA:
                {
                    magik::free_device(value.config_cuda.d_data);
                    break;
                }

                case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
                {
                    _r = magik::free_opengl_buffer(&value.config_open_gl_interop.gl_buffer_id, &value.config_open_gl_interop.cuda_resource);
                    break;
                }

                case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
                {
                    break;
                }
            }
        }

        external_collection_framebuffer->collection.clear();

        delete external_collection_framebuffer;
        return _r;
    }

    e_magik_result_types initialize_framebuffer_swapchain(framebuffer_swapchain_t* framebuffer_swapchain)
    {
        if(!framebuffer_swapchain)
        {
            return MAGIK_ERROR_INVALID_POINTER;
        }

        framebuffer_swapchain->front_framebuffer = &framebuffer_swapchain->framebuffer_collection[0];
        framebuffer_swapchain->ready_framebuffer.store(&framebuffer_swapchain->framebuffer_collection[1], std::memory_order_relaxed);
        framebuffer_swapchain->back_framebuffer = &framebuffer_swapchain->framebuffer_collection[2];

        return MAGIK_SUCCESS;
    }

    e_magik_result_types allocate_render_framebuffer_swapchain(framebuffer_swapchain_t* framebuffer_swapchain, bool* is_dirty)
    {
        if(framebuffer_swapchain->x_resolution_target <= 0) {framebuffer_swapchain->x_resolution_target = 2;}
        if(framebuffer_swapchain->y_resolution_target <= 0) {framebuffer_swapchain->y_resolution_target = 2;}

        size_t size_of_nth_buffer = 0;

        *is_dirty = false;

        for(auto& [key, value] : framebuffer_swapchain->render_framebuffer.collection)
        {
            if((framebuffer_swapchain->x_resolution_target != value.x_resolution) || (framebuffer_swapchain->y_resolution_target != value.y_resolution))
            {
                *is_dirty = true;

                size_of_nth_buffer = static_cast<size_t>(framebuffer_swapchain->x_resolution_target*framebuffer_swapchain->y_resolution_target*value.channels) * sizeof(float);

                magik::free_device(value.d_data);

                value.x_resolution = framebuffer_swapchain->x_resolution_target;
                value.y_resolution = framebuffer_swapchain->y_resolution_target;
                value.d_data = magik::allocate_device<float>(size_of_nth_buffer);
            }
        }

        return MAGIK_SUCCESS;
    }

    e_magik_result_types memcpy_render_to_back_framebuffer(framebuffer_swapchain_t* framebuffer_swapchain)
    {
        for(auto iter = framebuffer_swapchain->back_framebuffer->collection.begin(); iter != framebuffer_swapchain->back_framebuffer->collection.end();)
        {
            auto render_element = framebuffer_swapchain->render_framebuffer.collection.find(iter->first);

            if(render_element == framebuffer_swapchain->render_framebuffer.collection.end())
            {
                magik::free_device(iter->second.d_data);
                iter = framebuffer_swapchain->back_framebuffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(auto& [target_key, target_value] : framebuffer_swapchain->render_framebuffer.collection)
        {
            framebuffer_swapchain->back_framebuffer->collection.emplace(target_key, framebuffer_t());

            auto& back_element = framebuffer_swapchain->back_framebuffer->collection.find(target_key)->second;

            size_t size_of_target = static_cast<size_t>(target_value.x_resolution*target_value.y_resolution*target_value.channels)*sizeof(float);

            if((back_element.x_resolution != target_value.x_resolution) || (back_element.y_resolution != target_value.y_resolution) || (back_element.channels != target_value.channels) || !back_element.d_data)
            {
                magik::free_device(back_element.d_data);

                back_element.x_resolution = target_value.x_resolution;
                back_element.y_resolution = target_value.y_resolution;
                back_element.channels = target_value.channels;
                back_element.d_data = magik::allocate_device<float>(size_of_target);
            }

            magik::memcpy_device_to_device(back_element.d_data, target_value.d_data, size_of_target);
        }

        return MAGIK_SUCCESS;
    }

    e_magik_result_types swap_back_framebuffer(framebuffer_swapchain_t* framebuffer_swapchain)
    {
        if(!framebuffer_swapchain || !framebuffer_swapchain->ready_framebuffer.load(std::memory_order_relaxed) || !framebuffer_swapchain->back_framebuffer) return MAGIK_ERROR_INVALID_POINTER;

        framebuffer_swapchain->back_framebuffer = framebuffer_swapchain->ready_framebuffer.exchange(framebuffer_swapchain->back_framebuffer, std::memory_order_acq_rel);
        framebuffer_swapchain->is_ready_framebuffer_updated.store(true, std::memory_order_release);
        return MAGIK_SUCCESS;
    }

    e_magik_result_types try_swap_front_framebuffer(framebuffer_swapchain_t* framebuffer_swapchain, bool* is_swapped)
    {
        if(!framebuffer_swapchain || !framebuffer_swapchain->ready_framebuffer.load(std::memory_order_relaxed) || !framebuffer_swapchain->front_framebuffer)
        {
            *is_swapped = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(!framebuffer_swapchain->is_ready_framebuffer_updated.exchange(false, std::memory_order_acquire)) 
        {
            *is_swapped = false;
            return MAGIK_SUCCESS;
        }

        framebuffer_swapchain->front_framebuffer = framebuffer_swapchain->ready_framebuffer.exchange(framebuffer_swapchain->front_framebuffer, std::memory_order_acq_rel);

        *is_swapped = true;
        return MAGIK_SUCCESS;
    }

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_host(framebuffer_swapchain_t* framebuffer_swapchain, magik_aov_framebuffer_object_external* external_collection_framebuffer)
    {
        for(auto iter = external_collection_framebuffer->collection.begin(); iter != external_collection_framebuffer->collection.end(); )
        {
            auto element = framebuffer_swapchain->front_framebuffer->collection.find(iter->first);

            if(element == framebuffer_swapchain->front_framebuffer->collection.end())
            {
                auto buffer = iter->second;
                magik::free_host(buffer.config_host.h_data);
                iter = external_collection_framebuffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : framebuffer_swapchain->front_framebuffer->collection)
        {
            external_collection_framebuffer->collection.try_emplace(key); 
            auto& dcc_value = external_collection_framebuffer->collection.find(key)->second;

            size_t size_of_buffer = static_cast<size_t>(ctx_value.x_resolution*ctx_value.y_resolution*ctx_value.channels)*sizeof(float);

            if((!dcc_value.config_host.h_data) || (dcc_value.x_resolution != ctx_value.x_resolution) || (dcc_value.y_resolution != ctx_value.y_resolution) || (dcc_value.channels != ctx_value.channels))
            {
                magik::free_host(dcc_value.config_host.h_data);

                dcc_value.x_resolution = ctx_value.x_resolution;
                dcc_value.y_resolution = ctx_value.y_resolution;
                dcc_value.channels = ctx_value.channels;
                dcc_value.config_host.h_data = magik::allocate_host<float>(size_of_buffer);
                dcc_value.config_host.host_size = size_of_buffer;
            }

            magik::memcpy_device_to_host(ctx_value.d_data, dcc_value.config_host.h_data, size_of_buffer);
        }

        return MAGIK_SUCCESS;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_cuda(framebuffer_swapchain_t* framebuffer_swapchain, magik_aov_framebuffer_object_external* external_collection_framebuffer)
    {
        return MAGIK_SUCCESS;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_opengl(framebuffer_swapchain_t* framebuffer_swapchain, magik_aov_framebuffer_object_external* external_collection_framebuffer)
    {
        e_magik_result_types _r = MAGIK_SUCCESS;

        for(auto iter = external_collection_framebuffer->collection.begin(); iter != external_collection_framebuffer->collection.end(); )
        {
            auto element = framebuffer_swapchain->front_framebuffer->collection.find(iter->first);

            if(element == framebuffer_swapchain->front_framebuffer->collection.end())
            {
                auto buffer = iter->second;
                _r = magik::free_opengl_buffer(&buffer.config_open_gl_interop.gl_buffer_id, &buffer.config_open_gl_interop.cuda_resource);
                iter = external_collection_framebuffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(const auto& [key, ctx_value] : framebuffer_swapchain->front_framebuffer->collection)
        {
            external_collection_framebuffer->collection.try_emplace(key); 
            auto& dcc_value = external_collection_framebuffer->collection.find(key)->second; 

            if((dcc_value.x_resolution != ctx_value.x_resolution) || (dcc_value.y_resolution != ctx_value.y_resolution) || (dcc_value.channels != ctx_value.channels) || (!dcc_value.config_open_gl_interop.cuda_resource) || (dcc_value.config_open_gl_interop.gl_buffer_id == 0))
            {
                dcc_value.x_resolution = ctx_value.x_resolution;
                dcc_value.y_resolution = ctx_value.y_resolution;
                dcc_value.channels = ctx_value.channels;

                _r = magik::free_opengl_buffer(&dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
                _r = magik::allocate_opengl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.gl_buffer_id, &dcc_value.config_open_gl_interop.cuda_resource);
            }

            magik::map_cuda_to_opengl_buffer(dcc_value.x_resolution, dcc_value.y_resolution, dcc_value.channels, &dcc_value.config_open_gl_interop.cuda_resource, ctx_value.d_data);
        }

        return _r;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_vulkan(framebuffer_swapchain_t* framebuffer_swapchain, magik_aov_framebuffer_object_external* external_collection_framebuffer)
    {
        return MAGIK_SUCCESS;
    };

    e_magik_result_types memcpy_front_framebuffer_to_external_framebuffer(framebuffer_swapchain_t* framebuffer_swapchain, magik_aov_framebuffer_object_external* external_collection_framebuffer)
    {
        if(!framebuffer_swapchain || !external_collection_framebuffer || !framebuffer_swapchain->front_framebuffer) return MAGIK_ERROR_INVALID_POINTER;

        if( external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_HOST && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_CUDA && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && 
            external_collection_framebuffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP
        ) return MAGIK_UNKNOWN_ENUM_TYPE;

        e_magik_result_types result = MAGIK_SUCCESS;

        switch(external_collection_framebuffer->config_type)
        {
            case MAGIK_AOV_CONFIG_HOST:
            {
                result = memcpy_front_framebuffer_to_external_config_host(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_AOV_CONFIG_CUDA:
            {
                result = memcpy_front_framebuffer_to_external_config_cuda(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_AOV_CONFIG_OPENGL_INTEROP:
            {
                result = memcpy_front_framebuffer_to_external_config_opengl(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_AOV_CONFIG_VULKAN_INTEROP:
            {
                result = memcpy_front_framebuffer_to_external_config_vulkan(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }
        }

        return result;
    }

    e_magik_result_types destroy_framebuffer_swpachain(framebuffer_swapchain_t* framebuffer_swapchain)
    {
        for(uint32_t i = 0; i < 3; i++)
        {
            for(const auto& [key, ctx_value] : framebuffer_swapchain->framebuffer_collection[i].collection)
            {
                magik::free_device(ctx_value.d_data);
            }

            framebuffer_swapchain->framebuffer_collection[i].collection.clear();
        }

        for(const auto& [key, value] : framebuffer_swapchain->render_framebuffer.collection)
        {
            magik::free_device(value.d_data);
        }

        framebuffer_swapchain->render_framebuffer.collection.clear();

        return MAGIK_SUCCESS;
    }
}
