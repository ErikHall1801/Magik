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

MAGIK_API e_magik_result_types magik_render_manager_create(magik_render_manager_t* manager, magik_manager_descriptor_t descriptor)
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

    new_manager->cqs_context.front = std::make_unique<magik::cqs::buffer_object>();
    new_manager->cqs_context.back = std::make_unique<magik::cqs::buffer_object>();

    new_manager->cqs_context.front->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);
    new_manager->cqs_context.back->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);

    new_manager->user_host_mem_reserve_func = descriptor.host_reserve_func;
    new_manager->user_host_mem_commit_func = descriptor.host_commit_func;
    new_manager->user_host_mem_decommit_func = descriptor.host_decommit_func;
    new_manager->user_host_mem_release_func = descriptor.host_release_func;

    new_manager->worker_thread = std::thread(magik::worker::run, new_manager);

    *manager = new_manager;
    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_render_manager_destroy(magik_render_manager_t manager)
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

MAGIK_API e_magik_result_types magik_render_manager_fetch_error(magik_render_manager_t manager)
{
    return manager->atomic_last_error_type.load(std::memory_order_acquire);
}



/**
* [SECTION] Arbitrary Output Variables
*/

MAGIK_API e_magik_result_types magik_aov_configure_framebuffer_object(magik_aov_framebuffer_object_external_t* framebuffer_object, e_magik_aov_config_types config_type)
{
    return magik::aov::configure_framebuffer_object(framebuffer_object, config_type);
}

MAGIK_API e_magik_result_types magik_aov_fetch(magik_render_manager_t manager, bool* is_new_fetch, magik_aov_framebuffer_object_external_t framebuffer_object)
{
    return magik::aov::fetch(manager, is_new_fetch, framebuffer_object);
}

MAGIK_API e_magik_result_types magik_aov_extract_config_host(magik_render_manager_t manager, magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t framebuffer_object, const char* name)
{
    return magik::aov::extract_config_host(manager, container, framebuffer_object, name);
}

MAGIK_API e_magik_result_types magik_aov_extract_config_opengl_interop(magik_render_manager_t manager, magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t framebuffer_object, const char* name)
{
    return magik::aov::extract_config_opengl_interop(manager, container, framebuffer_object, name);
}

MAGIK_API e_magik_result_types magik_aov_destroy_framebuffer_object(magik_aov_framebuffer_object_external_t framebuffer_object)
{
    return magik::aov::destroy_framebuffer_object(framebuffer_object);
}



/**
* [SECTION] Command Queue System
*/

MAGIK_API e_magik_result_types magik_cqs_push_command(magik_render_manager_t manager, const void* command)
{
    return magik::cqs::push_command(manager, command);
}

MAGIK_API e_magik_result_types magik_cqs_dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
{
    return magik::cqs::dispatch_command_buffer(manager, is_dispatched);
}
