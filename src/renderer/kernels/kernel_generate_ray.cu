#include "kernel_generate_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"
#include "device_sensor_utilities.cuh"

namespace magik
{
    static __global__ void kernel_generate_ray(vec3f* d_pos, vec3f* d_dir, ray_queue_t advance_queue, curandState_t* d_random_device, uint32_t x_resolution, uint32_t y_resolution, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {
        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);

        // Logic for making the ray dir and orig. 
        vec3f ray_dir, ray_orig;

        vec3f sensor_position = generate_z_aligned_sensor_position(sensor_diagonal_mm, x_resolution, y_resolution, &d_random_device[thread_id]) - vec3f{0.0f, 0.0f, focal_length/1000.0f};
        ray_dir = sensor_position.norm();
        ray_orig = sensor_position;

        // To world space
        ray_orig = orientation * ray_orig;
        ray_orig += position;
        ray_dir = orientation * ray_dir;

        d_dir[thread_id] = ray_dir;
        d_pos[thread_id] = ray_orig;

        advance_queue.d_id[thread_id] = thread_id;
    }

    void launch_kernel_generate_ray_async(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, wavefront_ray_buffer_t* buffer, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::compute_n_blocks(buffer->x_resolution, buffer->y_resolution, x_threads_per_block, y_threads_per_block);

        kernel_generate_ray<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(buffer->ray_pool.d_pos, buffer->ray_pool.d_dir, buffer->advance_queue_A, buffer->ray_pool.d_random_device, buffer->x_resolution, buffer->y_resolution, focal_length, sensor_diagonal_mm, position, orientation);
        check_cuda_errors(cudaGetLastError());
    }
}
