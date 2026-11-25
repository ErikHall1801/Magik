#ifndef MAGIK_H
#define MAGIK_H

#include <stdint.h>
#include <cstddef>

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
#define MAGIK_VERSION_NAME "Rhapsody"   // Codename
#define MAGIK_VERSION_MAJOR 0           // New features (In our case before the API switch)
#define MAGIK_VERSION_MINOR 7           // Small changes / additions
#define MAGIK_VERSION_REVISION 0        // Bug fix release



/**
* [SECTION] Error handling & result types
*/
typedef enum e_magik_result_severity_types
{
    MAGIK_RESULT_SEVERITY_NONE = 0, // Command was applied
    MAGIK_RESULT_SEVERITY_WARNING = 1, // Command was applied but changed for safety
    MAGIK_RESULT_SEVERITY_REJECTED = 2, // Command was not applied because the er
    MAGIK_RESULT_SEVERITY_FATAL = 3 // Command has caused an error
} e_magik_result_severity_types;

typedef enum e_magik_manager_status_types
{
    MAGIK_STATUS_0 = 0, // Nominal - Internally, everything is fine
    MAGIK_STATUS_1 = 1, // Suspended - Such as bad allocs 
    MAGIK_STATUS_2 = 2, // Rebuild - Such as the CUDA device being dropped
} e_magik_manager_status_types;

typedef enum e_magik_result_types // Rename to MAGIK_RESULT_ We also need to cull these down. 
{
    MAGIK_SUCCESS = 0, // The operation was successful

    // API specific 100 - 199
    MAGIK_ERROR_NOT_RUNNING = 1, // A runtime function was called before the Magik thread was running. This can happen by out-of-order initalization 
    MAGIK_ERROR_INVALID_POINTER = 2,
    MAGIK_UNKNOWN_ENUM_TYPE = 3, 
    MAGIK_INVALID_CUDA_DEVICE = 4,

    // Host 200 - 299
    MAGIK_ERROR_HOST_OUT_OF_MEMORY = 100,
    MAGIK_ERROR_HOST_MEMORY_ALLOCATION_FAILED = 101,
    MAGIK_ERROR_HOST_TRACE_ALLOCATED_STEPS_AND_CAPACITY_MISMATCH = 102,

    // Device 300 - 399
    MAGIK_ERROR_DEVICE_OUT_OF_MEMORY = 200,
    MAGIK_ERROR_DEVICE_ALLOCATION_FAILED = 201,

    // Command queue system 400 - 499
    MAGIK_ERROR_INVALID_ID = 400, // Happens when the id provided to a function related to the command queue system is not valid, i.e 0 or uninitialized
    MAGIK_ERROR_PROVIDED_ID_NOT_FOUND = 401, // Happens when the id provided to a function used command queue system has not been found, for example if the asset was not added. 
    MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW = 402,
    MAGIK_ERROR_INVALID_COMMAND = 403,
    MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED = 404,
    MAGIK_ERROR_COMMAND_DROPPED = 405,
    MAGIK_ERROR_COMMAND_BUFFER_ALLOCATION_FAILED = 406,
    MAGIK_ERROR_COMMAND_SIZE_NOT_A_MULTIPLE_OF_4 = 407,
    MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ = 408,
    MAGIK_ERROR_COMMAND_SIZE_MISMATCH = 409,

    // General rendering 500 - 599
    MAGIK_ERROR_NEGATIVE_WAVELENGTH = 500,
    MAGIK_ERROR_NEGATIVE_MONTE_CARLO_WEIGHT = 501,
    MAGIK_ERROR_REFLECTANCE_GREATER_THAN_ONE = 502,
    MAGIK_ERROR_REFLECTANCE_LESS_THAN_ZERO = 503,
    MAGIK_ERROR_POSITION_INSIDE_CONDUCTOR = 504,
    MAGIK_ERROR_NEGATIVE_VOLUME_COEFFICIENT = 505,

    // General relativity 700 - 799
    MAGIK_ERROR_VELOCITY_GREATER_THAN_SPEED_OF_LIGHT = 700,
    MAGIK_ERROR_POSITION_INSIDE_EVENT_HORIZON = 701,
    MAGIK_ERROR_NEGATIVE_DOPPLER_FACTOR = 702,
    MAGIK_ERROR_NEGATIVE_TIME_COORDINATE = 703,
    MAGIK_ERROR_POSITIVE_NORM_TIMELIKE_FOUR_VECTOR = 704,
    MAGIK_ERROR_INCORRECT_PHOTON_NORM_FOUR_VECTOR = 705,
    MAGIK_ERROR_INCORRECT_PARTICLE_NORM_FOUR_VECTOR = 706,
    MAGIK_ERROR_UNKNOWN_METRIC = 707,
    MAGIK_ERROR_ABSOLUTE_TOLERANCE_LESS_THAN_ZERO = 708,
    MAGIK_ERROR_RELATIVE_TOLERANCE_LESS_THAN_ZERO = 709,
    MAGIK_ERROR_INSUFFICIENT_SUBSTEPS = 710,
    MAGIK_ERROR_INVALID_PROPER_LOCAL_VELOCITY = 711,
    MAGIK_ERROR_INVALID_CELESTIAL_SPHERE_RADIUS = 712,
    MAGIK_ERROR_INVALID_HORIZON_SCALAR = 713,
    MAGIK_ERROR_INVALID_METRIC_PARAMETER = 714,
    MAGIK_ERROR_INVALID_OBSERVER_POSITION = 715,
    MAGIK_ERROR_INVALID_OBSERVER_ORIENTATION = 716,

    // Lens simulation 800 - 899
    MAGIK_ERROR_LENSLETS_OUT_OF_ORDER = 801,
    MAGIK_ERROR_NO_FRONT_LENSLET_ID = 802,
    MAGIK_ERROR_LENSLET_CYLINDER_LARGER_THAN_SURFACE_RADIUS = 803,
    MAGIK_ERROR_NO_REFERENCE_TO_SPECIFIED_SPECTRAL_DATA = 804,

    // Arbitrary Output Variables 900 - 999
    MAGIK_ERROR_AOV_INCORRECT_EXTRACT_CALL = 900,
    MAGIK_ERROR_AOV_ALLOCATED_BEFORE_INITIALIZATION = 901,
    MAGIK_ERROR_AOV_SWAPCHAIN_NOT_INITALIZED = 902,

    // Interops 1000 - 1099
    MAGIK_ERROR_GL_LOADER_FAILED = 1000, // 
    MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED = 1001, // Did you call magik_gl_init ?
    MAGIK_ERROR_GL_BUFFER_SIZE_MISMATCH = 1002,

    // Color 1100 - 1199
    MAGIK_ERROR_UNKNOWN_COLOR_MATCHING_FUNCTION = 1100,
    MAGIK_ERROR_INVALID_BIN_COUNT = 1101,

    // General 10000 - 10099
    MAGIK_ERROR_UNKNOWN = 10000,
    MAGIK_ERROR_INVALID_VALUE_RANGE = 10001,

    // Prohibited
    MAGIK_PROHIBITED_FORCE_SIZE = 0x7FFFFFFF // Internal use only. Forces the C compiler to use uint32_t
} e_magik_result_types;

