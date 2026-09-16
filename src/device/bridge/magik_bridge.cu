#include "magik_bridge.h"
#include "magik_test_pattern.cuh"
#include "magik_interop_opengl.cuh"
#include "magik_library.cuh"

namespace magik::bridge
{
    bool host_gl_init(void* (*loader)(const char*))
    {
        return magik::interops::gl_init(loader);
    }

    int32_t host_get_n_cuda_device()
    {
        int32_t n_device = 0;
        check_cuda_errors(cudaGetDeviceCount(&n_device));

        return n_device;
    }

    void host_get_system_info()
    {
        int n_device = 0;
        check_cuda_errors(cudaGetDeviceCount(&n_device));

        printf("Number of CUDA devices %d \n", n_device);

        for(int i_device = 0; i_device < n_device; i_device++)
        {
            cudaDeviceProp device_prop;
            check_cuda_errors(cudaGetDeviceProperties(&device_prop, i_device));

            if(n_device == 0)
            {
                if(device_prop.major == 9999 && device_prop.minor == 9999)
                {
                    printf("No CUDA GPU has been detected. \n");
                    return;
                }
            }

            printf("\n");
            printf("CUDA device #%d\n", i_device);
            printf("Device name:                        %s\n", device_prop.name);
            printf("Major revision number:              %d\n", device_prop.major);
            printf("Minor revision number:              %d\n", device_prop.minor);
            printf("Total global memory:                %lu\n", (unsigned long)device_prop.totalGlobalMem);
            printf("Total shared memory per block:      %lu\n", (unsigned long)device_prop.sharedMemPerBlock);
            printf("Total constant memory size:         %lu\n", (unsigned long)device_prop.totalConstMem);
            printf("Warp size:                          %d\n", device_prop.warpSize);
            printf("Maximum block dimensions:           %d x %d x %d\n", device_prop.maxThreadsDim[0], device_prop.maxThreadsDim[1], device_prop.maxThreadsDim[2]);
            printf("Maximum grid dimensions:            %d x %d x %d\n", device_prop.maxGridSize[0], device_prop.maxGridSize[1], device_prop.maxGridSize[2]);
            printf("Number of multiprocessors:          %d\n", device_prop.multiProcessorCount);
            printf("\n");
        }
    }

    template<typename T> static  T* allocate_device_memory(size_t size)
    {
        T* d_ptr = nullptr;
        if(size == 0) return nullptr;
        check_cuda_errors(cudaMalloc(&d_ptr, size));
        return d_ptr;
    }

    template<typename T> static  T* allocate_host_memory(size_t size)
    {
        T* h_ptr = nullptr;
        if(size == 0) return nullptr;
        check_cuda_errors(cudaMallocHost(&h_ptr, size));
        return h_ptr;
    }

    template<typename T> static void destroy_device_memory(T* ptr)
    {
        if(!ptr) return;
        check_cuda_errors(cudaFree(ptr));
    }

    template<typename T> static void destroy_host_memory(T* ptr)
    {
        if(!ptr) return;
        check_cuda_errors(cudaFreeHost(ptr));
    }

    template<typename T> static void memcpy_device_to_host(T* h_ptr, T* d_ptr, size_t size)
    {
        if(!h_ptr || !d_ptr || (size == 0)) return;
        check_cuda_errors(cudaMemcpy(h_ptr, d_ptr, size, cudaMemcpyDeviceToHost));
    }

    template<typename T> static void memcpy_device_to_device(T* d_ptr_0, T* d_ptr_1, size_t size)
    {
        if(!d_ptr_0 || !d_ptr_1 || (size == 0)) return;
        check_cuda_errors(cudaMemcpy(d_ptr_0, d_ptr_1, size, cudaMemcpyDeviceToHost));
    }

    float* host_allocate_device_memory(size_t size)
    {
        return allocate_device_memory<float>(size);
    }

    float* host_allocate_host_memory(size_t size)
    {
        return allocate_host_memory<float>(size);
    }

    void host_destroy_device_memory(float* d_ptr)
    {
        destroy_device_memory<float>(d_ptr);
    }

    void host_destroy_host_memory(float* h_ptr)
    {
        destroy_host_memory<float>(h_ptr);
    }

    void host_memcpy_device_to_host(float* h_ptr, float* d_ptr, size_t size)
    {
        memcpy_device_to_host<float>(h_ptr, d_ptr, size);
    }

    void host_memcpy_device_to_device(float* d_ptr_0, float* d_ptr_1, size_t size)
    {
        memcpy_device_to_device<float>(d_ptr_0, d_ptr_1, size);
    }

    void call_test_pattern_julia_set_kernel(void* user_stream, float* d_rgba_fb, uint32_t x_resolution, uint32_t y_resolution, float c0, float c1, float c2, float real, float imag)
    {
        magik::kernels::launch_test_pattern_julia_set(user_stream, d_rgba_fb, x_resolution, y_resolution, 16, 16, c0, c1, c2, real, imag);
    }

    void set_cuda_device(uint32_t cuda_device)
    {
        check_cuda_errors(cudaSetDevice(cuda_device));
    }

    void host_allocate_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, uint32_t* gl_buffer_id, void** cuda_resource)
    {
        magik::interops::allocate_gl_buffer(x_resolution, y_resolution, channels, gl_buffer_id, cuda_resource);
        check_magik_errors(magik_get_last_error());
    }

    void host_free_gl_buffer(uint32_t* gl_buffer_id, void** cuda_resource)
    {
        magik::interops::free_gl_buffer(gl_buffer_id, cuda_resource);
        check_magik_errors(magik_get_last_error());
    }

    void host_map_cuda_to_gl_buffer(const uint32_t x_resolution, const uint32_t y_resolution, const uint32_t channels, void** cuda_resource, float* d_ptr)
    {
        magik::interops::map_cuda_to_gl_buffer(x_resolution, y_resolution, channels, cuda_resource, d_ptr);
        check_magik_errors(magik_get_last_error());
    }

    void host_create_cuda_stream(void** user_stream)
    {
        cudaStream_t d_stream;
        check_cuda_errors(cudaStreamCreateWithFlags(&d_stream, cudaStreamNonBlocking));
        *user_stream = static_cast<void*>(d_stream);
    }

    void host_destroy_cuda_stream(void** user_stream)
    {
        check_cuda_errors(cudaStreamDestroy(static_cast<cudaStream_t>(*user_stream)));
    }

    void host_cuda_semaphore(void** user_stream)
    {
        /*
        * 
        * So the idea, as far as i understand it, is that the stream syncs kernel launches. 
        * If kernels A and B are launched in order using the same stream, they will execute
        * in that order. But we dont need to invoke the cudaDeviceSync function each time 
        * the kernel is launched. Instead we can rapid fire all of them at once, then put 
        * the semaphore at the end of the worker thread to make sure there are no race 
        * conditions. 
        * 
        */

        check_cuda_errors(cudaStreamSynchronize(static_cast<cudaStream_t>(*user_stream)));
    }
}
