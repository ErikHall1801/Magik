/*
* This file is no longer public and implements the core host-side API logic. 
*/

#pragma once

#include "magik.h"
#include "magik_error.h"
#include "magik_bridge.h"
#include "magik_render_manager.h"
#include "magik_arbitrary_output_variables.h"
#include "magik_command_queue_system.h"
#include "magik_worker.h"
#include <iostream>



/**
* [SECTION] Error handling & result types
*/

MAGIK_API void magik_set_error_callback(magik_error_callback callback, void* user_data)
{
    magik::error::set_error_callback_internal(callback, user_data);
}

MAGIK_API e_magik_result_types magik_get_last_error(void)
{
    return magik::error::get_last_error_internal();
}

MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line)
{
    magik::error::check_error_internal(result, func, file, line);
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

    g_last_error = MAGIK_SUCCESS;
    return MAGIK_SUCCESS;
}



/**
* [SECTION] Render manager
*/

MAGIK_API magik_render_manager_t magik_create_render_manager(uint32_t cuda_device)
{
    magik_render_manager* manager = new magik_render_manager();
    manager->cuda_device = cuda_device;

    manager->worker_thread = std::thread(magik::worker::run, manager);

    g_last_error = MAGIK_SUCCESS;
    return manager;
}

MAGIK_API e_magik_result_types magik_destroy_render_manager(magik_render_manager_t manager)
{
    manager->is_running.store(false, std::memory_order_release);
    manager->worker_thread.join();
    delete manager;

    set_error(MAGIK_SUCCESS);
}



/**
* [SECTION] Arbitrary Output Variables
*/

MAGIK_API magik_aov_framebuffer_object_external_t magik_configure_aov_framebuffer(e_magik_aov_config_types config_type)
{
    magik_aov_framebuffer_object_external* buffer = new magik_aov_framebuffer_object_external();
    
    if(config_type != MAGIK_AOV_CONFIG_HOST && config_type != MAGIK_AOV_CONFIG_CUDA && config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
    {
        g_last_error = MAGIK_UNKNOWN_ENUM_TYPE;
        delete buffer;
        return nullptr;
    }

    buffer->x_resolution = 0;
    buffer->y_resolution = 0;

    buffer->config_type = config_type;

    switch(config_type)
    {
        case MAGIK_AOV_CONFIG_HOST:
        {
            buffer->data.config_host.h_albedo = nullptr;
            buffer->data.config_host.host_size = 0;
            break;
        }

        case MAGIK_AOV_CONFIG_CUDA:
        {
            buffer->data.config_cuda.d_albedo = nullptr;
            buffer->data.config_cuda.device_size = 0;
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

    g_last_error = MAGIK_SUCCESS;
    return buffer;
}

MAGIK_API bool magik_aov_fetch(magik_render_manager_t manager, magik_aov_framebuffer_object_external_t dcc_buffer)
{
    if(!manager || !dcc_buffer)
    {
        g_last_error = MAGIK_ERROR_INVALID_POINTER;
        return false;
    }

    if(!magik::aov::try_swap_front_framebuffer(&manager->aov_context))
    {
        check_magik_errors(magik_get_last_error());
        g_last_error = MAGIK_SUCCESS;
        return false;
    }

    check_magik_errors(magik::aov::memcpy_front_framebuffer_to_dcc_framebuffer(&manager->aov_context, dcc_buffer));

    g_last_error = MAGIK_SUCCESS;
    return true;
}

MAGIK_API e_magik_result_types magik_aov_config_host_extract(magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t dcc_buffer)
{
    if(!container || !dcc_buffer || !dcc_buffer->data.config_host.h_albedo) set_error(MAGIK_ERROR_INVALID_POINTER);

    container->h_albedo = dcc_buffer->data.config_host.h_albedo;
    container->size_of_albedo = dcc_buffer->data.config_host.host_size;
    container->x_resolution = dcc_buffer->x_resolution;
    container->y_resolution = dcc_buffer->y_resolution;

    set_error(MAGIK_SUCCESS);
}

MAGIK_API e_magik_result_types magik_aov_resize(magik_render_manager_t manager, uint32_t x_resolution, uint32_t y_resolution)
{
    manager->aov_context.x_resolution = x_resolution;
    manager->aov_context.y_resolution = y_resolution;
    set_error(MAGIK_SUCCESS);
}

MAGIK_API e_magik_result_types magik_aov_destroy(magik_aov_framebuffer_object_external_t dcc_buffer)
{
    if(!dcc_buffer) set_error(MAGIK_SUCCESS);

    if(dcc_buffer->config_type != MAGIK_AOV_CONFIG_HOST && dcc_buffer->config_type != MAGIK_AOV_CONFIG_CUDA && dcc_buffer->config_type != MAGIK_AOV_CONFIG_OPENGL_INTEROP && dcc_buffer->config_type != MAGIK_AOV_CONFIG_VULKAN_INTEROP)
    {
        set_error(MAGIK_UNKNOWN_ENUM_TYPE);
    }

    switch(dcc_buffer->config_type)
    {
        case MAGIK_AOV_CONFIG_HOST:
        {
            magik::bridge::host_destroy_host_memory(dcc_buffer->data.config_host.h_albedo);
            break;
        }

        case MAGIK_AOV_CONFIG_CUDA:
        {
            magik::bridge::host_destroy_device_memory(dcc_buffer->data.config_cuda.d_albedo);
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

    delete dcc_buffer;
    set_error(MAGIK_SUCCESS);
}



/**
* [SECTION] Command Queue System
*/

