#include "magik_interop_opengl.cuh"

namespace magik::interops
{
    void get_gl_info()
    {
        const GLubyte* version  = glGetString(GL_VERSION);
        if(version)
        {
            std::cout << "OpenGL Version: " << version << std::endl;
        }
        else
        {
            std::cout << "Failed to get OpenGL Version" << std::endl;
        }
    }

    void allocate_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource)
    {
        uint32_t pbo_id;
        glGenBuffers(1, &pbo_id);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pbo_id);
        glBufferData(GL_PIXEL_UNPACK_BUFFER, (size_t)(x_resolution*y_resolution*channels) * sizeof(float), nullptr, GL_DYNAMIC_DRAW);
        cudaGraphicsResource_t cuda_res;
        check_cuda_errors(cudaGraphicsGLRegisterBuffer(&cuda_res, pbo_id, cudaGraphicsRegisterFlagsNone));

        *gl_buffer_id = pbo_id;
        *cuda_resource = (void*)cuda_res;
    }

    void free_gl_buffer(uint32_t* gl_buffer_id, void** cuda_resource)
    {
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
    }

    void map_cuda_to_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr)
    {
        if(!*cuda_resource || !d_ptr) return;

        cudaGraphicsResource_t cuda_res = static_cast<cudaGraphicsResource_t>(*cuda_resource);
        check_cuda_errors(cudaGraphicsMapResources(1, &cuda_res, 0));

        void* d_resource_ptr = nullptr;
        size_t size_of_resource = 0;

        check_cuda_errors(cudaGraphicsResourceGetMappedPointer(&d_resource_ptr, &size_of_resource, cuda_res));

        size_t size_of_buffer = (size_t)(x_resolution*y_resolution*channels)*sizeof(float);

        if(size_of_buffer > size_of_resource) { /* log + bail, don't memcpy */ }
        else check_cuda_errors(cudaMemcpy(d_resource_ptr, d_ptr, size_of_buffer, cudaMemcpyDeviceToDevice));

        check_cuda_errors(cudaMemcpy(d_resource_ptr, d_ptr, size_of_buffer, cudaMemcpyDeviceToDevice));

        check_cuda_errors(cudaGraphicsUnmapResources(1, &cuda_res, 0));
    }
}