/**
* @brief Catches Magik errors and provides debug information
* 
* @param [in] val Magik API function which returns the e_magik_result_types type
* @warning If the return type is not MAGIK_SUCCESS this macro either prints out general debug information or calls a user-defined 
* callback. The callback uses the magik_error_callback signature and has to be set using magik_set_error_callback. It is highly 
* adviced to define a callback which handles errors, as many of them, such as MAGIK_ERROR_HOST_OUT_OF_MEMORY will cause a crash 
* sooner rather than later if left to their own devices. The default behaivor does not cause the application to crash. 
*/
#define check_magik_errors(val) check_magik( (val), #val, __FILE__, __LINE__)

/**
* @brief Typedef for error callbacks
* 
* @param [in] result The result of a Magik function which returns e_magik_result_types. It is recommended to use the macro 
* check_magik_error to automatically fill the next arguments
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
* @brief This is the default error checking function which the macro "check_magik_errors" uses. 
* 
* @param [in] result The result of a function which returns e_magik_result_types. In case an API function does not return this type,
* you can instead use magik_get_last_error() as the input. All Magik functions record the last error.
* @param [in] func The name of the function which caused the error. 
* @param [in] file The file the function which caused the error was located in. You can use the "__FILE__" macro here. 
* @param [in] line The line in which the error occured. You can use the "__LINE__" macro here. 
* 
* @warning This function does not interfer with the programs operation. It only prints that an error has occured. It is strongly 
* recommended to set a error callback using magik_set_error_callback()
*/
MAGIK_API void check_magik(e_magik_result_types result, char const* func, const char* const file, int const line); 



/**
* [SECTION] Interops initialization
*/

/**
* @brief Signature of an OpenGL loader function, for example glfwGetProcAddress.
*/
typedef void* (*magik_gl_loader_proc)(const char* name);

/**
* @brief Loads Magiks OpenGL entry points. 
* 
* @param [in] loader A function which returns the address of a named OpenGL entry point.
*
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER, MAGIK_ERROR_GL_LOADER_FAILED
*
* @warning Magik links its own copy of the OpenGL loader, so the host application loading OpenGL for itself does not load Magiks. 
* Call  this once, with the OpenGL context current on the calling thread, before magik_get_system_Info() or any 
* MAGIK_AOV_CONFIG_OPENGL_INTEROP framebuffer. 
*/
MAGIK_API e_magik_result_types magik_gl_init(magik_gl_loader_proc loader);



/**
* [SECTION] Info
*/

/**
* @brief Prints system info to the console
* 
*/
MAGIK_API void magik_get_system_Info();



/**
* [SECTION] Version checking
*/

/**
* @brief Fetches API version
* 
* @param [out] major major version number
* @param [out] minor minor version number
* @param [out] revision revision number
* @param [out] as_char Formated char of the version number and codename, MAJOR.MINOR.REVISION - Codename, for example "Magik ! 0.1.0 -
* Rhapsody" 
* 
* @return MAGIK_SUCCESS
*/
MAGIK_API e_magik_result_types magik_get_version(uint32_t* major, uint32_t* minor, uint32_t* revision, const char** as_char);



/**
* [SECTION] Memory
*/



/**
* [SECTION] Render manager
*/

/**
* @brief Available display modes for a Magik instance. 
* 
* When MAGIK_DISPLAY_SWAPCHAIN is selected Magiks worker thread will automatically create a three frame swapchain. By default the 
* swapchain contains no layers. These have to be added using the command queue systems magik_command_add_aov_t command. In order to 
* access the front buffer the user has to create and configure a framebuffer using magik_configure_aov_framebuffer. Then the user 
* has to create an AOV container matching theor chosen config, for example magik_aov_container_config_opengl_interop_t. The user can 
* then fetch the front buffer using magik_aov_fetch and extract a specific buffer using the matching magik_aov_config_XXX_extract() 
* function. 
* 
* If MAGIK_DISPLAY_HEADLESS is chosen Magik will not create a swapchain. The function magik_aov_fetch cannot be called in this mode. 
* Instead, the user has to user magik_aov_fetch_render_framebuffer(). The extract functions, which only extract a given configuration 
* from the framebuffer, remain valid even in headless mode. 
*/
typedef enum e_magik_manager_display_types
{
    MAGIK_DISPLAY_SWAPCHAIN = 0,
    MAGIK_DISPLAY_HEADLESS = 1
} e_magik_manager_display_types;

/**
* @brief Descriptor for a Magik instance
* 
* @param display_type The managers display configuration
* @param user_device_id The CUDA device with the given ID will be used for Magiks render loop. 
* @param user_stream The CUDA stream used by Magik. If this field is left as null Magik will initalize a non-blocking stream internally.
* Which is destroyed when the manager terminates. If the field is populated Magik will treat the stream as borrowed and the DCC is 
* responsible for managing it. 
* @param cqs_n_reserved_chunk Number of 4 byte chunks in the command buffer.
* @param cqs_drop_overflows setting to toggle if overflowing commands are dropped. 
* 
* Note, the number of reserved chunks is not equal to the number of commands which can be pushed to the buffer in one dispatch cycle. 
* A command is, at least, 4 bytes large. But many store additional data inside the command buffer. For instance, if 4096 chunks are 
* allocated, the buffer can store 4096 commands of the minimum size. However if commands with, say, 40 bytes of total data are pushed, 
* the buffer can only hold 409 of them before overflowing. It is recommended to overallocate as even command buffers with tens of 
* thousands of chunks requiere little memory. Moreover, there is no penality for overallocating when Magik consumes the buffer, as it 
* internally tracks the number of occupied chunks. 
* 
* The command queue system is the primary way in which the user is expected to interface with Magik. It is a one way "fire and forget" 
* system. 
*/
typedef struct magik_manager_descriptor_t
{
    e_magik_manager_display_types display_type;

    uint32_t user_device_id;
    void* user_stream;

    uint32_t cqs_n_reserved_chunk;
    bool cqs_drop_overflow;

} magik_manager_descriptor_t;

