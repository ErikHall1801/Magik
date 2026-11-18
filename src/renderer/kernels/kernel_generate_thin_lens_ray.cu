#include "kernel_generate_thin_lens_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_sensor_utilities.cuh"
#include "wavelength_sampler.cuh"
#include "thin_lens.cuh"

namespace magik
{
    struct kernel_generate_thin_lens_ray_args_t
    {
        curandState_t* d_random_device = nullptr;
        vec4f* d_initial_observer_spatial_direction = nullptr;
        vec4f* d_initial_observer_spatial_position = nullptr;
        float* d_sensor_wavelength_nm = nullptr;
        float* d_monte_carlo_weight = nullptr;
        uint32_t* d_advance_A_queue_id = nullptr;

        uint32_t x_resolution;
        uint32_t y_resolution;
        float max_wavelength_nm;
        float min_wavelength_nm;
        float focal_length;
        float sensor_diagonal_mm;
        vec3f position;
        mat3f orientation;

        __host__ void create(magik_render_manager* manager, wavefront_buffer_t* wb)
        {
            d_random_device = wb->ray_pool.get<random_device_t>();
            d_initial_observer_spatial_direction = wb->ray_pool.get<initial_observer_spatial_direction_t>();
            d_initial_observer_spatial_position = wb->ray_pool.get<initial_observer_spatial_position_t>();
            d_sensor_wavelength_nm = wb->ray_pool.get<sensor_wavelength_nm_t>();
            d_monte_carlo_weight = wb->ray_pool.get<monte_carlo_weight_t>();
            d_advance_A_queue_id = wb->queue_pool.get_id_ptr<advance_A_queue_t>();

            x_resolution = wb->x_resolution;
            y_resolution = wb->y_resolution;
            max_wavelength_nm = manager->stage.settings.max_wavelength_nm;
            min_wavelength_nm = manager->stage.settings.min_wavelength_nm;
            focal_length = manager->stage.optical_systen.focal_length;
            sensor_diagonal_mm = manager->stage.optical_systen.sensor_diagonal_mm;
            position = manager->stage.optical_systen.position;
            orientation = manager->stage.optical_systen.orientation;
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

        draw_random_wavelength_uniform(&args.d_sensor_wavelength_nm[thread_id], &args.d_monte_carlo_weight[thread_id], args.max_wavelength_nm, args.min_wavelength_nm, &args.d_random_device[thread_id]);

        args.d_advance_A_queue_id[thread_id] = thread_id;
    }

    void launch_kernel_generate_thin_lens_ray_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        dim3 threads_per_block = dim3(manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y, 1);
        dim3 n_block = magik::compute_n_blocks(wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y);

        kernel_generate_thin_lens_ray_args_t args;
        args.create(manager, wavefront_buffer);

        kernel_generate_thin_lens_ray<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(args);
        check_cuda_errors(cudaGetLastError());
    }
}
