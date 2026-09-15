#ifndef MAGIK_H
#define MAGIK_H

#include <stdint.h>

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
#define MAGIK_VERSION_MINOR 3           // Small changes / additions
#define MAGIK_VERSION_REVISION 0        // Bug fix release



/**
* [SECTION] Error handling & result types
*/
typedef enum e_magik_result_types
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

    // Device 300 - 399
    MAGIK_ERROR_DEVICE_OUT_OF_MEMORY = 200,

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

    // General 10000 - 10099
    MAGIK_ERROR_UNKNOWN = 10000,

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
* @brief Gets the last magik error. This is useful in circumstances where a Magik function call is wrapped inside another 
* function which may not be able to return the error. You can nest this function inside the check_magik_error macro to get the 
* usual behavior. 
*
* @return Last error
* 
* @warning While the function is thread safe it can only return the last error and is not intrinsically aware to distinguish where 
* an error happen. The error log will use the location check_magik_error ! 
*/
MAGIK_API e_magik_result_types magik_get_last_error(void);

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
* [SECTION] Tests
*/

/**
* @brief Example of an opaque pointer & struct. More specifically, this defines an opaque alias to a pointer of an internal struct. 
* Where magik_rgba_test_frame_buffer is internal and magik_rgba_test_frame_buffer_t is the alias. 
*/
typedef struct magik_test_rgba_frame_buffer* magik_test_rgba_frame_buffer_t;

/**
* @brief Two test-kernel patterns are available. The UV gradient should appear with the black corner, R = G = B = 0, at the lower left 
* side of your window. The mandelbrot is intended to test resource allocation performance. 
*/
typedef enum e_magik_test_kernel_pattern_types
{
    uv_gradient = 0,
    mandelbrot = 1
} e_magik_test_kernel_pattern_types;



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
* [SECTION] Frame time
*/

/**
* @brief Returns the frame time in microseconds. 
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER
*/
MAGIK_API e_magik_result_types magik_fetch_frame_time(double* ft);



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
* @param cuda_device The CUDA device with the given ID will be used for Magiks render loop. 
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
    e_magik_manager_display_types display_type = MAGIK_DISPLAY_SWAPCHAIN;

    uint32_t cuda_device_id = 0;

    uint32_t cqs_n_reserved_chunk = 4096;
    bool cqs_drop_overflow = false;
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
MAGIK_API magik_render_manager_t magik_create_render_manager(magik_manager_descriptor_t descriptor);

/**
* @brief TEMP !!! All this does is stop the render thread and call .join(). 
*/
MAGIK_API e_magik_result_types magik_destroy_render_manager(magik_render_manager_t mananger);



/**
* [SECTION] Arbitrary Output Variables
*/

typedef enum e_magik_aov_config_types
{
    MAGIK_AOV_CONFIG_HOST = 0,
    MAGIK_AOV_CONFIG_CUDA = 1,              // To-be-implemented. DO NOT USE ! 
    MAGIK_AOV_CONFIG_OPENGL_INTEROP = 2,
    MAGIK_AOV_CONFIG_VULKAN_INTEROP = 3     // To-be-implemented. DO NOT USE ! 
} e_magik_aov_transfer_types;

/**
* @brief Opaque struct which holds the AOV buffers on the DCC thread. To extract the data you must call the matching extract function. 
*/
typedef struct magik_aov_framebuffer_object_external* magik_aov_framebuffer_object_external_t;

/**
* @brief Configurs the DCC side AOV buffer to anticipate a "config_type" backend. The configuration can be changed at runtime. To do so 
* destroy the buffer, then overwrite the struct with this function. 
* 
* @param [in] config_type 
* 
* @return magik_external_aov_buffer_t
* 
* @warning This function may generate the following errors; MAGIK_SUCCESS, MAGIK_UNKNOWN_ENUM_TYPE
* @warning This function does not requiere a swapchain to be setup, as the external framebuffer object can equally be used as the target 
* to extract the render framebuffer. 
*/
MAGIK_API magik_aov_framebuffer_object_external_t magik_configure_aov_framebuffer(e_magik_aov_config_types config_type);

/**
* @brief This function fetches the most up-to-date AOV buffer from the API. Magik uses a tripple buffer lock-free swap chain. Memory 
* transfers only happen if the front AOV buffer internally tracked by Magik has changed since the last time this function was called. 
* 
* @param [in] manager The render manager from which you want the AOV 
* @param [out] dcc_buffer The DCC buffer instance to which the AOVs will be copied too. 
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
MAGIK_API bool magik_aov_fetch(magik_render_manager_t manager, magik_aov_framebuffer_object_external_t dcc_buffer); 

/**
* @brief Struct where the matching extract function will store pointers to the AOV memory to. 
* 
* @warning Do not allocate the pointers in this struct ! They will be overwriten by the extract function ! This struct servers as an 
* observer. 
*/
typedef struct magik_aov_container_config_host_t
{
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;
    uint32_t channels = 0;
    size_t size_of_data = 0;
    float* h_data = nullptr;
} magik_aov_container_config_host_t;

/**
* @brief Extracts the pointers to the host configured AOV buffer. 
* 
* @param [in] container Pointer to the struct into which the AOV data will be stored
* @param [in] dcc_buffer Buffer which stores the front AOV 
* @param [in] name The name of the AOV to be extracted
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER
*/
MAGIK_API e_magik_result_types magik_aov_config_host_extract(magik_render_manager_t manager, magik_aov_container_config_host_t* container, magik_aov_framebuffer_object_external_t dcc_buffer, const char* name);