/**
* @brief Opaque stuct for Magiks render state 
*/
typedef struct magik_render_manager* magik_render_manager_t;

/**
* @brief Creates a render manager based on a descriptor. 
* 
* @return MAGIK_SUCCESS, MAGIK_INVALID_CUDA_DEVICE, MAGIK_ERROR_COMMAND_BUFFER_ALLOCATION_FAILED
* 
* @warning  Calling this function automatically launches Magiks worker thread which will be ideling until the DCC has created a valid 
* render context using the command queue system. The CQS is configured in this function call as well. All "hot loop" functions, such 
* as magik_aov_fetch() are designed to handle situations where they are called before the worker thread is done initalizing. 
*/
MAGIK_API e_magik_result_types magik_render_manager_create(magik_render_manager_t* manager, magik_manager_descriptor_t descriptor);

/**
* @brief TEMP !!! All this does is stop the render thread and call .join(). 
*/
MAGIK_API e_magik_result_types magik_render_manager_destroy(magik_render_manager_t mananger);

/**
* @brief Returns the last error recorded by the manager
* 
* @param [in] manager Initalized manager
* 
* @related Last error
* 
* @warning This function is intended for async runtime errors. Most API functions provided in the API have an immediate effect as they run 
* on the DCC thread. But most of Magiks logic runs on an independent worker thread which may run into issues after the DCC made a function 
* call due to the async nature. These errors are caught by the manager and can be occasionally fetched by the DCC. It is up to the user to 
* device how often they want to do so.
* Do note, the DCC owns the manager. So when the API crashes, the last error is persistent in the manager.  
*/
MAGIK_API e_magik_result_types magik_render_manager_fetch_error(magik_render_manager_t manager);



/**
* [SECTION] Color
*/

typedef enum e_magik_color_matching_function_types
{
    MAGIK_CMF_CIE_1931 = 0
} e_magik_color_matching_function_types;

typedef enum e_magik_scene_colorspace_types
{
    MAGIK_SCENE_COLORSPACE_CIE_XYZ = 0,
    MAGIK_SCENE_COLORSPACE_CIE_RGB = 1,
    MAGIK_SCENE_COLORSPACE_LINEAR_REC709 = 2,
    MAGIK_SCENE_COLORSPACE_LINEAR_REC2020= 3,
    MAGIK_SCENE_COLORSPACE_ACES_CG = 4,
    MAGIK_SCENE_COLORSPACE_ADOBE_RGB_1998 = 5
} e_magik_scene_colorspace_types; 

typedef enum e_magik_display_colorspace_types
{
    MAGIK_DISPLAY_COLORSPACE_SRGB = 0,
    MAGIK_DISPLAY_COLORSPACE_REC709 = 1,
    MAGIK_DISPLAY_COLORSPACE_REC2100_PQ = 2,
    MAGIK_DISPLAY_COLORSPACE_REC2100_HLG = 3,
    MAGIK_DISPLAY_COLORSPACE_DCI_P3_THEATRICAL_WHITE_POINT = 4,
    MAGIK_DISPLAY_COLORSPACE_DISPLAY_P3 = 5,
    MAGIK_DISPLAY_COLORSPACE_ADOBE_RGB = 6
} e_magik_display_colorspace_types;

typedef enum e_magik_view_transform_types
{
    MAGIK_VIEW_TRANSFORM_NONE = 0,
    MAGIK_VIEW_TRANSFORM_REINHARD_SIMPLE = 1,
    MAGIK_VIEW_TRANSFORM_REINHARD_EXTENDED = 2,
    MAGIK_VIEW_TRANSFORM_GRAN_TURISMO_7 = 3,
    MAGIK_VIEW_TRANSFORM_AGX = 4,
    MAGIK_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL = 5
} e_magik_view_transform_types;

typedef enum e_magik_gran_turismo_7_mode_types
{
    MAGIK_GRAN_TURISMO_7_MODE_ICTCP = 0,
    MAGIK_GRAN_TURISMO_7_MODE_JZAZBZ = 1
} e_magik_gran_turismo_7_mode_types;

typedef enum e_magik_agx_look_types
{
    MAGIK_AGX_LOOK_NONE = 0,
    MAGIK_AGX_LOOK_GOLDEN = 1,
    MAGIK_AGX_LOOK_PUNCHY = 2
} e_magik_agx_look_types;

typedef enum e_magik_output_format_types
{
    MAGIK_OUTPUT_FORMAT_UNORM8 = 0,
    MAGIK_OUTPUT_FORMAT_UNORM10 = 1,
    MAGIK_OUTPUT_FORMAT_UNORM12 = 2,
    MAGIK_OUTPUT_FORMAT_UNORM16 = 3,
    MAGIK_OUTPUT_FORMAT_FLOAT16 = 4,
    MAGIK_OUTPUT_FORMAT_FLOAT32 = 5,
} e_magik_output_format_types;



/**
* [SECTION] Renderer statistics
*/

/**
* Magik owns the memory ! DO NOT FREE IT ON THE DCC ! IT IS RELEASED ON TERMINATION ! 
*/
typedef struct magik_renderer_statistics_t
{
    // Sample 
    size_t x_sample;

    // Render loop timings
    double total_render_time_seconds;
    double latest_render_loop_iteration_time_seconds;

    // Wavefront sample timings
    double total_wavefront_sample_time_seconds;
    double latest_wavefront_sample_time_seconds;

    // Wavefront queue
    size_t latest_wavefront_history_length;
    uint32_t* h_latest_advance_A_queue_count_history;
    uint32_t* h_latest_advance_B_queue_count_history;
    uint32_t* h_latest_intersect_queue_count_history;
    uint32_t* h_latest_bxdf_queue_count_history;
    uint32_t* h_latest_redistribute_queue_count_history;
    uint32_t* h_latest_splat_queue_count_history;

    // Memory usage
    size_t total_framebuffer_swapchain_size;
    size_t total_wavefront_buffer_size;
} magik_renderer_statistics_t;

