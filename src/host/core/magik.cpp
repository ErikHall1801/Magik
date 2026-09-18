/*
* This file is no longer public and implements the core host-side API logic. 
*/

#include "magik.h"
#include "magik_error.h"
#include "magik_bridge.h"
#include "magik_render_manager.h"
#include "magik_arbitrary_output_variables.h"
#include "magik_command_queue_system.h"
#include "magik_worker.h"
#include "magik_host_memory.h"



/**
* [SECTION] Error handling & result types
*/

MAGIK_API void magik_set_error_callback(magik_error_callback callback, void* user_data)
{
    magik::error::set_error_callback_internal(callback, user_data);
}

MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line)
{
    magik::error::check_error_internal(result, func, file, line);
}


/**
* [SECTION] Interop initialization
*/

MAGIK_API e_magik_result_types magik_gl_init(magik_gl_loader_proc loader)
{
    if(!loader)
    {
        return MAGIK_ERROR_INVALID_POINTER;
    }

    if(!magik::bridge::host_gl_init((void* (*)(const char*))loader))
    {
        return MAGIK_ERROR_GL_LOADER_FAILED;
    }

    return MAGIK_SUCCESS;
}



/**
* [SECTION] Info
*/

MAGIK_API void magik_get_system_Info()
{
    magik::bridge::host_get_system_info();
}



/**
* [SECTION] Tests
*/



/**
* [SECTION] Version checking
*/

MAGIK_API e_magik_result_types magik_get_version(uint32_t* major, uint32_t* minor, uint32_t* revision, const char** as_char)
{
    if(major) *major = MAGIK_VERSION_MAJOR;
    if(minor) *minor = MAGIK_VERSION_MINOR;
    if(revision) *revision = MAGIK_VERSION_REVISION;
    if(as_char) 
    {
        static char buffer[256];
        snprintf(buffer, sizeof(buffer), "Magik ! %u.%u.%u - %s", 
                MAGIK_VERSION_MAJOR, MAGIK_VERSION_MINOR, MAGIK_VERSION_REVISION, MAGIK_VERSION_NAME);
        *as_char = buffer;
    }

    return MAGIK_SUCCESS;
}



/**
* [SECTION] Frame time
*/

MAGIK_API e_magik_result_types magik_fetch_frame_time(double* ft)
{
    if(!ft) return MAGIK_ERROR_INVALID_POINTER;

    *ft = frame_time.load(std::memory_order_relaxed);

    return MAGIK_SUCCESS;
}



/**
* [SECTION] Memory
*/



/**
* [SECTION] Render manager
*/