/**
* @brief Struct which containes base types for a CUDA DCC backend. The user is responsible for casting these base types into CUDA ones 
* !
*/
typedef struct magik_aov_container_config_cuda_t
{

} magik_aov_container_config_cuda_t;

/**
* 
*/
MAGIK_API e_magik_result_types magik_aov_config_cuda_extract(magik_aov_container_config_cuda_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief Struct which containes base types for a OpenGL DCC backend. The user is responsible for casting these base types into OpenGL
* ones !
*/
typedef struct magik_aov_container_config_opengl_interop_t
{
    uint32_t x_resolution = 0;
    uint32_t y_resolution = 0;
    uint32_t channels = 0;
    uint32_t gl_buffer_id = 0;
    void* cuda_resources = nullptr; // true type is cudaGraphicsResource_t
} magik_aov_container_config_opengl_interop_t;

/**
* @brief Extracts the OpenGL buffer id, cuda resources and resolution from the opaque AOV object
* 
* @param [in] container Pointer to the struct into which the AOV data will be stored
* @param [in] dcc_buffer Buffer which stores the front AOV 
* @param [in] name The name of the AOV to be extracted
* 
* @return MAGIK_SUCCESS, MAGIK_ERROR_INVALID_POINTER, MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED, 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_aov_config_opengl_interop_extract(magik_render_manager_t manager, magik_aov_container_config_opengl_interop_t* container, magik_aov_framebuffer_object_external_t dcc_buffer, const char* name);

/**
* @brief Struct which containes base types for a Vulkan DCC backend. The user is responsible for casting these base types into 
* Vulkan ones !
*/
typedef struct magik_aov_container_config_vulkan_interop_t
{

} magik_aov_container_config_vulkan_interop_t;

/**
* @brief To be implemented ! DO NOT USE ! 
*/
MAGIK_API e_magik_result_types magik_aov_extract_vulkan_interop_extract(magik_aov_container_config_vulkan_interop_t* container, magik_aov_framebuffer_object_external_t dcc_buffer);

/**
* @brief Free´s the memory associated with an AOV buffer. The user does not have to call this function each time the configuration 
* is changed. 
* 
* @param [in] dcc_buffer
* 
* @return 
* 
* @warning 
*/
MAGIK_API e_magik_result_types magik_aov_destroy(magik_aov_framebuffer_object_external_t dcc_buffer);



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

    /**
    * @brief Force resizes the render buffer
    */
    MAGIK_COMMAND_SET_RESOLUTION = 2001,

    /**
    * @brief Sets the complex offset point of the julia set kernel
    */
    MAGIK_COMMAND_SET_JULIA_SET_OFFSET = 2002,

    /**
    * @brief Sets the Julia set color pallet
    */
    MAGIK_COMMAND_SET_JULIA_SET_COLOR = 2003,



    // ##########################
    // ### 3000-3999 Settings ###
    // ##########################



    // #######################
    // ### 4000-4999 Scene ###
    // #######################


    
    // ########################
    // ### 5000-5999 Camera ###
    // ########################



    // #################################
    // ### 6000-6999 Hittable Object ###
    // #################################



    // ################################
    // ### 7000-7999 bxdf materials ###
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

// ##################################
// ### 1000-1999 Basic operations ###
// ##################################
typedef struct MAGIK_ALIGN4 magik_command_set_state_render_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_SET_STATE_RENDER;
} magik_command_set_state_render_t;

typedef struct MAGIK_ALIGN4 magik_command_set_state_pause_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_SET_STATE_PAUSE;
} magik_command_set_state_pause_t;

typedef struct MAGIK_ALIGN4 magik_command_clear_render_buffer_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_CLEAR_RENDER_BUFFER;
} magik_command_clear_render_buffer_t;

typedef struct MAGIK_ALIGN4 magik_command_add_aov_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_ADD_AOV;
    uint32_t length_of_name = 0;
    char name[512];
    uint32_t channels = 0;
} magik_command_add_aov_t;

typedef struct MAGIK_ALIGN4 magik_command_remove_aov_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_REMOVE_AOV;
    uint32_t length_of_name = 0;
    char name[512];
} magik_command_remove_aov_t;



// ################################
// ### 2000-2999 Built-in tests ###
// ################################
typedef struct MAGIK_ALIGN4 magik_command_printf_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_PRINTF;
    uint32_t length_of_text = 0;
    char text[512];
} magik_command_printf_t;

typedef struct MAGIK_ALIGN4 magik_command_set_resolution_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_SET_RESOLUTION;
    uint32_t x_resolution = 2;
    uint32_t y_resolution = 2;
} magik_command_set_resolution_t;

typedef struct MAGIK_ALIGN4 magik_command_set_julia_set_offset_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_SET_JULIA_SET_OFFSET;
    float real = 0.0f;
    float imaginary = 0.0f;
} magik_command_set_julia_set_offset_t;

typedef struct MAGIK_ALIGN4 magik_command_set_julia_set_color_t
{
    const e_magik_cqs_command_types embedded_type = MAGIK_COMMAND_SET_JULIA_SET_COLOR;
    float c0 = 0.0f;
    float c1 = 0.0f;
    float c2 = 0.0f;
} magik_command_set_julia_set_color_t;



// ##########################
// ### 3000-3999 Settings ###
// ##########################



// #######################
// ### 4000-4999 Scene ###
// #######################



// ########################
// ### 5000-5999 Camera ###
// ########################



// #################################
// ### 6000-6999 Hittable Object ###
// #################################



// ################################
// ### 7000-7999 bxdf materials ###
// ################################



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
MAGIK_API bool magik_cqs_dispatch_command_buffer(magik_render_manager_t manager);



#ifdef __cplusplus
}
#endif

#endif