/**
* @brief Returns render statistics.
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER
*/
MAGIK_API e_magik_result_types magik_fetch_renderer_statistics(magik_render_manager_t manager, bool* is_new_fetch, magik_renderer_statistics_t* dcc_statistics);

/**
* @brief Returns render statistics.
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER
*/
MAGIK_API e_magik_result_types magik_destroy_renderer_statistics(magik_renderer_statistics_t* statistics);




/**
* [SECTION] Framebuffer
*/

typedef enum e_magik_framebuffer_collection_config_types
{
    MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_HOST = 0,
    MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_CUDA = 1,              // To-be-implemented. DO NOT USE ! 
    MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_OPENGL_INTEROP = 2,
    MAGIK_FRAMEBUFFER_COLLECTION_CONFIG_VULKAN_INTEROP = 3     // To-be-implemented. DO NOT USE ! 
} e_magik_framebuffer_collection_config_types;

/**
* @brief Opaque struct which holds the framebuffers on the DCC thread. To extract the data you must call the matching extract function. 
*/
typedef struct magik_framebuffer_collection_external* magik_framebuffer_collection_external_t;

/**
* @brief Configurs the DCC side framebuffer to anticipate a "config_type" backend. The configuration can be changed at runtime. To do so 
* destroy the buffer, then overwrite the struct with this function. 
* 
* @param [in] config_type 
* 
* @return e_magik_result_types
* 
* @warning This function may generate the following errors; MAGIK_SUCCESS, MAGIK_UNKNOWN_ENUM_TYPE
* @warning This function does not requiere a swapchain to be setup, as the external framebuffer object can equally be used as the target 
* to extract the render framebuffer. 
*/
MAGIK_API e_magik_result_types magik_configure_framebuffer_collection(magik_framebuffer_collection_external_t* framebuffer, e_magik_framebuffer_collection_config_types config_type);

/**
* @brief This function fetches the most up-to-date AOV buffer from the API. Magik uses a tripple buffer lock-free swap chain. Memory 
* transfers only happen if the front AOV buffer internally tracked by Magik has changed since the last time this function was called. 
* 
* @param [in] manager The render manager from which you want the AOV 
* @param [out] framebuffer The DCC buffer instance to which the AOVs will be copied too. 
* 
* @return MAGIK_SUCCESS, MAGIK_UNKNOWN_ENUM_TYPE, MAGIK_ERROR_GL_BUFFER_SIZE_MISMATCH, MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED,
* MAGIK_ERROR_AOV_SWAPCHAIN_NOT_INITALIZED
* 
* @warning This function returns false if the API side AOV has not updated since the last call. In this case a transfer would not change 
* the result and is thus skipped. The DCC should only call the extract functions if this function returned true. Though the contents of 
* the AOV object do not expire between calls. The user is not responsible for allocating the DCC buffer ! Magik automatically allocates 
* and reallocates the buffers depending on the configuration and resolution ! The resolution is automatically updated using the active 
* camera. This function will always return false if Magik workers thread is not running, for example if it takes longer than usual to 
* initalze. 
* Calling _extract functions is not illegal even if this function returned falls. The extract functions simply convert Magik´s internal 
* representation which is already stored on the DCC to the user defined configuration. 
*/
MAGIK_API e_magik_result_types magik_framebuffer_collection_fetch(magik_render_manager_t manager, bool* is_new_fetch, magik_framebuffer_collection_external_t framebuffer); 

/**
* @brief Struct where the matching extract function will store pointers to the AOV memory to. 
* 
* @warning Do not allocate the pointers in this struct ! They will be overwriten by the extract function ! This struct servers as an 
* observer. 
*/
typedef struct magik_framebuffer_container_config_host_t
{
    uint32_t x_resolution;
    uint32_t y_resolution;
    uint32_t channels;
    size_t size_of_data;
    float* h_data;
} magik_framebuffer_container_config_host_t;

/**
* @brief Extracts the pointers to the host configured AOV buffer. 
* 
* @param [in] container Pointer to the struct into which the AOV data will be stored
* @param [in] framebuffer Buffer which stores the front AOV 
* @param [in] name The name of the AOV to be extracted
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER
*/
MAGIK_API e_magik_result_types magik_extract_config_host(magik_render_manager_t manager, magik_framebuffer_container_config_host_t* container, magik_framebuffer_collection_external_t framebuffer, const char* name);

/**
* @brief Struct which containes base types for a CUDA DCC backend. The user is responsible for casting these base types into CUDA ones 
* !
*/
typedef struct magik_framebuffer_container_config_cuda_t
{

} magik_framebuffer_container_config_cuda_t;

/**
* 
*/
MAGIK_API e_magik_result_types magik_extract_config_cuda(magik_framebuffer_container_config_cuda_t* container, magik_framebuffer_collection_external_t framebuffer);

/**
* @brief Struct which containes base types for a OpenGL DCC backend. The user is responsible for casting these base types into OpenGL
* ones !
*/
typedef struct magik_framebuffer_container_config_opengl_interop_t
{
    uint32_t x_resolution;
    uint32_t y_resolution;
    uint32_t channels;
    uint32_t gl_buffer_id;
    void* cuda_resources = nullptr; // true type is cudaGraphicsResource_t
} magik_framebuffer_container_config_opengl_interop_t;

/**
* @brief Extracts the OpenGL buffer id, cuda resources and resolution from the opaque AOV object
* 
* @param [in] container Pointer to the struct into which the AOV data will be stored
* @param [in] framebuffer Buffer which stores the front AOV 
* @param [in] name The name of the AOV to be extracted
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER, MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED, 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_extract_config_opengl_interop(magik_render_manager_t manager, magik_framebuffer_container_config_opengl_interop_t* container, magik_framebuffer_collection_external_t framebuffer, const char* name);

/**
* @brief Struct which containes base types for a Vulkan DCC backend. The user is responsible for casting these base types into 
* Vulkan ones !
*/
typedef struct magik_framebuffer_container_config_vulkan_interop_t
{

} magik_framebuffer_container_config_vulkan_interop_t;