MAGIK_API e_magik_result_types magik_create_render_manager(magik_render_manager_t* manager, magik_manager_descriptor_t descriptor)
{
    int32_t n_cuda_device = magik::bridge::host_get_n_cuda_device();

    if(descriptor.user_device_id >= n_cuda_device)
    {
        return MAGIK_INVALID_CUDA_DEVICE;
    }

    magik_render_manager* new_manager = new magik_render_manager();
    
    new_manager->cuda_device = descriptor.user_device_id;

    if(descriptor.user_stream == nullptr)
    {
        new_manager->owns_stream = true;
        magik::bridge::host_create_cuda_stream(&new_manager->cuda_stream);
    }
    else
    {
        new_manager->owns_stream = false;
        new_manager->cuda_stream = descriptor.user_stream;
    }

    new_manager->cqs_context.n_reserved_chunk = descriptor.cqs_n_reserved_chunk;
    new_manager->cqs_context.drop_overflows = descriptor.cqs_drop_overflow;

    try
    {
        new_manager->cqs_context.front = std::make_unique<magik::cqs::buffer_object>();
        new_manager->cqs_context.back = std::make_unique<magik::cqs::buffer_object>();

        new_manager->cqs_context.front->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);
        new_manager->cqs_context.back->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);
    }
    catch(const std::bad_alloc)
    {
        delete new_manager;
        return MAGIK_ERROR_COMMAND_BUFFER_ALLOCATION_FAILED;
    }

    new_manager->user_host_mem_reserve_func = descriptor.host_reserve_func;
    new_manager->user_host_mem_commit_func = descriptor.host_commit_func;
    new_manager->user_host_mem_decommit_func = descriptor.host_decommit_func;
    new_manager->user_host_mem_release_func = descriptor.host_release_func;

    new_manager->worker_thread = std::thread(magik::worker::run, new_manager);

    *manager = new_manager;
    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_destroy_render_manager(magik_render_manager_t manager)
{
    manager->is_running.store(false, std::memory_order_release);
    manager->worker_thread.join();

    if(manager->owns_stream)
    {
        magik::bridge::host_destroy_cuda_stream(&manager->cuda_stream);
    }

    delete manager;
    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_fetch_memory_usage(magik_render_manager_t manager, uint64_t* size_reserve, uint64_t* size_commit, e_magik_memory_types type)
{
    if(!manager || !size_reserve || !size_commit) return MAGIK_ERROR_INVALID_POINTER;

    if(!manager->is_running.load(std::memory_order_acquire))
    {
        *size_reserve = 0;
        *size_commit = 0;
        return MAGIK_SUCCESS;
    }

    switch(type)
    {
        case MAGIK_MEMORY_HOST:
        {
            *size_reserve = host_mem_reserve.load(std::memory_order_acquire);
            *size_commit = host_mem_commit.load(std::memory_order_acquire);
            break;
        }

        case MAGIK_MEMORY_DEVICE:
        {
            break;
        }

        case MAGIK_MEMORY_UNIFIED:
        {
            break;
        }

        default:
        {
            return MAGIK_UNKNOWN_ENUM_TYPE;
        }
    }

    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_fetch_manager_error(magik_render_manager_t manager)
{
    return manager->atomic_last_error_type.load(std::memory_order_acquire);
}



/**
* [SECTION] Arbitrary Output Variables
*/

MAGIK_API e_magik_result_types magik_configure_aov_framebuffer(magik_aov_framebuffer_object_external_t* framebuffer, e_magik_aov_config_types config_type)
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

MAGIK_API e_magik_result_types magik_aov_fetch(magik_render_manager_t manager, bool* is_new_fetch, magik_aov_framebuffer_object_external_t dcc_buffer)
{
    if(!manager || !dcc_buffer)
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
    return magik::aov::memcpy_front_framebuffer_to_dcc_framebuffer(&manager->aov_context, dcc_buffer);
}

MAGIK_API e_magik_result_types magik_aov_config_host_extract(magik_render_manager_t manager, magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t dcc_buffer, const char* name)
{
    if(!manager || !container || !dcc_buffer) return MAGIK_ERROR_INVALID_POINTER;

    if(!manager->is_running.load(std::memory_order_acquire))
    {
        return MAGIK_SUCCESS;
    }

    if(dcc_buffer->config_type != MAGIK_AOV_CONFIG_HOST)
    {
        return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
    }

    auto element = dcc_buffer->collection.find(name);

    if(element == dcc_buffer->collection.end())
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

MAGIK_API e_magik_result_types magik_aov_config_opengl_interop_extract(magik_render_manager_t manager, magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t dcc_buffer, const char* name)
{
    if(!manager || !container || !dcc_buffer) return MAGIK_ERROR_INVALID_POINTER;

    if(!manager->is_running.load(std::memory_order_acquire))
    {
        return MAGIK_SUCCESS;
    }

    if(dcc_buffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP)
    {
        return MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL;
    }

    auto element = dcc_buffer->collection.find(name);

    if(element == dcc_buffer->collection.end())
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

MAGIK_API e_magik_result_types magik_aov_destroy(magik_aov_framebuffer_object_external_t dcc_buffer)
{
    if(!dcc_buffer) return MAGIK_SUCCESS;

    if(dcc_buffer->config_type != MAGIK_AOV_CONFIG_HOST && dcc_buffer->config_type != MAGIK_AOV_CONFIG_CUDA && dcc_buffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && dcc_buffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
    {
        return MAGIK_UNKNOWN_ENUM_TYPE;
    }

    e_magik_result_types _r = MAGIK_SUCCESS;

    for(auto& [key, value] : dcc_buffer->collection)
    {
        switch(dcc_buffer->config_type)
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

    dcc_buffer->collection.clear();

    delete dcc_buffer;
    return _r;
}



/**
* [SECTION] Command Queue System
*/

MAGIK_API e_magik_result_types magik_cqs_push_command(magik_render_manager_t manager, const void* command)
{
    if(!manager || !command) return MAGIK_ERROR_INVALID_POINTER;

    if(reinterpret_cast<uintptr_t>(command) % sizeof(uint32_t) != 0) return MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED;

    e_magik_cqs_command_types command_type;
    memcpy(&command_type, command, sizeof(e_magik_cqs_command_types)); 
    
    bool is_valid = false;
    size_t command_size = 0;
    magik::cqs::fetch_command_info(command_type, &is_valid, &command_size);

    if(!is_valid) return MAGIK_ERROR_INVALID_COMMAND;

    if(command_size % sizeof(uint32_t) != 0) return MAGIK_ERROR_COMMAND_SIZE_NOT_A_MULTIPLE_OF_4;

    size_t command_buffer_occupancy = (size_t)(manager->cqs_context.front->n_occupied_chunk)*sizeof(uint32_t);
    size_t command_buffer_capacity = (size_t)(manager->cqs_context.n_reserved_chunk)*sizeof(uint32_t);

    if((command_buffer_occupancy+command_size) > command_buffer_capacity)
    {
        if(manager->cqs_context.drop_overflows)
        {
            return MAGIK_SUCCESS;
        }
        else
        {
            return MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW;
        }
    }

    uint32_t* head_ptr = manager->cqs_context.front->data.get() + manager->cqs_context.front->n_occupied_chunk;
    memcpy(head_ptr, command, command_size);
    manager->cqs_context.front->n_occupied_chunk += static_cast<uint32_t>(command_size / sizeof(uint32_t));

    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_cqs_dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
{
    if(!manager) 
    {
        *is_dispatched = false;
        return MAGIK_ERROR_INVALID_POINTER;
    }

    if(manager->cqs_context.is_swap_ready.load(std::memory_order_acquire))
    {
        manager->cqs_context.front.swap(manager->cqs_context.back);
        manager->cqs_context.is_swap_ready.store(false, std::memory_order_release);

        *is_dispatched = true;
        return MAGIK_SUCCESS;
    }
    else
    {
        *is_dispatched = false;
        return MAGIK_SUCCESS;
    }
}
