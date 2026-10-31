#include "kernel_redistribute_radiance.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_spectral_utilities.cuh"
#include "device_sensor_utilities.cuh"

namespace magik
{
    __global__ static void kernel_redistribute_radiance(ray_pool_t ray_pool, ray_queue_t redistribute_queue, ray_queue_t splat_queue, float max_wavelength_nm, float min_wavelength_nm, float redistribution_standard_deviation, float sensor_diagonal_mm, float sensor_resolution_x, float sensor_resolution_y, uint32_t n_spectral_irradiance_bin)
    {
        // Reads "redistribute queue"
        // Writes "splat queue"
        // Well what does this write too ? The idea is that any ray in the redistribute queue is kill. 
        // The question really is if we can put the splat kernel into the wavefront as well. Because
        // that too can easily be async. Yeah, this works fine. We can even put the color kernel there. 
        // Since, again, that can be async here. 
        // We keep this one seperate because, in the future, the work done in here will get more complicated
        // when sensor responsens and what not. 

        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *redistribute_queue.d_count) return;
        uint32_t ray_id = redistribute_queue.d_id[queue_index];

        float spectral_radiance = ray_pool.d_spectral_radiance[ray_id];
        float monte_carlo_weight = ray_pool.d_monte_carlo_weight[ray_id];

        if((spectral_radiance > 0.0f) && (monte_carlo_weight > 0.0f))
        {
            float inv_b = compute_inv_b(sensor_diagonal_mm, sensor_resolution_x, sensor_resolution_y);

            redistribute_spectral_radiance_t args;
            args.d_spectral_irradiance = ray_pool.d_intrinsic_spectral_irradiance;
            args.spectral_radiance = spectral_radiance;
            args.monte_carlo_weight = monte_carlo_weight;
            args.sensor_wavelength_nm = ray_pool.d_sensor_wavelength_nm[ray_id];
            args.max_wavelength_nm = max_wavelength_nm;
            args.min_wavelength_nm = min_wavelength_nm;
            args.redistribution_standard_deviation = redistribution_standard_deviation;
            args.sensor_width_mm = sensor_resolution_x * inv_b;
            args.sensor_height_mm = sensor_resolution_y * inv_b;
            args.sensor_resolution_x = sensor_resolution_x;
            args.sensor_resolution_y = sensor_resolution_y;
            args.n_spectral_irradiance_bin = n_spectral_irradiance_bin;

            redistribute_spectral_radiance(&args);
        }

        uint32_t slot = atomicAdd(splat_queue.d_count, 1);
        splat_queue.d_id[slot] = ray_id;
    }

    void launch_kernel_redistribute_radiance_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((buffer->x_resolution*buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_redistribute_radiance<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(buffer->ray_pool, buffer->redistribute_queue, buffer->splat_queue, manager->stage.settings.max_wavelength_nm, manager->stage.settings.min_wavelength_nm, manager->stage.settings.redistribution_standard_deviation, manager->stage.optical_systen.sensor_diagonal_mm, manager->stage.optical_systen.x_resolution, manager->stage.optical_systen.y_resolution, manager->stage.settings.n_spectral_irradiance_bin);
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(buffer->redistribute_queue.d_count, &manager->cuda_stream);
    }
}