/**
* @brief To be implemented ! DO NOT USE ! 
*/
MAGIK_API e_magik_result_types magik_extract_vulkan_interop(magik_framebuffer_container_config_vulkan_interop_t* container, magik_framebuffer_collection_external_t framebuffer);

/**
* @brief Free´s the memory associated with an AOV buffer. The user does not have to call this function each time the configuration 
* is changed. 
* 
* @param [in] framebuffer
* 
* @return 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_destroy_framebuffer_collection(magik_framebuffer_collection_external_t framebuffer);



/**
* [SECTION] Relativity
*/

typedef enum e_magik_spacetime_metric_types
{
    MINKOWSKI = 0,
    SCHWARZSCHILD = 1,
    KERR = 2
} e_magik_spacetime_metric_types;

typedef enum e_magik_test_particle_types
{
    MASSIVE = 0,
    MASSLESS = 1
} e_magik_test_particle_types;

typedef struct magik_trace_geodesic_metric_parameters_t
{
    e_magik_spacetime_metric_types metric_type;
    bool time_reversed;
    float event_horizon_scalar; // > 1 
    float schwarzschild_mass; // In kg
    float kerr_mass; // In kg
    float kerr_spin;
} magik_trace_geodesic_metric_parameters_t;

typedef struct magik_trace_geodesic_integrator_parameters_t
{
    unsigned int n_integrator_max_substep;
    float integrator_absolute_error_tolerance;
    float integrator_relative_error_tolerance;
} magik_trace_geodesic_integrator_parameters_t;

typedef struct magik_trace_geodesic_inital_conditions_t
{
    e_magik_test_particle_types test_particle_type;

    float spatial_position_x;
    float spatial_position_y;
    float spatial_position_z;

    float x_rotation;
    float y_rotation;
    float z_rotation;

    float local_proper_velocity_x;
    float local_proper_velocity_y;
    float local_proper_velocity_z;

    float massive_particle_speed;
} magik_trace_geodesic_inital_conditions_t;

typedef struct magik_trace_geodesic_step_t
{
    float four_position[4];
    float four_momentum[4];
    float moment_derivative[4];
    float four_vector_contraction;
    float affine_parameter;
    float delta_affine_parameter;
} magik_trace_geodesic_step_t;

typedef struct magik_trace_geodesic_container_t
{
    uint64_t capacity;
    uint32_t n_allocated_step;
    uint32_t n_written;
    magik_trace_geodesic_step_t* steps;
} magik_trace_geodesic_container_t; 

/**
* @brief This function enables the DCC to trace geodesics of a test particle in a chosen spacetime metric and set of initial conditions. 
* 
* @warning Magik does not allocate the memory requiered to store the geodesic. The user is responsible for providing the host memory and 
* correctly indicate the number of available slots. This function runs on the caller thread and is not async. 
*/
MAGIK_API e_magik_result_types magik_trace_geodesic(magik_trace_geodesic_container_t* container, magik_trace_geodesic_inital_conditions_t initial_conditions, magik_trace_geodesic_metric_parameters_t metric_parameters, magik_trace_geodesic_integrator_parameters_t integrator_parameters);



/**
* [SECTION] Command Queue System
*/

#if defined(__cplusplus) && __cplusplus >= 201103L
    #define MAGIK_ALIGN4 alignas(4)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
    #include <stdalign.h>
    #define MAGIK_ALIGN4 alignas(4)
#elif defined(_MSC_VER)
    #define MAGIK_ALIGN4 __declspec(align(4))
#elif defined(__GNUC__) || defined(__clang__)
    #define MAGIK_ALIGN4 __attribute__((aligned(4)))
#else
    #define MAGIK_ALIGN4
#endif 

