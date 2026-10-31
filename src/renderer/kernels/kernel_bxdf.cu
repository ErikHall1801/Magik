#include "kernel_bxdf.cuh"
#include "cuda_device_utilities.cuh"
#include "cuda_host_utilities.h"

namespace magik
{
    static __device__ vec3f random_unit_three_vector(curandState_t* random_device)
    {
        using ::sin;
        using ::cos;
        using ::acos;

        float u = curand_uniform(random_device);
        float theta = acos(1.0f - 2.0f*u);
        float phi = 2.0f*magik::pi*curand_uniform(random_device);

        vec3f p;
        p.x = cos(phi) * sin(theta);
        p.y = sin(phi) * sin(theta);
        p.z = cos(theta);
        return p;
    }

    static __device__ vec3f offset_origin(vec3f x, vec3f n)
    {
        /*
        CREDITS;

        https://github.com/Apress/ray-tracing-gems/blob/master/Ch_06_A_Fast_and_Robust_Method_for_Avoiding_Self-Intersection/offset_ray.cu

        To make the function transform the offset into the surface, simply negate the normal
        assuming the convention that the passed in normal always opposes the geodesics direction ! 
        */

        const float offset_scale = 4.0f;
        const float int_scale = 256.0f * offset_scale;
        const float float_scale = (1.0f / 65536.0f) * offset_scale;
        const float origin = 1.0f / 32.0f;

        int of_ix = int_scale*n.x;
        int of_iy = int_scale*n.y;
        int of_iz = int_scale*n.z;

        float p_ix = __int_as_float(__float_as_int(x.x) + ((x.x < 0) ? -of_ix : of_ix));
        float p_iy = __int_as_float(__float_as_int(x.y) + ((x.y < 0) ? -of_iy : of_iy));
        float p_iz = __int_as_float(__float_as_int(x.z) + ((x.z < 0) ? -of_iz : of_iz));

        return vec3f{   fabsf(x.x) < origin ? x.x+float_scale*n.x : p_ix,
                        fabsf(x.y) < origin ? x.y+float_scale*n.y : p_iy,
                        fabsf(x.z) < origin ? x.z+float_scale*n.z : p_iz };
    }

    static __global__ void kernel_bxdf(ray_pool_t ray_pool, ray_queue_t bxdf_queue, ray_queue_t advance_queue, ray_queue_t redistribute_queue)
    {
        // Reads "bxdf queue"
        // Writes "advance queue" or "redistribution queue"

        // 1. Fetch ray id
        uint32_t queue_index = blockIdx.x * blockDim.x + threadIdx.x;
        if(queue_index >= *bxdf_queue.d_count) return;
        uint32_t ray_id = bxdf_queue.d_id[queue_index];

        // 2. Fetch ray-specific data
        uint32_t hit_id = ray_pool.hit_id[ray_id];

        bool to_advance = false;

        // 3. Do work
        if(hit_id == 1)
        {
            // Box, reflect ray dir, offset ray orig, set "step distance" to 0, send to advance queue

            vec3f hit_normal = ray_pool.hit_normal[ray_id];
            vec3f hit_dir = ray_pool.d_dir[ray_id];

            vec3f outgoing_dir = random_unit_three_vector(&ray_pool.d_random_device[ray_id]);

            if(vector_dot_product(hit_dir, outgoing_dir) < 0.0f)
            {
                outgoing_dir *= -1.0f;
            }

            // vec3f outgoing_dir = magik::vector_reflect(hit_dir, hit_normal);
            vec3f new_orig = offset_origin(ray_pool.d_pos[ray_id], hit_normal);

            ray_pool.d_dir[ray_id] = outgoing_dir;
            ray_pool.d_pos[ray_id] = new_orig;
            ray_pool.d_step_distance[ray_id] = 0.0f;
            ray_pool.d_monte_carlo_weight[ray_id] *= 0.9f;

            to_advance = true;
        }
        else if(hit_id == 2)
        {
            // Light
            // ray_pool.d_spectral_radiance[ray_id] = magik::evaluate_sodium_vapor_lamp_spectrum(ray_pool.d_sensor_wavelength_nm[ray_id]) * 50000000000.0f;
            ray_pool.d_spectral_radiance[ray_id] = magik::sample_plancks_law<float>(ray_pool.d_sensor_wavelength_nm[ray_id], 1800.0f) * 150.0f;
            to_advance = false;
        }

        uint32_t slot = 0;

        if(to_advance)
        {
            slot = atomicAdd(advance_queue.d_count, 1);
            advance_queue.d_id[slot] = ray_id;
        }
        else
        {
            slot = atomicAdd(redistribute_queue.d_count, 1);
            redistribute_queue.d_id[slot] = ray_id;
        }
    }

    void launch_kernel_bxdf_async(magik_render_manager* manager, wavefront_ray_buffer_t* buffer)
    {
        uint32_t threads_per_block = manager->stage.settings.wavefront_threads_per_block;
        uint32_t n_block = ((buffer->x_resolution*buffer->y_resolution) + threads_per_block - 1) / threads_per_block;

        kernel_bxdf<<<n_block, threads_per_block, 0, static_cast<cudaStream_t>(manager->cuda_stream)>>>(buffer->ray_pool, buffer->bxdf_queue, buffer->advance_queue_A, buffer->redistribute_queue);
        check_cuda_errors(cudaGetLastError());

        reset_queue_async(buffer->bxdf_queue.d_count, &manager->cuda_stream); 
    }
}
