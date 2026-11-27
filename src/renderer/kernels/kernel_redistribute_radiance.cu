#include "kernel_redistribute_radiance.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_color_utilities.cuh"
#include "device_sensor_utilities.cuh"
#include "stage.h"

namespace magik
{
    struct kernel_redistribute_radiance_args_t
    {
        uint32_t* d_redistribute_queue_count = nullptr;
        uint32_t* d_redistribute_queue_id = nullptr;
        uint32_t* d_complete_queue_count = nullptr;
        uint32_t* d_complete_queue_id = nullptr;
        float* d_spectral_radiance = nullptr;
        float* d_throughput = nullptr;
        float* d_intrinsic_spectral_irradiance = nullptr;
        float* d_sensor_wavelength_nm = nullptr;

        float isi_max_wavelength_nm;
        float isi_min_wavelength_nm;
        float redistribution_standard_deviation_nm;
        float sensor_diagonal_mm;
        float sensor_resolution_x;
        float sensor_resolution_y;
        float iso;
        float fps;
        float shutter_angle;
        uint32_t n_isi_bin;

        __host__ void create(wavefront_buffer_t& wavefront_buffer, stage_t& stage)
        {
            d_redistribute_queue_count = wavefront_buffer.queue_pool.get_count_ptr<redistribute_queue_t>();
            d_redistribute_queue_id = wavefront_buffer.queue_pool.get_id_ptr<redistribute_queue_t>();
            d_complete_queue_count = wavefront_buffer.queue_pool.get_count_ptr<complete_queue_t>();
            d_complete_queue_id = wavefront_buffer.queue_pool.get_id_ptr<complete_queue_t>();
            d_spectral_radiance = wavefront_buffer.ray_pool.get<spectral_radiance_t>();
            d_throughput = wavefront_buffer.ray_pool.get<throughput_t>();
            d_intrinsic_spectral_irradiance = wavefront_buffer.ray_pool.get<intrinsic_spectral_irradiance_t>();
            d_sensor_wavelength_nm = wavefront_buffer.ray_pool.get<sensor_wavelength_nm_t>();

            isi_max_wavelength_nm = stage.color_settings.isi_max_wavelength_nm;
            isi_min_wavelength_nm = stage.color_settings.isi_min_wavelength_nm;
            redistribution_standard_deviation_nm = stage.color_settings.redistribution_standard_deviation_nm;
            sensor_diagonal_mm = stage.optical_system_settings.sensor_diagonal_mm;
            sensor_resolution_x = static_cast<float>(stage.optical_system_settings.x_resolution);
            sensor_resolution_y = static_cast<float>(stage.optical_system_settings.y_resolution);
            iso = stage.optical_system_settings.iso;
            fps = stage.optical_system_settings.fps;
            shutter_angle = stage.optical_system_settings.shutter_angle;
            n_isi_bin = stage.color_settings.n_isi_bin;
        }
    };

    __global__ static void kernel_redistribute_radiance(kernel_redistribute_radiance_args_t args)
    {
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *args.d_redistribute_queue_count) return;
        uint32_t ray_id = args.d_redistribute_queue_id[queue_index];

        float spectral_radiance = args.d_spectral_radiance[ray_id];
        float throughput = args.d_throughput[ray_id];

        if((spectral_radiance > 0.0f) && (throughput > 0.0f))
        {
            float inv_b = compute_inv_b(args.sensor_diagonal_mm, args.sensor_resolution_x, args.sensor_resolution_y);
            float sensor_width_mm = args.sensor_resolution_x * inv_b;
            float sensor_height_mm = args.sensor_resolution_y * inv_b;
            float sensor_wavelength_nm = args.d_sensor_wavelength_nm[ray_id];
            size_t spectral_irradiance_id = (size_t)ray_id * args.n_isi_bin;

            float wavelength_range_in_bin_nm = (args.isi_max_wavelength_nm - args.isi_min_wavelength_nm) / static_cast<float>(args.n_isi_bin);
            float x1 = args.isi_min_wavelength_nm;
            float x2 = args.isi_min_wavelength_nm + wavelength_range_in_bin_nm;
            float sampled_irradiance = radiance_to_irradiance({spectral_radiance, throughput, sensor_width_mm, sensor_height_mm, args.iso, args.fps, args.shutter_angle, static_cast<uint32_t>(args.sensor_resolution_x), static_cast<uint32_t>(args.sensor_resolution_y)});
            float x_stored_irradiance = 0.0f;

            for(size_t i = 0; i < args.n_isi_bin; i++)
            {
                x_stored_irradiance = args.d_intrinsic_spectral_irradiance[spectral_irradiance_id + i];
                x_stored_irradiance += sampled_irradiance * (magik::norm_gaussian_cdf(sensor_wavelength_nm, x2, args.redistribution_standard_deviation_nm) - magik::norm_gaussian_cdf(sensor_wavelength_nm, x1, args.redistribution_standard_deviation_nm));
                /* Intrinsic sensor response function goes here */ 
                args.d_intrinsic_spectral_irradiance[spectral_irradiance_id + i] = x_stored_irradiance;

                x1 += wavelength_range_in_bin_nm;
                x2 += wavelength_range_in_bin_nm;
            }
        }

        uint32_t slot = atomicAdd(args.d_complete_queue_count, 1);
        args.d_complete_queue_id[slot] = ray_id;
    }

    void launch_kernel_redistribute_radiance_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, stage_t& stage)
    {
        uint32_t threads_per_block = stage.render_settings.wavefront_threads_per_block;
        uint32_t n_block = (wavefront_buffer.queue_ceiling + threads_per_block - 1) / threads_per_block;

        kernel_redistribute_radiance_args_t args;
        args.create(wavefront_buffer, stage);

        kernel_redistribute_radiance<<<n_block, threads_per_block, 0, user_stream>>>(args);
        check_cuda_errors(cudaGetLastError());

        wavefront_buffer.queue_pool.store_count_in_history<redistribute_queue_t>(user_stream, wavefront_buffer.iteration, stage.render_settings.n_geodesic_step_limit);
        wavefront_buffer.queue_pool.zero_count_async<redistribute_queue_t>(user_stream);
    }
}
