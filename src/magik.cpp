#include "magik.h"

#include <iostream>


/**
* [SECTION] Result types
*/

static magik_error_callback g_error_callback = nullptr;

static void* g_error_user_data = nullptr;

static thread_local e_magik_result_types g_last_error = MAGIK_SUCCESS;

MAGIK_API void magik_set_error_callback(magik_error_callback callback, void* user_data)
{
    g_error_callback = callback;
    g_error_user_data = user_data;
}

MAGIK_API e_magik_result_types magik_get_last_error(void)
{
    return g_last_error;
}

MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line)
{
    if(result != MAGIK_SUCCESS)
    {
        g_last_error = result;

        if(g_error_callback)
        {
            g_error_callback(result, func, file, line, g_error_user_data);
        }
        else
        {
            printf("Magik error = %u at %s:%d '%s'\n", static_cast<unsigned int>(result), file, line, func);
        }
    }
}



/**
* [SECTION] Tests
*/

struct magik_rgba_test_frame_buffer_t
{
    uint32_t x_res = 0;
    uint32_t y_res = 0;
    float* data = nullptr;
};

MAGIK_API e_magik_result_types magik_allocate_host_rgba_test(magik_rgba_test_frame_buffer* buffer, uint32_t width, uint32_t height)
{
    try // Memory allocation can fail !
    {
        *buffer = new magik_rgba_test_frame_buffer_t();
        (*buffer)->x_res = width;
        (*buffer)->y_res = height;
        // Yk, CUDA host alloc once that is there

        return MAGIK_SUCCESS;
    }
    catch(...)
    {
        return MAGIK_ERROR_HOST_OUT_OF_MEMORY;
    }
}

MAGIK_API e_magik_result_types magik_destroy_host_rgba_test(magik_rgba_test_frame_buffer buffer)
{
    // Yk, CUDA Free 

    if(buffer != nullptr)
    {
        delete buffer;
    }

    return MAGIK_SUCCESS;
}



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