/**
* @brief The list of all commands the DCC can issue to Magik. These commands cannot be used directly in the magik_cqs_push_command() 
* function as it takes a void* to a command struct. Every command struct includes its own type. This design, as opposed to one where 
* the user inputs the descrete command enum directly, to prevent the possibility of a command type mismatch. 
* 
* @warning Magik is designed to be entirly controlled through the Command Queue System. 
*/
typedef enum e_magik_cqs_command_types
{
    // ##################################
    // ### 1000-1999 Basic operations ###
    // ##################################
    /**
    * @brief Sets the internal render flag to "Rendering"
    */
    MAGIK_COMMAND_SET_STATE_RENDER = 1000,

    /**
    * @brief Sets the internal render flag to "Pause"
    */
    MAGIK_COMMAND_SET_STATE_PAUSE = 1001,

    /**
    * @brief Force clears the render buffer
    */
    MAGIK_COMMAND_CLEAR_RENDER_BUFFER = 1002, 

    /**
    * @brief Add new AOV
    */
    MAGIK_COMMAND_ADD_AOV = 1003,

    /**
    * @brief Delete AOV
    */
    MAGIK_COMMAND_REMOVE_AOV = 1004,



    // ################################
    // ### 2000-2999 Built-in tests ###
    // ################################
    /**
    * @brief Prints a char string from the worker thread
    */
    MAGIK_COMMAND_PRINTF = 2000,



    // ##########################
    // ### 3000-3999 Settings ###
    // ##########################



    // ############################
    // ### 4000-4999 Relativity ###
    // ############################
    /**
    * @brief Sets the global spacetime metric
    */
    MAGIK_COMMAND_SET_METRIC_MINKOWSKI = 4000,
    MAGIK_COMMAND_SET_METRIC_SCHWARZSCHILD = 4001,
    MAGIK_COMMAND_SET_METRIC_KERR = 4002,

    /**
    * @brief Sets the integrators tolerances and 
    * maximum number of per iteration substeps. 
    */
    MAGIK_COMMAND_SET_ABSOLUTE_ERROR_TOLERANCE = 4100,
    MAGIK_COMMAND_SET_RELATIVE_ERROR_TOLERANCE = 4101,
    MAGIK_COMMAND_SET_MAX_SUBSTEPS = 4102,

    /**
    * @brief Sets the observers, cameras, local 
    * proper velocity. This velocity can exceed 
    * the speed of light locally, but is naturally
    * bounded to it globally. 
    */
    MAGIK_COMMAND_SET_OBSERVER_LOCAL_PROPER_VELOCITY = 4200,

    /**
    * @brief Set the radius of the celestial sphere
    * centered about the observer. 
    */
    MAGIK_COMMAND_SET_CELESTIAL_SPHERE_RADIUS = 4300,

    /**
    * @brief Sets the schwarzschild black hole event
    * horizon scale multiplier. This value cannot be 
    * less than 1. The scalar increases the size of 
    * the horizon slightly to prevent geodesics from
    * taking too long to hit the boundary. 
    */
    MAGIK_COMMAND_SET_SCHWARZSCHILD_EVENT_HORIZON_SCALAR = 4400,

    /** 
    * @brief Sets the schwarzschild black holes mass
    * parameter. Magik supports a negative mass. This
    * is a mathematically valid, if physically meaningless
    * solution.  
    */
    MAGIK_COMMAND_SET_SCHWARZSCHILD_MASS_PARAMETER = 4401,
    
    /**
    * @brief Sets the Kerr black hole event horizon
    * scalar. This value cannot be smaller than 1. 
    * It artifically scales the event horizon to 
    * ensure geodesics terminate without spending 
    * hundreds of steps orbiting. 
    */
    MAGIK_COMMAND_SET_KERR_EVENT_HORIZON_SCALAR = 4402,
    
    /**
    * @brief Sets the kerr black hole's mass 
    * parameter. This value cannot be negative. 
    */
    MAGIK_COMMAND_SET_KERR_MASS_PARAMETER = 4403,
    
    /**
    * @brief Sets the kerr black hole's dimensionless
    * spin parameter. Conventionally the spin parameter
    * would be denoted as the angular momentum over 
    * mass. The angular momentum is factored out to
    * arrive at a dimensionless quantity. For physical
    * results use values between -1 and 1. Values 
    * outside this range are rendered and represent a 
    * naked singularity. 
    */
    MAGIK_COMMAND_SET_KERR_DIMENSIONLESS_SPIN_PARAMETER = 4404,


    
    // ########################
    // ### 5000-5999 Camera ###
    // ########################
    /**
    * @brief Set the active camera id
    */
    MAGIK_COMMAND_SET_ACTIVE_CAMERA = 5000,

    /**
    * @brief Set the position of a camera
    */
    MAGIK_COMMAND_SET_CAMERA_POSITION = 5001,

    /**
    * @brief Set the pitch, yaw and roll of a camera
    */
    MAGIK_COMMAND_SET_CAMERA_ORIENTATION = 5002,

    /**
    * @brief Set the resolution of the camera, values less than 2 are guarded against.
    */
    MAGIK_COMMAND_SET_CAMERA_RESOLUTION = 5003,



    // #######################
    // ### 6000-6999 Color ###
    // #######################
    /**
    * @brief Magik accumulates irradiance, energy, onto a per 
    * pixel buffer whoms dimensions are set by this command. 
    * The bins are equally spaced apart in the spectral domain. 
    * A higher number of bins results in higher color accuracy,
    * yet a count past 36 runs into deminishing returns. 
    * "Intrinsic" in this case simply refers to the fact Magik 
    * does not accumulate raw irradiance, but instead the energy
    * after having passed through the sensor. This means the 
    * sensor specific response, such as Halation, is baked into
    * the buffer.   
    */
    MAGIK_COMMAND_SET_N_INTRINSIC_SPECTRAL_IRRADIANCE_BIN = 6000,

    /**
    * @brief Sets the bounds of the spectral domain in which Magik
    * samples random wavelengths. This range should generally be 
    * the same as the chosen color matching function. The values
    * need to be provided in nanometres. 
    */
    MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MAXIMUM_WAVELENGTH_NM = 6001,
    MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MINIMUM_WAVELENGTH_NM = 6002,
    
    /**
    * @brief Magik samples individual wavelengths continiously
    * in the user-defined domain. Yet the spectral radiance, per
    * sample energy, is ultimatley converted to and discriticed 
    * into the intrinisc spectral irradiance buffer. 
    * To avoid spectral aliasing the energy is not simply added
    * to the closest bin, but redistributed across adjacent ones. 
    * The kernel used is a gaussian normal distribution. The SD 
    * of which is set by this command and measured in nanometre. 
    */
    MAGIK_COMMAND_SET_REDISTRIBUTION_STANDARD_DEVIATION_NM = 6003,

    /**
    * @brief Set the color matching function Magik uses to convert
    * the intrinsic spectral irradiance buffer into the CIE color 
    * system. 
    */
    MAGIK_COMMAND_SET_COLOR_MATCHING_FUNCTION = 6100,

    /**
    * @brief I dont know what to write here. These all explain 
    * themselves. 
    */
    MAGIK_COMMAND_SET_SCENE_COLORSPACE = 6101,
    MAGIK_COMMAND_SET_VIEW_TRANSFORM = 6102,
    MAGIK_COMMAND_SET_DISPLAY_COLORSPACE = 6103,
    MAGIK_COMMAND_SET_OUTPUT_FORMAT = 6104,

    MAGIK_COMMAND_SET_WHITE_BALANCE_WHITE_POINT = 6200,
    MAGIK_COMMAND_SET_WHITE_BALANCE_TINT = 6201,

    MAGIK_COMMAND_SET_VIEW_TRANSFORM_REINHARD_EXTENDED_WHITE_LUMINANCE = 6300,

    MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_START_COMPRESSION = 6301,
    MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_DESATURATION = 6302,

    MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_MODE = 6304,
    MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_SDR_PAPER_WHITE_BALANCE = 6305,
    MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_REFERENCE_LUMINANCE = 6306,
    MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_JZAZBZ_EXPONENT_SCALE_FACTOR = 6407,

    MAGIK_COMMAND_SET_VIEW_TRANSFORM_AGX_LOOK = 6308,



    // ########################
    // ### 7000-7999 Render ###
    // ########################
    /**
    * @brief Sets the maximum number of geodesic steps Magik is
    * allowed to take throughout an entire path's trajectory. This 
    * is not the same as the bounce limits ! For every interaction,
    * such as reflections, many geodesic steps might be consumed. 
    */
    MAGIK_COMMAND_SET_N_GEODESIC_STEP_LIMIT = 7000,
    
    /**
    * @brief Sets the maximum number of reflections. 
    */
    MAGIK_COMMAND_SET_N_REFLECTED_LIMIT = 7001,



    // ################################
    // ### 8000-8999 bxdf materials ###
    // ################################ 

    // Prohibited
    MAGIK_COMMAND_PROHIBITED_FORCE_SIZE = 0x7FFFFFFF 
} e_magik_cqs_command_types;

