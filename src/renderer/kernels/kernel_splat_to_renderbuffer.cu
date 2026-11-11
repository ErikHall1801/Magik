#include "kernel_splat_to_renderbuffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_spectral_utilities.cuh"

namespace magik
{
    struct kernel_splat_to_renderbuffer_t
    {
        float* d_intrinsic_spectral_irradiance;
        uint32_t* d_splat_queue_count;
        uint32_t* d_splat_queue_id;
        float* d_renderbuffer;
        
        uint32_t n_spectral_irradiance_bin;
        float max_wavelength_nm;
        float min_wavelength_nm;
        uint32_t x_sample;

        __host__ void create(magik_render_manager* manager, wavefront_buffer_t* wb, float* d_target_buffer)
        {
            d_intrinsic_spectral_irradiance = wb->ray_pool.get<intrinsic_spectral_irradiance_t>();
            d_splat_queue_count = wb->queue_pool.get_count_ptr<splat_queue_t>();
            d_splat_queue_id = wb->queue_pool.get_id_ptr<splat_queue_t>();
            d_renderbuffer = d_target_buffer;

            n_spectral_irradiance_bin = manager->stage.settings.n_spectral_irradiance_bin;
            max_wavelength_nm = manager->stage.settings.max_wavelength_nm;
            min_wavelength_nm = manager->stage.settings.min_wavelength_nm;
            x_sample = manager->x_sample.load(std::memory_order_acquire);
        }
    };

    static __global__ void kernel_splat_to_renderbuffer(kernel_splat_to_renderbuffer_t args)
    {
        /*
        This kernel will eventually include the entire color pipeline, such as OCIO-generated functions. 
        */

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_splat_queue_count) return;
        uint32_t ray_id = args.d_splat_queue_id[queue_index];

        vec3f linear_color = spectral_irradiance_to_cie_xyz(&args.d_intrinsic_spectral_irradiance[(size_t)ray_id * args.n_spectral_irradiance_bin], args.n_spectral_irradiance_bin, args.max_wavelength_nm, args.min_wavelength_nm, args.x_sample);

        args.d_renderbuffer[ray_id * 3 + 0] = linear_color.x;
        args.d_renderbuffer[ray_id * 3 + 1] = linear_color.y;
        args.d_renderbuffer[ray_id * 3 + 2] = linear_color.z;
    }

    void launch_kernel_splat_to_renderbuffer_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer, float* d_renderbuffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_splat_to_renderbuffer_t args;
        args.create(manager, wavefront_buffer, d_renderbuffer);

        kernel_splat_to_renderbuffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(args);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<splat_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
