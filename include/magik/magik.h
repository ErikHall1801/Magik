/*
* This is the APIs public header. It uses opaque structs to hide the 
* actual implementation logic. 
* The core rule of this file is to keep everything opaque and C-style. 
*/ 

#ifndef MAGIK_H
#define MAGIK_H

#include <stdint.h>
#include "magik_error_types.h"

#if defined(_WIN32)
    #if defined(MAGIK_BUILD_DLL)
        #define MAGIK_API __declspec(dllexport)
    #else
        #define MAGIK_API __declspec(dllimport)
    #endif
#elif defined(__GNUC__) || defined(__clang__)
    #define MAGIK_API __attribute__((visibility("default")))
#else
    #define MAGIK_API
#endif

#ifdef __cplusplus
extern "C" {
#endif



/**
* [SECTION] Version
*/
#define MAGIK_VERSION_NAME "Rhapsody"
#define MAGIK_VERSION_MAJOR 0
#define MAGIK_VERSION_MINOR 1
#define MAGIK_VERSION_REVISION 0



/**
* [SECTION] Error handling & result types
*/

/**
* @brief Catches Magik errors and provides debug information
* 
* @param [in] val Magik API function which returns the e_magik_result_types type
* @warning If the return type is not MAGIK_SUCCESS this macro either prints out general debug information or calls 
           a user-defined callback. The callback uses the magik_error_callback signature and has to be set using 
           magik_set_error_callback. It is highly adviced to define a callback which handles errors, as many of 
           them, such as MAGIK_ERROR_HOST_OUT_OF_MEMORY will cause a crash sooner rather than later if left to their 
           own devices. The default behaivor does not cause the application to crash. 
*/
#define check_magik_error(val) check_magik( (val), #val, __FILE__, __LINE__);

/**
* @brief Typedef for error callbacks
* 
* @param [in] result The result of a Magik function which returns e_magik_result_types. It is recommended to use 
                     the macro check_magik_error to automatically fill the next arguments
* @param [in] func The function in which the error was first caught, not the one in which it necessarily happened. 
* @param [in] file The file in which the function that caugth the error was located in.
* @param [in] line The line where the error was caught.
* @param [in] user_data A void pointer to user data used by the callback. 
*/
typedef void (*magik_error_callback)(e_magik_result_types result, const char* func, const char* file, int line, void* user_data);

/**
* @brief Sets a callback function and user data to be used in the event of an error
* 
* @param [in] callback A function of a defined signature 
* @param [in] user_data A void pointer to user data. 
* 
* @warning Only one callback and user data pointer can be set at a time !
*/
MAGIK_API void magik_set_error_callback(magik_error_callback callback, void* user_data);

/**
* @brief Gets the last magik error. This is useful in circumstances where a Magik function call is wrapped inside
         another function which may not be able to return the error. You can nest this function inside the 
         check_magik_error macro to get the usual behavior. 
*
* @return Last error
* 
* @warning While the function is thread safe it can only return the last error and is not intrinsically aware to 
           distinguish where an error happen. The error log will use the location check_magik_error ! 
*/
MAGIK_API e_magik_result_types magik_get_last_error(void);

/**
* 
*/
MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line); 



/**
* [SECTION] Tests
*/

/**
* @brief Example of an opaque pointer & struct. More specifically, this defines an opaque alias to a 
         pointer of an internal struct. Where magik_rgba_test_frame_buffer is internal and 
         magik_rgba_test_frame_buffer_t is the alias. 
*/
typedef struct magik_test_rgba_frame_buffer* magik_test_rgba_frame_buffer_t;

/**
* @brief Two test-kernel patterns are available. The UV gradient should appear with the black corner, R = G = B = 0, 
         at the lower left side of your window. The mandelbrot is intended to test resource allocation performance. 
*/
enum e_magik_test_kernel_pattern_types
{
    uv_gradient = 0,
    mandelbrot = 1
};

/**
* @brief Allocate width x height x 4 (RGBA) host frame buffer
*
* @param [out] buffer Pointer to the handle which recieves the data pointer and tracks the state.
* @param [in] width The width of the frame buffer in pixels.
* @param [in] height The height of the frame buffer in pixels.
* 
* @return e_magik_result_types MAGIK_SUCCESS on successful allocation, MAGIK_ERROR_HOST_MEMORY_ALLOCATION_FAILED when 
          the system failed to allocated memory
*
* @warning The caller is responsible for freeing the allocated buffer by passing it into magik_host_destroy_rgba_test
*/
MAGIK_API magik_test_rgba_frame_buffer_t magik_test_allocate_dcc_rgba_frame_buffer(uint32_t width, uint32_t height);

/**
* @brief Destroys previously allocated RGBA buffer
* 
* @param [out] result MAGIK_SUCCESS if the destruction was successful. Freeing null data is safe. 
* @param [in] buffer magik_rgba_test_frame_buffer struct
*/
MAGIK_API e_magik_result_types magik_test_destroy_dcc_rgba_frame_buffer(magik_test_rgba_frame_buffer_t buffer);

/** 
* @brief Transfers the API internal device frame buffer to the DCC buffer by invoking memcpy.
*
* @param [out] data A plain float pointer.
* @param [in] buffer magik_rgba_test_frame_buffer struct which has to have been allocated by calling 
                     magik_test_allocate_host_rgba_frame_buffer before ! 
* 
* @return MAGIK_SUCCESS on successful transfer. MAGIK_INVALID_POINTER if the buffer or data members are null. 
* 
* @warning Do not free the pointer fetched by this function manually !
*/
MAGIK_API e_magik_result_types magik_test_fetch_rgba_frame_buffer_data(float** data, magik_test_rgba_frame_buffer_t buffer);

/**
* @brief A minimum-setup kernel initially designed for us to validate the APIs behaivor. We decided to keep this logic 
         if other coders wish to test a simple kernel with a display output before setting up Magiks command queue 
         system and initialization logic.
* 
* @param [in] buffer magik_rgba_test_frame_buffer struct
* @param [in] pattern_type Either "uv_gradient" or "mandelbrot"
* 
* @return MAGIK_SUCCESS on successful execution. MAGIK_INVALID_POINTER if the buffer has not been allocated, 
          MAGIK_UNKNOWN_ENUM_TYPE if the pattern_type is not valid. 
* 
* @warning This kernel runs, and blocks, the main thread until the execution has finished ! 
*/
MAGIK_API e_magik_result_types magik_test_kernel(magik_test_rgba_frame_buffer_t buffer, e_magik_test_kernel_pattern_types pattern_type);



/**
* [SECTION] Version checking
*/

/**
* @brief Fetches API version
* 
* @param [out] major major version number
* @param [out] minor minor version number
* @param [out] revision revision number
* @param [out] as_char Formated char of the version number and codename, MAJOR.MINOR.REVISION - Codename, for example "Magik ! 0.1.0 - Rhapsody" 
* 
* @return MAGIK_SUCCESS
*/
MAGIK_API e_magik_result_types magik_get_version(uint32_t* major, uint32_t* minor, uint32_t* revision, const char** as_char);



#ifdef __cplusplus
}
#endif

#endif