/**
* @brief Command data types. 
* 
* @warning  Attempting to modify the embedded type will result in a compilation error. The embeeded type is used by Magik to map a 
* specific command to its execution path. Changing the embedded type will cause issues if the change is not properly propagated 
* throughout the API. 
*/

typedef struct MAGIK_ALIGN4 magik_command_header_t
{
    uint32_t type;
    uint32_t size; // Size of the whole struct, including the header
} magik_command_header_t;

// ##################################
// ### 1000-1999 Basic operations ###
// ##################################
typedef struct MAGIK_ALIGN4 magik_command_set_state_render_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_STATE_RENDER;
} magik_command_set_state_render_t;

typedef struct MAGIK_ALIGN4 magik_command_set_state_pause_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_STATE_PAUSE;
} magik_command_set_state_pause_t;

typedef struct MAGIK_ALIGN4 magik_command_clear_render_buffer_t
{
    magik_command_header_t header; // MAGIK_COMMAND_CLEAR_RENDER_BUFFER;
} magik_command_clear_render_buffer_t;

typedef struct MAGIK_ALIGN4 magik_command_add_aov_t
{
    magik_command_header_t header; // MAGIK_COMMAND_ADD_AOV;
    uint32_t length_of_name;
    char name[512];
    uint32_t channels;
} magik_command_add_aov_t;

typedef struct MAGIK_ALIGN4 magik_command_remove_aov_t
{
    magik_command_header_t header; // MAGIK_COMMAND_REMOVE_AOV;
    uint32_t length_of_name;
    char name[512];
} magik_command_remove_aov_t;



// ################################
// ### 2000-2999 Built-in tests ###
// ################################
typedef struct MAGIK_ALIGN4 magik_command_printf_t
{
    magik_command_header_t header; // MAGIK_COMMAND_PRINTF;
    uint32_t length_of_text;
    char text[512];
} magik_command_printf_t;



// ##########################
// ### 3000-3999 Settings ###
// ##########################



// ############################
// ### 4000-4999 Relativity ###
// ############################
typedef struct MAGIK_ALIGN4 magik_command_set_metric_minkowski_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_METRIC_MINKOWSKI;
} magik_command_set_metric_minkowski_t;

typedef struct MAGIK_ALIGN4 magik_command_set_metric_schwarzschild_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_METRIC_SCHWARZSCHILD;
} magik_command_set_metric_schwarzschild_t;

typedef struct MAGIK_ALIGN4 magik_command_set_metric_kerr_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_METRIC_KERR;
} magik_command_set_metric_kerr_t;

typedef struct MAGIK_ALIGN4 magik_command_set_absolute_error_tolerance_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_ABSOLUTE_ERROR_TOLERANCE;
    float absolute_error_tolerance; // 1e-3f
} magik_command_set_absolute_error_tolerance_t;

typedef struct MAGIK_ALIGN4 magik_command_set_relative_error_tolerance_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_RELATIVE_ERROR_TOLERANCE;
    float relative_error_tolerance; // 1e-10f
} magik_command_set_relative_error_tolerance_t;

typedef struct MAGIK_ALIGN4 magik_command_set_max_substeps_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_MAX_SUBSTEPS;
    uint32_t max_substeps; // 56
} magik_command_set_max_substeps_t;

typedef struct MAGIK_ALIGN4 magik_command_set_observer_local_proper_velocity_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_OBSERVER_LOCAL_PROPER_VELOCITY;
    float velocity_x;
    float velocity_y;
    float velocity_z;
} magik_command_set_observer_local_proper_velocity_t;

typedef struct MAGIK_ALIGN4 magik_command_set_celestial_sphere_radius_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_CELESTIAL_SPHERE_RADIUS;
    float celestial_sphere_radius;
} magik_command_set_celestial_sphere_radius_t;

typedef struct MAGIK_ALIGN4 magik_command_set_schwarzschild_event_horizon_scalar_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_SCHWARZSCHILD_EVENT_HORIZON_SCALAR;
    float scalar;
} magik_command_set_schwarzschild_event_horizon_scalar_t;

typedef struct MAGIK_ALIGN4 magik_command_set_schwarzschild_mass_parameter_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_SCHWARZSCHILD_MASS_PARAMETER;
    float mass_parameter; // 6.7329546075E26f
} magik_command_set_schwarzschild_mass_parameter_t;

typedef struct MAGIK_ALIGN4 magik_command_set_kerr_event_horizon_scalar_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_KERR_EVENT_HORIZON_SCALAR;
    float scalar;
} magik_command_set_kerr_event_horizon_scalar_t;

typedef struct MAGIK_ALIGN4 magik_command_set_kerr_mass_parameter_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_KERR_MASS_PARAMETER;
    float mass_parameter; // 6.7329546075E26f
} magik_command_set_kerr_mass_parameter_t;

typedef struct MAGIK_ALIGN4 magik_command_set_kerr_dimensionless_spin_parameter_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_KERR_DIMENSIONLESS_SPIN_PARAMETER;
    float dimensionless_spin_parameter; // 0.999f
} magik_command_set_kerr_dimensionless_spin_parameter_t;



// ########################
// ### 5000-5999 Camera ###
// ########################
typedef struct MAGIK_ALIGN4 magik_command_set_active_camera_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_ACTIVE_CAMERA;
    uint32_t id = 0;
} magik_command_set_active_camera_t;

typedef struct MAGIK_ALIGN4 magik_command_set_camera_position_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_CAMERA_POSITION;
    uint32_t id = 0;
    float position_x = 0.0f;
    float position_y = 0.0f;
    float position_z = 0.0f;
} magik_command_set_camera_position_t;

typedef struct MAGIK_ALIGN4 magik_command_set_camera_orientation_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_CAMERA_ORIENTATION;
    uint32_t id = 0;
    float rotation_x = 0.0f;
    float rotation_y = 0.0f;
    float rotation_z = 0.0f;
} magik_command_set_camera_orientation_t;

typedef struct MAGIK_ALIGN4 magik_command_set_camera_resolution_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_CAMERA_RESOLUTION;
    uint32_t x_resolution = 2;
    uint32_t y_resolution = 2;
} magik_command_set_camera_resolution_t;



