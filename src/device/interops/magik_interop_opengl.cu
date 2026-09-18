#include "magik_interop_opengl.cuh"

namespace magik::interops
{
    static bool g_gl_loaded = false;

    bool gl_init(void* (*loader)(const char*))
    {
        g_gl_loaded = gladLoadGLLoader((GLADloadproc)loader) != 0;
        return g_gl_loaded;
    }

    e_magik_result_types get_gl_info()
    {
        if(!g_gl_loaded) 
        {
            return MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED;
        }

        const GLubyte* version  = glGetString(GL_VERSION);
        if(version)
        {
            std::cout << "OpenGL Version: " << version << std::endl;
        }
        else
        {
            std::cout << "Failed to get OpenGL Version" << std::endl;
        }

        return MAGIK_SUCCESS;
    }

    e_magik_result_types allocate_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource)
    {
        if(!g_gl_loaded) 
        {
            return MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED;
        }

        size_t size_of_gl_buffer = (size_t)(x_resolution*y_resolution*channels) * sizeof(float);
        uint32_t pbo_id;
        glGenBuffers(1, &pbo_id);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo_id);
        glBufferData(GL_PIXEL_UNPACK_BUFFER, size_of_gl_buffer, nullptr, GL_DYNAMIC_DRAW);
        cudaGraphicsResource_t cuda_res;
        check_cuda_errors(cudaGraphicsGLRegisterBuffer(&cuda_res, pbo_id, cudaGraphicsRegisterFlagsNone));

        *gl_buffer_id = pbo_id;
        *cuda_resource = (void*)cuda_res;

        return MAGIK_SUCCESS;
    }

    e_magik_result_types free_gl_buffer(uint32_t* gl_buffer_id, void** cuda_resource)
    {
        if(!g_gl_loaded) 
        {
            return MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED;
        }

        if(cuda_resource && *cuda_resource)
        {
            check_cuda_errors(cudaGraphicsUnregisterResource(static_cast<cudaGraphicsResource_t>(*cuda_resource)));
            *cuda_resource = nullptr;
        }

        if(gl_buffer_id && *gl_buffer_id != 0)
        {
            glDeleteBuffers(1, gl_buffer_id);
            *gl_buffer_id = 0;
        }

        return MAGIK_SUCCESS;
    }

    e_magik_result_types map_cuda_to_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr)
    {
        if(!*cuda_resource || !d_ptr) return MAGIK_ERROR_INVALID_POINTER;

        if(!g_gl_loaded) 
        {
            return MAGIK_ERROR_GL_FUNCTIONS_NOT_LOADED;
        }

        cudaGraphicsResource_t cuda_res = static_cast<cudaGraphicsResource_t>(*cuda_resource);
        check_cuda_errors(cudaGraphicsMapResources(1, &cuda_res, 0));

        void* d_resource_ptr = nullptr;
        size_t size_of_resource = 0;
        check_cuda_errors(cudaGraphicsResourceGetMappedPointer(&d_resource_ptr, &size_of_resource, cuda_res));

        size_t size_of_buffer = (size_t)(x_resolution*y_resolution*channels)*sizeof(float);
        if(size_of_buffer > size_of_resource) 
        {
            return MAGIK_ERROR_GL_BUFFER_SIZE_MISMATCH;
        }

        else check_cuda_errors(cudaMemcpy(d_resource_ptr, d_ptr, size_of_buffer, cudaMemcpyDeviceToDevice));

        check_cuda_errors(cudaMemcpy(d_resource_ptr, d_ptr, size_of_buffer, cudaMemcpyDeviceToDevice));
        check_cuda_errors(cudaGraphicsUnmapResources(1, &cuda_res, 0));

        return MAGIK_SUCCESS;
    }
}
