#include "kernel_generate_ray.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __device__ vec2f generate_screen_uv_coordinates(uint32_t x_resolution, uint32_t y_resolution)
    {
        int x_abs = threadIdx.x + blockIdx.x * blockDim.x;
        int y_abs = threadIdx.y + blockIdx.y * blockDim.y;

        float x_norm = -((float(x_abs) / float(x_resolution)) - 0.5f);
        float y_norm = -(float(y_abs) / float(y_resolution) - 0.5f);

        float u = x_norm;
        float v = y_norm;
        float ratio = float(y_resolution) / float(x_resolution);

        if (ratio < 1.0)
        {
            v *= ratio;
        }
        else
        {
            u /= ratio;
        }

        return vec2f{u, v };
    }

    static __device__ float compute_inv_b(float diagonal_mm, uint32_t y_resolution, uint32_t x_resolution)
    {
        return diagonal_mm / sqrtf(static_cast<float>(x_resolution * x_resolution + y_resolution * y_resolution));
    }

    static __device__ vec3f generate_z_aligned_sensor_position(float diagonal_mm, uint32_t x_resolution, uint32_t y_resolution)
    {
        float inv_s = compute_inv_b(diagonal_mm, x_resolution, y_resolution);
        float width_mm = x_resolution * inv_s;
        float height_mm = y_resolution * inv_s;

        float num_of_pixels = static_cast<float>(x_resolution * y_resolution);
        float area_of_sensor = (width_mm * height_mm) / 1E6f;
        float pixel_side_length = sqrtf(area_of_sensor / num_of_pixels);
        float ju = 0.0f; // (curand_uniform(&thread_random_device) - 0.5f) * pixel_side_length;
        float jv = 0.0f; // (curand_uniform(&thread_random_device) - 0.5f) * pixel_side_length;

        vec2f uv = generate_screen_uv_coordinates(x_resolution, y_resolution);

        return vec3f{ ((-uv.x * diagonal_mm) / 1000.0f) + ju, ((-uv.y * diagonal_mm) / 1000.0f) + jv, 0.0f }; // uv is flipped because the ideal and physical cameras naturally flip the render
    }

    static __global__ void kernel_generate_ray(vec3f* d_pos, vec3f* d_dir, ray_queue_t advance_queue, uint32_t x_resolution, uint32_t y_resolution, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {
        /*
        What i need to figure out is how to get the thread id here. How do we launch a flat kernel, so to speak. 

        Let's consider "is_valid_thread"
        Even that is not clear to me, do we just use the thread id directly ? 
        We still need the x and y resolutions ! So we can compute i_x and i_y ? 

        So, what do we actually need to check ? 
        1. The thread is valid
        2. The thread 

        Wait, do we actually need to check the count ? Not really. We launch d_count many threads. Which have 
        basically random id's. So, we have to check if the thread is valid, using x and y resolution. Then 
        we can fetch the ray id, which tells us where it sits in the image. Which raises an interesting question,
        what is the ray id ? Well, its the index into the ray pool. 

        So, this thread_id we have just computed is ideally 0 - d_count. Which means now we can index into the d_id
        array and figure out which ray this one works at. 
        Not so fast. Remember, this kernel runs for all rays. It just puts their id´s into the queue. So actually, 
        we can put the thread_id into the queue ? Wait what. Yeah this is the atomic add. We have to fetch the 
        count, put the thread_id there and increment it. 
        The logic of this kernel will be pretty reusable for the sensor position & direction, though we will have to 
        consider how this works with the lens sim. Should that be a part of the main loop ? 
        */

        if(!magik::is_valid_thread(x_resolution, y_resolution)) return;

        uint32_t i_x = threadIdx.x + blockIdx.x * blockDim.x;
        uint32_t i_y = threadIdx.y + blockIdx.y * blockDim.y;
        uint32_t thread_id = magik::get_n_dimensional_thread_id(x_resolution, 1);

        // Logic for making the ray dir and orig. 
        vec3f ray_dir, ray_orig;

        vec3f sensor_position = generate_z_aligned_sensor_position(sensor_diagonal_mm, x_resolution, y_resolution) - vec3f{0.0f, 0.0f, focal_length/1000.0f};
        ray_dir = sensor_position.norm();
        ray_orig = sensor_position;

        // To world space
        ray_orig = orientation * ray_orig;
        ray_orig += position;
        ray_dir = orientation * ray_dir;

        d_dir[thread_id] = ray_dir;
        d_pos[thread_id] = ray_orig;

        // This is not actually needed here. We can just initalize the advance_queue count to the number of pixels 
        // uint32_t slot = atomicAdd(advance_queue.d_count, 1); // Right this works because we are returning the old value of d_count, but incrementing it by 1. 
        // advance_queue.d_id[slot] = thread_id; // Now it is save to access because we know no other thread will look at this slot. 
        advance_queue.d_id[thread_id] = thread_id;
    }

    void launch_kernel_generate_ray_async(void** user_stream, uint32_t x_threads_per_block, uint32_t y_threads_per_block, wavefront_ray_buffer_t* buffer, float focal_length, float sensor_diagonal_mm, vec3f position, mat3f orientation)
    {
        dim3 threads_per_block = dim3(x_threads_per_block, y_threads_per_block, 1);
        dim3 n_block = magik::compute_n_blocks(buffer->x_resolution, buffer->y_resolution, x_threads_per_block, y_threads_per_block);

        kernel_generate_ray<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(*user_stream)>>>(buffer->ray_pool.d_pos, buffer->ray_pool.d_dir, buffer->advance_queue_A, buffer->x_resolution, buffer->y_resolution, focal_length, sensor_diagonal_mm, position, orientation);
        check_cuda_errors(cudaGetLastError());
    }
}
