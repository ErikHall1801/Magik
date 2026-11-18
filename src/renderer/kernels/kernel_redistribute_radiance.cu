#include "kernel_redistribute_radiance.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_color_utilities.cuh"
#include "device_sensor_utilities.cuh"

namespace magik
{
    struct kernel_redistribute_radiance_args_t
    {
        uint32_t* d_redistribute_queue_count = nullptr;
        uint32_t* d_redistribute_queue_id = nullptr;
        uint32_t* d_splat_queue_count = nullptr;
        uint32_t* d_splat_queue_id = nullptr;
        float* d_spectral_radiance = nullptr;
        float* d_monte_carlo_weight = nullptr;
        float* d_intrinsic_spectral_irradiance = nullptr;
        float* d_sensor_wavelength_nm = nullptr;

        float max_wavelength_nm;
        float min_wavelength_nm;
        float redistribution_standard_deviation;
        float sensor_diagonal_mm;
        float sensor_resolution_x;
        float sensor_resolution_y;
        uint32_t n_spectral_irradiance_bin;

        __host__ void create(magik_render_manager* manager, wavefront_buffer_t* wb)
        {
            d_redistribute_queue_count = wb->queue_pool.get_count_ptr<redistribute_queue_t>();
            d_redistribute_queue_id = wb->queue_pool.get_id_ptr<redistribute_queue_t>();
            d_splat_queue_count = wb->queue_pool.get_count_ptr<splat_queue_t>();
            d_splat_queue_id = wb->queue_pool.get_id_ptr<splat_queue_t>();
            d_spectral_radiance = wb->ray_pool.get<spectral_radiance_t>();
            d_monte_carlo_weight = wb->ray_pool.get<monte_carlo_weight_t>();
            d_intrinsic_spectral_irradiance = wb->ray_pool.get<intrinsic_spectral_irradiance_t>();
            d_sensor_wavelength_nm = wb->ray_pool.get<sensor_wavelength_nm_t>();

            max_wavelength_nm = manager->stage.settings.max_wavelength_nm;
            min_wavelength_nm = manager->stage.settings.min_wavelength_nm;
            redistribution_standard_deviation = manager->stage.settings.redistribution_standard_deviation;
            sensor_diagonal_mm = manager->stage.optical_systen.sensor_diagonal_mm;
            sensor_resolution_x = static_cast<float>(manager->stage.optical_systen.x_resolution);
            sensor_resolution_y = static_cast<float>(manager->stage.optical_systen.y_resolution);
            n_spectral_irradiance_bin = manager->stage.settings.n_spectral_irradiance_bin;
        }
    };

    __global__ static void kernel_redistribute_radiance(kernel_redistribute_radiance_args_t args)
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
        if(queue_index >= *args.d_redistribute_queue_count) return;
        uint32_t ray_id = args.d_redistribute_queue_id[queue_index];

        float spectral_radiance = args.d_spectral_radiance[ray_id];
        float monte_carlo_weight = args.d_monte_carlo_weight[ray_id];

        if((spectral_radiance > 0.0f) && (monte_carlo_weight > 0.0f))
        {
            float inv_b = compute_inv_b(args.sensor_diagonal_mm, args.sensor_resolution_x, args.sensor_resolution_y);

            redistribute_spectral_radiance_args_t s_args;
            s_args.d_intrinsic_spectral_irradiance = args.d_intrinsic_spectral_irradiance;
            s_args.spectral_radiance = spectral_radiance;
            s_args.monte_carlo_weight = monte_carlo_weight;
            s_args.sensor_wavelength_nm = args.d_sensor_wavelength_nm[ray_id];
            s_args.isi_max_wavelength_nm = args.max_wavelength_nm;
            s_args.isi_min_wavelength_nm = args.min_wavelength_nm;
            s_args.redistribution_standard_deviation = args.redistribution_standard_deviation;
            s_args.sensor_width_mm = static_cast<float>(args.sensor_resolution_x) * inv_b;
            s_args.sensor_height_mm = static_cast<float>(args.sensor_resolution_y) * inv_b;
            s_args.iso = 1000.0f; 
            s_args.fps = 24.0f; 
            s_args.shutter_angle = 180.0f;
            s_args.ray_id = ray_id;
            s_args.sensor_resolution_x = args.sensor_resolution_x; 
            s_args.sensor_resolution_y = args.sensor_resolution_y;
            s_args.n_isi_spectral_irradiance_bin = args.n_spectral_irradiance_bin;

            redistribute_spectral_radiance(s_args);
        }

        uint32_t slot = atomicAdd(args.d_splat_queue_count, 1);
        args.d_splat_queue_id[slot] = ray_id;
    }

    void launch_kernel_redistribute_radiance_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer->queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_redistribute_radiance_args_t args;
        args.create(manager, wavefront_buffer);

        kernel_redistribute_radiance<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(args);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer->queue_pool.store_count_in_history<redistribute_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream), wavefront_buffer->iteration, manager->stage.settings.n_geodesic_step_limit);
        wavefront_buffer->queue_pool.zero_count_async<redistribute_queue_t>(static_cast<cudaStream_t>(manager->cuda_stream));
    }
}
