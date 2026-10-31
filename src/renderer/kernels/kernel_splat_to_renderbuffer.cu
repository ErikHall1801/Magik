#include "kernel_splat_to_renderbuffer.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_spectral_utilities.cuh"

namespace magik
{
    static __global__ void kernel_splat_to_renderbuffer(ray_pool_t ray_pool, ray_queue_t splat_queue, float* d_renderbuffer, uint32_t n_spectral_irradiance_bin, float max_wavelength_nm, float min_wavelength_nm, uint32_t x_sample)
    {
        /*
        Now, a couple of things change.
        - This kernel is now async and part of the wavefront, so we have to write the queue to the x*y renderbuffer ! Not too bad, the ray_id tells us where to write. 
        - We also use this kernel to encapsulate the whole color pipeline. Spectral -> CIE XYZ -> Color Space -> Tonemapping. So once OCIO is integrated it will work here. 
        */

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *splat_queue.d_count) return;
        uint32_t ray_id = splat_queue.d_id[queue_index];

        vec3f linear_color = spectral_irradiance_to_cie_xyz(&ray_pool.d_intrinsic_spectral_irradiance[ray_id], n_spectral_irradiance_bin, ray_pool.d_sensor_wavelength_nm[ray_id], max_wavelength_nm, min_wavelength_nm, x_sample);

        d_renderbuffer[ray_id + 0] = linear_color.x;
        d_renderbuffer[ray_id + 1] = linear_color.y;
        d_renderbuffer[ray_id + 2] = linear_color.z;
    }

    void launch_kernel_splat_to_renderbuffer_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer, float* d_renderbuffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((buffer->x_resolution*buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_splat_to_renderbuffer<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(buffer->ray_pool, buffer->splat_queue, d_renderbuffer, manager->stage.settings.n_spectral_irradiance_bin, manager->stage.settings.max_wavelength_nm, manager->stage.settings.min_wavelength_nm, manager->x_sample.load(std::memory_order_acquire));
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(buffer->splat_queue.d_count, &manager->cuda_stream);
    }
}