// #######################
// ### 6000-6999 Color ###
// #######################
typedef struct MAGIK_ALIGN4 magik_command_set_n_intrinsic_spectral_irradiance_bin_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_N_INTRINSIC_SPECTRAL_IRRADIANCE_BIN;
    uint32_t n_isi_bin; // 24
} magik_command_set_n_intrinsic_spectral_irradiance_bin_t;

typedef struct MAGIK_ALIGN4 magik_command_set_sample_domain_maximum_wavelength_nm_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MAXIMUM_WAVELENGTH_NM;
    float maximum_wavelength_nm; // 830.0f
} magik_command_set_sample_domain_maximum_wavelength_nm_t;

typedef struct MAGIK_ALIGN4 magik_command_set_sample_domain_minimum_wavelength_nm_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_SAMPLE_DOMAIN_MINIMUM_WAVELENGTH_NM;
    float minimum_wavelength_nm; // 380.0f
} magik_command_set_sample_domain_minimum_wavelength_nm_t;

typedef struct MAGIK_ALIGN4 magik_command_set_redistribution_standard_deviation_nm_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_REDISTRIBUTION_STANDARD_DEVIATION_NM;
    float standard_deviation_nm; // 10.0f
} magik_command_set_redistribution_standard_deviation_nm_t;

typedef struct MAGIK_ALIGN4 magik_command_set_color_matching_function_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_COLOR_MATCHING_FUNCTION;
    e_magik_color_matching_function_types cmf_type; // CIE 1931
} magik_command_set_color_matching_function_t;

typedef struct MAGIK_ALIGN4 magik_command_set_scene_colorspace_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_SCENE_COLORSPACE;
    e_magik_scene_colorspace_types scene_colorspace;
} magik_command_set_scene_colorspace_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM;
    e_magik_view_transform_types view_transform;
} magik_command_set_view_transform_t;

typedef struct MAGIK_ALIGN4 magik_command_set_display_colorspace_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_DISPLAY_COLORSPACE;
    e_magik_display_colorspace_types display_colorspace;
} magik_command_set_display_colorspace_t;

typedef struct MAGIK_ALIGN4 magik_command_set_output_format_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_OUTPUT_FORMAT;
    e_magik_output_format_types output_format;
} magik_command_set_output_format_t;

typedef struct MAGIK_ALIGN4 magik_command_set_white_balance_white_point_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_WHITE_BALANCE_WHITE_POINT;
    float white_point_kelvin;
} magik_command_set_white_balance_white_point_t;

typedef struct MAGIK_ALIGN4 magik_command_set_white_balance_tint_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_WHITE_BALANCE_TINT;
    float tint;
} magik_command_set_white_balance_tint_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_reinhard_extended_white_luminance_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_REINHARD_EXTENDED_WHITE_LUMINANCE;
    float white_luminance;
} magik_command_set_view_transform_reinhard_extended_white_luminance_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_khronos_pbr_neutral_start_compression_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_START_COMPRESSION;
    float start_compression;
} magik_command_set_view_transform_khronos_pbr_neutral_start_compression_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_khronos_pbr_neutral_desaturation_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_KHRONOS_PBR_NEUTRAL_DESATURATION;
    float desaturation;
} magik_command_set_view_transform_khronos_pbr_neutral_desaturation_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_gt7_mode_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_MODE;
    e_magik_gran_turismo_7_mode_types mode;
} magik_command_set_view_transform_gt7_mode_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_gt7_sdr_paper_white_balance_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_SDR_PAPER_WHITE_BALANCE;
    float sdr_paper_white_balance;
} magik_command_set_view_transform_gt7_sdr_paper_white_balance_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_gt7_reference_luminance_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_REFERENCE_LUMINANCE;
    float reference_luminance;
} magik_command_set_view_transform_gt7_reference_luminance_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_gt7_jzazbz_exponent_scale_factor_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_GT7_JZAZBZ_EXPONENT_SCALE_FACTOR;
    float jzazbz_exponent_scale_factor;
} magik_command_set_view_transform_gt7_jzazbz_exponent_scale_factor_t;

typedef struct MAGIK_ALIGN4 magik_command_set_view_transform_agx_look_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_VIEW_TRANSFORM_AGX_LOOK;
    e_magik_agx_look_types look;
} magik_command_set_view_transform_agx_look_t;



// ########################
// ### 7000-7999 Render ###
// ########################
typedef struct MAGIK_ALIGN4 magik_command_set_n_geodesic_step_limit_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_N_GEODESIC_STEP_LIMIT;
    uint32_t n_geodesic_step_limit;
} magik_command_set_n_geodesic_step_limit_t;

typedef struct MAGIK_ALIGN4 magik_command_set_n_reflected_limit_t
{
    magik_command_header_t header; // MAGIK_COMMAND_SET_N_REFLECTED_LIMIT;
    uint32_t n_reflected_limit;
} magik_command_set_n_reflected_limit_t;



/**
* @brief Pushes a command to the command buffer.
*  
* @param [in] manager Previously initialized Magik render manager
* @param [in] command Dedicated struct which includes the command type itself.  
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW, MAGIK_ERROR_INVALID_COMMAND, MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED, 
* MAGIK_ERROR_INVALID_POINTER
* 
* @warning  By default this function returns MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW if the size of the most recently pushed command 
* exceeds the space occupied by previous commands issued during the dispatch cycle. This behaivor can be disabled by adding setting 
* the "drop_overflows" bool during the configuration to true. In which case the function returns MAGIK_SUCCESS. 
*/
MAGIK_API e_magik_result_types magik_cqs_push_command(magik_render_manager_t manager, const void* command);

/**
* @brief Swaps the front and back command buffers with the worker thread. 
* 
* @param [in] manager Previously initialized Magik render manager
* 
* @return true if the dispatch was successful, false otherwise. 
* 
* @warning  Dispatching the command buffer can "fail". The worker thread may not have finished consuming the back buffer in which case 
* this function will not do anything. Do note, returning "false" does not mean an error occured ! But merely that the worker thread was 
* not ready. 
* The system is designed to handle this case and allow the user to continue writing to the front buffer over the next DCC cycle. So 
* commands can accumulate over multiple cycles. If this happens the function returns false. 
*/
MAGIK_API e_magik_result_types magik_cqs_dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched);



#ifdef __cplusplus
}
#endif

#endif
