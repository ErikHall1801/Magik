#include "kernel_splat_to_renderbuffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_spectral_utilities.cuh"

namespace magik
{
    static __global__ void kernel_splat_to_renderbuffer(float* d_intrinsic_spectral_irradiance, uint32_t* d_splat_queue_count, uint32_t* d_splat_queue_id, float* d_renderbuffer, uint32_t n_spectral_irradiance_bin, float max_wavelength_nm, float min_wavelength_nm, uint32_t x_sample)
    {
        /*
        This kernel will eventually include the entire color pipeline, such as OCIO-generated functions. 
        */

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *d_splat_queue_count) return;
        uint32_t ray_id = d_splat_queue_id[queue_index];

        vec3f linear_color = spectral_irradiance_to_cie_xyz(&d_intrinsic_spectral_irradiance[(size_t)ray_id * n_spectral_irradiance_bin], n_spectral_irradiance_bin, max_wavelength_nm, min_wavelength_nm, x_sample);

        d_renderbuffer[ray_id * 3 + 0] = linear_color.x;
        d_renderbuffer[ray_id * 3 + 1] = linear_color.y;
        d_renderbuffer[ray_id * 3 + 2] = linear_color.z;
    }

    void launch_kernel_splat_to_renderbuffer_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer, float* d_renderbuffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        uint32_t* d_splat_queue_count = wavefront_buffer->queue_pool.get_count_ptr<splat_queue_t>();
        uint32_t* d_splat_queue_id = wavefront_buffer->queue_pool.get_id_ptr<splat_queue_t>();

        float* d_intrinsic_spectral_irradiance = wavefront_buffer->ray_pool.get<intrinsic_spectral_irradiance_t>();

        kernel_splat_to_renderbuffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_intrinsic_spectral_irradiance, d_splat_queue_count, d_splat_queue_id, d_renderbuffer, manager->stage.settings.n_spectral_irradiance_bin, manager->stage.settings.max_wavelength_nm, manager->stage.settings.min_wavelength_nm, manager->x_sample.load(std::memory_order_acquire));
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.zero_count_async<splat_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
