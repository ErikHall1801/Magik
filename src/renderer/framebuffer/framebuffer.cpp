#include "framebuffer.h"

namespace magik
{
    // DCC
    static e_magik_result_types memcpy_front_framebuffer_to_external_config_host(framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external* external_collection_framebuffer)
    {
        for(auto iter = external_collection_framebuffer->collection.begin(); iter != external_collection_framebuffer->collection.end(); )
        {
            auto element = framebuffer_swapchain.front_framebuffer->collection.find(iter->first);

            if(element == framebuffer_swapchain.front_framebuffer->collection.end())
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

        for(const auto& [key, ctx_value] : framebuffer_swapchain.front_framebuffer->collection)
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

        return MAGIK_RESULT_SUCCESS;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_cuda(framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external* external_collection_framebuffer)
    {
        return MAGIK_RESULT_SUCCESS;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_opengl(framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external* external_collection_framebuffer)
    {
        e_magik_result_types _r = MAGIK_RESULT_SUCCESS;

        for(auto iter = external_collection_framebuffer->collection.begin(); iter != external_collection_framebuffer->collection.end(); )
        {
            auto element = framebuffer_swapchain.front_framebuffer->collection.find(iter->first);

            if(element == framebuffer_swapchain.front_framebuffer->collection.end())
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

        for(const auto& [key, ctx_value] : framebuffer_swapchain.front_framebuffer->collection)
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

    static e_magik_result_types memcpy_front_framebuffer_to_external_config_vulkan(framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external* external_collection_framebuffer)
    {
        return MAGIK_RESULT_SUCCESS;
    };

    static e_magik_result_types memcpy_front_framebuffer_to_external_framebuffer(framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external* external_collection_framebuffer)
    {
        if(!external_collection_framebuffer || !framebuffer_swapchain.front_framebuffer) return MAGIK_RESULT_INVALID_POINTER;

        if( external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP
        ) return MAGIK_RESULT_UNKNOWN_ENUM_TYPE;

        e_magik_result_types result = MAGIK_RESULT_SUCCESS;

        switch(external_collection_framebuffer->config_type)
        {
            case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST:
            {
                result = memcpy_front_framebuffer_to_external_config_host(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA:
            {
                result = memcpy_front_framebuffer_to_external_config_cuda(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP:
            {
                result = memcpy_front_framebuffer_to_external_config_opengl(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }

            case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP:
            {
                result = memcpy_front_framebuffer_to_external_config_vulkan(framebuffer_swapchain, external_collection_framebuffer);
                break;
            }
        }

        return result;
    }

    static e_magik_result_types try_swap_front_framebuffer(framebuffer_swapchain_t& framebuffer_swapchain, bool* is_swapped)
    {
        if(!framebuffer_swapchain.ready_framebuffer.load(std::memory_order_relaxed) || !framebuffer_swapchain.front_framebuffer)
        {
            *is_swapped = false;
            return MAGIK_RESULT_INVALID_POINTER;
        }

        if(!framebuffer_swapchain.is_ready_framebuffer_updated.exchange(false, std::memory_order_acquire)) 
        {
            *is_swapped = false;
            return MAGIK_RESULT_SUCCESS;
        }

        framebuffer_swapchain.front_framebuffer = framebuffer_swapchain.ready_framebuffer.exchange(framebuffer_swapchain.front_framebuffer, std::memory_order_acq_rel);

        *is_swapped = true;
        return MAGIK_RESULT_SUCCESS;
    }

    e_magik_result_types configure_external_framebuffer_collection(magik_framebuffer_collection_external_t* external_collection_framebuffer, e_magik_framebuffer_collection_config_types config_type)
    {
        magik_framebuffer_collection_external* buffer = new magik_framebuffer_collection_external();
        
        if(config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST && config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA && config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP && config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_RESULT_UNKNOWN_ENUM_TYPE;
            delete buffer;
        }

        buffer->config_type = config_type;

        *external_collection_framebuffer = buffer;
        return MAGIK_RESULT_SUCCESS;
    }

    e_magik_result_types fetch_framebuffer_collection(bool is_running, e_magik_manager_display_types display_type, framebuffer_swapchain_t& framebuffer_swapchain, magik_framebuffer_collection_external_t external_collection_framebuffer, bool* is_new_fetch)
    {
        if(!external_collection_framebuffer)
        {
            *is_new_fetch = false;
            return MAGIK_RESULT_INVALID_POINTER;
        }

        if(!is_running)
        {
            *is_new_fetch = false;
            return MAGIK_RESULT_SUCCESS;
        }

        if(display_type == MAGIK_DISPLAY_HEADLESS)
        {
            *is_new_fetch = false;
            return MAGIK_RESULT_AOV_SWAPCHAIN_NOT_INITALIZED;
        }

        bool is_swapped = false;
        auto _r = try_swap_front_framebuffer(framebuffer_swapchain, &is_swapped);
        if(!is_swapped)
        {
            *is_new_fetch = false;
            return _r;
        }

        *is_new_fetch = true;
        return memcpy_front_framebuffer_to_external_framebuffer(framebuffer_swapchain, external_collection_framebuffer);
    }

    e_magik_result_types extract_config_host(bool is_running, magik_framebuffer_container_config_host_t* container, magik_framebuffer_collection_external_t external_collection_framebuffer, const char* name)
    {
        if(!container || !external_collection_framebuffer) return MAGIK_RESULT_INVALID_POINTER;

        if(!is_running)
        {
            return MAGIK_RESULT_SUCCESS;
        }

        if(external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST)
        {
            return MAGIK_RESULT_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = external_collection_framebuffer->collection.find(name);

        if(element == external_collection_framebuffer->collection.end())
        {
            return MAGIK_RESULT_SUCCESS;
        }

        container->x_resolution = element->second.x_resolution;
        container->y_resolution = element->second.y_resolution;
        container->channels = element->second.channels;
        container->size_of_data = element->second.config_host.host_size;
        container->h_data = element->second.config_host.h_data;

        return MAGIK_RESULT_SUCCESS;
    }

    e_magik_result_types extract_config_opengl_interop(bool is_running, magik_framebuffer_container_config_opengl_interop_t* container, magik_framebuffer_collection_external_t external_collection_framebuffer, const char* name)
    {
        if(!container || !external_collection_framebuffer) return MAGIK_RESULT_INVALID_POINTER;

        if(!is_running)
        {
            return MAGIK_RESULT_SUCCESS;
        }

        if(external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP)
        {
            return MAGIK_RESULT_AOV_INCORRECT_EXTRACT_CALL;
        }

        auto element = external_collection_framebuffer->collection.find(name);

        if(element == external_collection_framebuffer->collection.end())
        {
            return MAGIK_RESULT_SUCCESS;
        }

        container->x_resolution = element->second.x_resolution;
        container->y_resolution = element->second.y_resolution;
        container->channels = element->second.channels;
        container->gl_buffer_id = element->second.config_open_gl_interop.gl_buffer_id;
        container->cuda_resources = element->second.config_open_gl_interop.cuda_resource;

        return MAGIK_RESULT_SUCCESS;
    }

    e_magik_result_types destroy_external_framebuffer_collection(magik_framebuffer_collection_external_t external_collection_framebuffer)
    {
        if(!external_collection_framebuffer) return MAGIK_RESULT_SUCCESS;

        if( external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP && 
            external_collection_framebuffer->config_type != MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP)
        {
            return MAGIK_RESULT_UNKNOWN_ENUM_TYPE;
        }

        e_magik_result_types _r = MAGIK_RESULT_SUCCESS;

        for(auto& [key, value] : external_collection_framebuffer->collection)
        {
            switch(external_collection_framebuffer->config_type)
            {
                case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST:
                {
                    magik::free_host(value.config_host.h_data);
                    break;
                }

                case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA:
                {
                    magik::free_device(value.config_cuda.d_data);
                    break;
                }

                case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP:
                {
                    _r = magik::free_opengl_buffer(&value.config_open_gl_interop.gl_buffer_id, &value.config_open_gl_interop.cuda_resource);
                    break;
                }

                case MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP:
                {
                    break;
                }
            }
        }

        external_collection_framebuffer->collection.clear();

        delete external_collection_framebuffer;
        return _r;
    }

    // Internal
    static void realloc_framebuffer(framebuffer_collection_t& framebuffer_collection, uint32_t x_resolution_target, uint32_t y_resolution_target)
    {
        for(auto&[key, value] : framebuffer_collection.collection)
        {
            if((value.x_resolution != x_resolution_target) || (value.y_resolution != y_resolution_target))
            {
                check_cuda_errors(cudaFree(value.d_data));
                value.x_resolution = x_resolution_target;
                value.y_resolution = y_resolution_target;
                check_cuda_errors(cudaMalloc(reinterpret_cast<void**>(&value.d_data), static_cast<size_t>(value.x_resolution)*static_cast<size_t>(value.y_resolution)*static_cast<size_t>(value.channels)*sizeof(float)));
            }
        }
    }

    static void memcpy_render_to_back_framebuffer(framebuffer_swapchain_t& framebuffer_swapchain)
    {
        for(auto iter = framebuffer_swapchain.back_framebuffer->collection.begin(); iter != framebuffer_swapchain.back_framebuffer->collection.end();)
        {
            auto render_element = framebuffer_swapchain.render_framebuffer.collection.find(iter->first);

            if(render_element == framebuffer_swapchain.render_framebuffer.collection.end())
            {
                magik::free_device(iter->second.d_data);
                iter = framebuffer_swapchain.back_framebuffer->collection.erase(iter);
            }
            else
            {
                iter++;
            }
        }

        for(auto& [target_key, target_value] : framebuffer_swapchain.render_framebuffer.collection)
        {
            framebuffer_swapchain.back_framebuffer->collection.emplace(target_key, framebuffer_t());

            auto& back_element = framebuffer_swapchain.back_framebuffer->collection.find(target_key)->second;

            size_t size_of_target = static_cast<size_t>(target_value.x_resolution*target_value.y_resolution*target_value.channels)*sizeof(float);

            if((back_element.x_resolution != target_value.x_resolution) || (back_element.y_resolution != target_value.y_resolution) || (back_element.channels != target_value.channels) || !back_element.d_data)
            {
                magik::free_device(back_element.d_data);

                back_element.x_resolution = target_value.x_resolution;
                back_element.y_resolution = target_value.y_resolution;
                back_element.channels = target_value.channels;
                back_element.d_data = magik::allocate_device<float>(size_of_target);
            }

            check_cuda_errors(cudaMemcpy(back_element.d_data, target_value.d_data, size_of_target, cudaMemcpyDeviceToDevice));
        }
    }

    static void swap_back_framebuffer(framebuffer_swapchain_t& framebuffer_swapchain)
    {
        if(!framebuffer_swapchain.ready_framebuffer.load(std::memory_order_relaxed) || !framebuffer_swapchain.back_framebuffer) return;

        framebuffer_swapchain.back_framebuffer = framebuffer_swapchain.ready_framebuffer.exchange(framebuffer_swapchain.back_framebuffer, std::memory_order_acq_rel);
        framebuffer_swapchain.is_ready_framebuffer_updated.store(true, std::memory_order_release);
    }

    void update_framebuffer_swapchain(update_framebuffer_swapchain_t args)
    {
        if(args.update_policy != MAGIK_FRAMEBUFFER_UPDATE_POLICY_NONE)
        {
            realloc_framebuffer(args.framebuffer_swapchain.render_framebuffer, args.x_resolution_target, args.y_resolution_target);
        }

        MAGIK_ASSERT(args.framebuffer_swapchain.back_framebuffer != nullptr, "The back framebuffer collection cannot be null");

        realloc_framebuffer(*args.framebuffer_swapchain.back_framebuffer, args.x_resolution_target, args.y_resolution_target);

        memcpy_render_to_back_framebuffer(args.framebuffer_swapchain);

        swap_back_framebuffer(args.framebuffer_swapchain);

        args.update_policy = MAGIK_FRAMEBUFFER_UPDATE_POLICY_NONE;
    }

    void initialize_framebuffer_swapchain(framebuffer_swapchain_t& framebuffer_swapchain)
    {
        framebuffer_swapchain.front_framebuffer = &framebuffer_swapchain.framebuffer_collection[0];
        framebuffer_swapchain.ready_framebuffer.store(&framebuffer_swapchain.framebuffer_collection[1], std::memory_order_relaxed);
        framebuffer_swapchain.back_framebuffer = &framebuffer_swapchain.framebuffer_collection[2];
    }

    void release_framebuffer_swapchain(framebuffer_swapchain_t& framebuffer_swapchain)
    {
        for(uint32_t i = 0; i < 3; i++)
        {
            for(const auto& [key, ctx_value] : framebuffer_swapchain.framebuffer_collection[i].collection)
            {
                check_cuda_errors(cudaFree(ctx_value.d_data));
            }

            framebuffer_swapchain.framebuffer_collection[i].collection.clear();
        }

        for(const auto& [key, value] : framebuffer_swapchain.render_framebuffer.collection)
        {
            check_cuda_errors(cudaFree(value.d_data));
        }

        framebuffer_swapchain.render_framebuffer.collection.clear();
    }
}
