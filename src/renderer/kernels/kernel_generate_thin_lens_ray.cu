#include "kernel_generate_thin_lens_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_sensor_utilities.cuh"
#include "device_spectral_utilities.cuh"
#include "thin_lens.cuh"

namespace magik
{
    static __global__ void kernel_generate_thin_lens_ray(curandState_t* d_random_device, vec4f* d_dir, vec4f* d_pos, float* d_sensor_wavelength_nm, float* d_monte_carlo_weight, uint32_t* d_advance_queue_id, uint32_t x_resolution, uint32_t y_resolution, float max_wavelength_nm, float min_wavelength_nm, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);

        // Logic for making the ray dir and orig. 
        vec3f ray_dir, ray_orig;

        vec3f sensor_pos = generate_z_aligned_sensor_position(sensor_diagonal_mm, x_resolution, y_resolution, &d_random_device[thread_id]);
        vec3f sensor_dir = vec3f{0.0f, 0.0f, -1.0f};

        magik::generate_thin_lens_ray(&ray_dir, &ray_orig, sensor_dir, sensor_pos, focal_length);

        // To world space
        ray_orig = orientation * ray_orig;
        ray_orig += position;
        ray_dir = orientation * ray_dir;

        d_dir[thread_id] = vec4f{ray_dir.x, ray_dir.y, ray_dir.z, 0.0f};
        d_pos[thread_id] = vec4f{ray_orig.x, ray_orig.y, ray_orig.z, 0.0f};

        // draw_random_wavelength_cie_1931_weighted(&d_sensor_wavelength_nm[thread_id], &d_monte_carlo_weight[thread_id], max_wavelength_nm, min_wavelength_nm, &d_random_device[thread_id]);
        draw_random_wavelength_uniform(&d_sensor_wavelength_nm[thread_id], &d_monte_carlo_weight[thread_id], max_wavelength_nm, min_wavelength_nm, &d_random_device[thread_id]);

        d_advance_queue_id[thread_id] = thread_id;
    }

    void launch_kernel_generate_thin_lens_ray_async(magik_render_manager* manager, wavefront_buffer_t* wavefront_buffer)
    {
        dim3 threads_per_block = dim3(manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y, 1);
        dim3 n_block = magik::compute_n_blocks(wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, manager->stage.settings.threads_per_block_x, manager->stage.settings.threads_per_block_y);

        curandState_t* d_random_device = wavefront_buffer->ray_pool.get<random_device_t>();
        vec4f* d_dir = wavefront_buffer->ray_pool.get<direction_t>();
        vec4f* d_pos = wavefront_buffer->ray_pool.get<position_t>();
        float* d_sensor_wavelength_nm = wavefront_buffer->ray_pool.get<sensor_wavelength_nm_t>();
        float* d_monte_carlo_weight = wavefront_buffer->ray_pool.get<monte_carlo_weight_t>();

        uint32_t* d_advance_A_queue_id = wavefront_buffer->queue_pool.get_id_ptr<advance_A_queue_t>();

        kernel_generate_thin_lens_ray<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(d_random_device, d_dir, d_pos, d_sensor_wavelength_nm, d_monte_carlo_weight, d_advance_A_queue_id, wavefront_buffer->x_resolution, wavefront_buffer->y_resolution, manager->stage.settings.max_wavelength_nm, manager->stage.settings.min_wavelength_nm, manager->stage.optical_systen.focal_length, manager->stage.optical_systen.sensor_diagonal_mm, manager->stage.optical_systen.position, manager->stage.optical_systen.orientation);
        check_cuda_errors(cudaGetLastError());
    }
}
