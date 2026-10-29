/*
* This file is no longer public and implements the core host-side API logic. 
*/

#include "magik.h"
#include "magik_error.h"
#include "renderer.h"

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

    if(!magik::opengl_init((void* (*)(const char*))loader))
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
    magik::printf_system_info();
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
* [SECTION] Memory
*/



/**
* [SECTION] Render manager
*/

MAGIK_API e_magik_result_types magik_render_manager_create(magik_render_manager_t* manager, magik_manager_descriptor_t descriptor)
{
    int32_t n_cuda_device = magik::get_cuda_device_count();

    if(descriptor.user_device_id >= n_cuda_device)
    {
        return MAGIK_INVALID_CUDA_DEVICE;
    }

    magik_render_manager* new_manager = new magik_render_manager();
    
    new_manager->cuda_device = descriptor.user_device_id;

    if(descriptor.user_stream == nullptr)
    {
        new_manager->owns_stream = true;
        magik::create_cuda_stream(&new_manager->cuda_stream);
    }
    else
    {
        new_manager->owns_stream = false;
        new_manager->cuda_stream = descriptor.user_stream;
    }

    new_manager->command_context.n_reserved_chunk = descriptor.cqs_n_reserved_chunk;
    new_manager->command_context.drop_overflows = descriptor.cqs_drop_overflow;

    new_manager->command_context.front = std::make_unique<magik::command_buffer_t>();
    new_manager->command_context.back = std::make_unique<magik::command_buffer_t>();

    new_manager->command_context.front->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);
    new_manager->command_context.back->data = std::make_unique<uint32_t[]>(descriptor.cqs_n_reserved_chunk);

    new_manager->user_host_mem_reserve_func = descriptor.host_reserve_func;
    new_manager->user_host_mem_commit_func = descriptor.host_commit_func;
    new_manager->user_host_mem_decommit_func = descriptor.host_decommit_func;
    new_manager->user_host_mem_release_func = descriptor.host_release_func;

    new_manager->worker_thread = std::thread(magik::run, new_manager);

    *manager = new_manager;
    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_render_manager_destroy(magik_render_manager_t manager)
{
    manager->is_running.store(false, std::memory_order_release);
    manager->worker_thread.join();

    if(manager->owns_stream)
    {
        magik::destroy_cuda_stream(&manager->cuda_stream);
    }

    delete manager;
    return MAGIK_SUCCESS;
}

MAGIK_API e_magik_result_types magik_render_manager_fetch_error(magik_render_manager_t manager)
{
    return manager->atomic_last_error_type.load(std::memory_order_acquire);
}



/**
* [SECTION] Renderer statistics
*/

MAGIK_API e_magik_result_types magik_fetch_renderer_statistics(magik_render_manager_t manager, magik_renderer_statistics_t* statistics)
{
    if(!manager || !statistics) return MAGIK_ERROR_INVALID_POINTER;

    statistics->sampled_time_point_seconds = manager->sampled_time_point_seconds.load(std::memory_order_relaxed);
    statistics->average_sample_time_seconds = manager->average_sample_time_seconds.load(std::memory_order_relaxed);
    statistics->latest_sample_time_seconds = manager->latest_sample_time_seconds.load(std::memory_order_relaxed);
    statistics->total_render_time_seconds = manager->total_render_time_seconds.load(std::memory_order_relaxed);

    return MAGIK_SUCCESS;
}



/**
* [SECTION] Framebuffer
*/

MAGIK_API e_magik_result_types magik_configure_framebuffer_collection(magik_framebuffer_collection_external_t* framebuffer, e_magik_framebuffer_collection_config_types config_type)
{
    return magik::configure_external_framebuffer_collection(framebuffer, config_type);
}

MAGIK_API e_magik_result_types magik_framebuffer_collection_fetch(magik_render_manager_t manager, bool* is_new_fetch, magik_framebuffer_collection_external_t framebuffer)
{
    return magik::fetch_framebuffer_collection(manager, framebuffer, is_new_fetch);
}

MAGIK_API e_magik_result_types magik_extract_config_host(magik_render_manager_t manager, magik_framebuffer_container_config_host_t* container, magik_framebuffer_collection_external_t framebuffer, const char* name)
{
    return magik::extract_config_host(manager, container, framebuffer, name);
}

MAGIK_API e_magik_result_types magik_extract_config_opengl_interop(magik_render_manager_t manager, magik_framebuffer_container_config_opengl_interop_t* container, magik_framebuffer_collection_external_t framebuffer, const char* name)
{
    return magik::extract_config_opengl_interop(manager, container, framebuffer, name);
}

MAGIK_API e_magik_result_types magik_destroy_framebuffer_collection(magik_framebuffer_collection_external_t framebuffer)
{
    return magik::destroy_external_framebuffer_collection(framebuffer);
}



/**
* [SECTION] Command Queue System
*/

MAGIK_API e_magik_result_types magik_cqs_push_command(magik_render_manager_t manager, const void* command)
{
    return magik::push_command(manager, command);
}

MAGIK_API e_magik_result_types magik_cqs_dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
{
    return magik::dispatch_command_buffer(manager, is_dispatched);
}
