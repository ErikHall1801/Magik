#include "kernel_generate_thin_lens_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_sensor_utilities.cuh"
#include "thin_lens.cuh"

namespace magik
{
    struct kernel_generate_thin_lens_ray_args_t
    {
        curandState_t* d_random_device = nullptr;
        vec4f* d_initial_observer_spatial_direction = nullptr;
        vec4f* d_initial_observer_spatial_position = nullptr;
        float* d_sensor_wavelength_nm = nullptr;
        float* d_throughput = nullptr;
        uint32_t* d_advance_A_queue_id = nullptr;

        uint32_t x_resolution;
        uint32_t y_resolution;
        float max_wavelength_nm;
        float min_wavelength_nm;
        float focal_length;
        float sensor_diagonal_mm;
        vec3f position;
        mat3f orientation;

        color_pipeline_descriptor_t color_pipeline_descriptor;

        __host__ void create(wavefront_buffer_t& wavefront_buffer, stage_t& stage, color_pipeline_descriptor_t& color_pipeline_descriptor)
        {
            d_random_device = wavefront_buffer.ray_pool.get<random_device_t>();
            d_initial_observer_spatial_direction = wavefront_buffer.ray_pool.get<initial_observer_spatial_direction_t>();
            d_initial_observer_spatial_position = wavefront_buffer.ray_pool.get<initial_observer_spatial_position_t>();
            d_sensor_wavelength_nm = wavefront_buffer.ray_pool.get<sensor_wavelength_nm_t>();
            d_throughput = wavefront_buffer.ray_pool.get<throughput_t>();
            d_advance_A_queue_id = wavefront_buffer.queue_pool.get_id_ptr<advance_A_queue_t>();

            x_resolution = wavefront_buffer.x_resolution;
            y_resolution = wavefront_buffer.y_resolution;
            max_wavelength_nm = stage.color_settings.isi_max_wavelength_nm;
            min_wavelength_nm = stage.color_settings.isi_min_wavelength_nm;
            focal_length = stage.optical_system_settings.focal_length;
            sensor_diagonal_mm = stage.optical_system_settings.sensor_diagonal_mm;
            position = stage.optical_system_settings.position;
            orientation = stage.optical_system_settings.orientation;

            color_pipeline_descriptor = color_pipeline_descriptor;
        }
    };

    static __global__ void kernel_generate_thin_lens_ray(kernel_generate_thin_lens_ray_args_t args)
    {
        if(!magik::is_valid_thread(args.x_resolution, args.y_resolution)) return;

        uint32_t thread_id = magik::get_n_dimensional_thread_id(args.x_resolution, 1);

        // Logic for making the ray dir and orig. 
        vec3f ray_dir, ray_orig;

        vec3f sensor_pos = generate_z_aligned_sensor_position(args.sensor_diagonal_mm, args.x_resolution, args.y_resolution, &args.d_random_device[thread_id]);
        vec3f sensor_dir = vec3f{0.0f, 0.0f, -1.0f};

        magik::generate_thin_lens_ray(&ray_dir, &ray_orig, sensor_dir, sensor_pos, args.focal_length);

        // To world space
        ray_orig = args.orientation * ray_orig;
        ray_orig += args.position;

        args.d_initial_observer_spatial_direction[thread_id] = vec4f{ray_dir.x, ray_dir.y, ray_dir.z, 0.0f};
        args.d_initial_observer_spatial_position[thread_id] = vec4f{ray_orig.x, ray_orig.y, ray_orig.z, 0.0f};

        float pdf; // Setting for the sampling strategy ? 
        draw_random_wavelength_cmf_inverse_cdf(&args.d_sensor_wavelength_nm[thread_id], &pdf, args.color_pipeline_descriptor, &args.d_random_device[thread_id]);
        args.d_throughput[thread_id] = 1.0f / pdf;

        args.d_advance_A_queue_id[thread_id] = thread_id;
    }

    void launch_kernel_generate_thin_lens_ray_async(wavefront_buffer_t& wavefront_buffer, cudaStream_t user_stream, stage_t& stage, color_pipeline_descriptor_t& color_pipeline_descriptor)
    {
        dim3 threads_per_block = dim3(stage.render_settings.threads_per_block_x, stage.render_settings.threads_per_block_y, 1);
        dim3 n_block = magik::compute_n_blocks(wavefront_buffer.x_resolution, wavefront_buffer.y_resolution, stage.render_settings.threads_per_block_x, stage.render_settings.threads_per_block_y);

        kernel_generate_thin_lens_ray_args_t args;
        args.create(wavefront_buffer, stage, color_pipeline_descriptor);

        kernel_generate_thin_lens_ray<<<n_block, threads_per_block, 0, user_stream>>>(args);
        check_cuda_errors(cudaGetLastError());
    }
}
