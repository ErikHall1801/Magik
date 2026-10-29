#include "command.h"
#include "renderer.h"
#include <string> // ???

namespace magik
{
    void fetch_command_info(e_magik_cqs_command_types type, bool* is_valid_command, size_t* command_size)
    {
        bool is_valid_ = false;
        size_t size_ = 0;

        switch(type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER: { is_valid_ = true; size_ = sizeof(magik_command_set_state_render_t); break; }

            case MAGIK_COMMAND_SET_STATE_PAUSE: { is_valid_ = true; size_ = sizeof(magik_command_set_state_pause_t); break; }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER: { is_valid_ = true; size_ = sizeof(magik_command_clear_render_buffer_t); break; }

            case MAGIK_COMMAND_ADD_AOV: { is_valid_ = true; size_ = sizeof(magik_command_add_aov_t); break; }

            case MAGIK_COMMAND_REMOVE_AOV: { is_valid_ = true; size_ = sizeof(magik_command_remove_aov_t); break; }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF: { is_valid_ = true; size_ = sizeof(magik_command_printf_t); break; }

            case MAGIK_COMMAND_SET_RESOLUTION: { is_valid_ = true; size_ = sizeof(magik_command_set_resolution_t); break; }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // #######################
            // ### 4000-4999 Scene ###
            // #######################


            
            // ########################
            // ### 5000-5999 Camera ###
            // ########################
            case MAGIK_COMMAND_SET_ACTIVE_CAMERA: { is_valid_ = true; size_ = sizeof(magik_command_set_active_camera_t); break; }

            case MAGIK_COMMAND_SET_CAMERA_POSITION: { is_valid_ = true; size_ = sizeof(magik_command_set_camera_position_t); break; }

            case MAGIK_COMMAND_SET_CAMERA_ORIENTATION: { is_valid_ = true; size_ = sizeof(magik_command_set_camera_orientation_t); break; }



            // #################################
            // ### 6000-6999 Hittable Object ###
            // #################################



            // ################################
            // ### 7000-7999 bxdf materials ###
            // ################################ 



            default: { break; }
        }

        *is_valid_command = is_valid_;
        *command_size = size_;
    }

    static void apply_command(magik_render_manager* manager, uint32_t* playhead, command_buffer_t* command_buffer, e_magik_cqs_command_types command_type, size_t command_size)
    {
        switch(command_type)
        {
            // ##################################
            // ### 1000-1999 Basic operations ###
            // ##################################
            case MAGIK_COMMAND_SET_STATE_RENDER:
            {
                break;
            }

            case MAGIK_COMMAND_SET_STATE_PAUSE:
            {
                break;
            }

            case MAGIK_COMMAND_CLEAR_RENDER_BUFFER:
            {
                break;
            }

            case MAGIK_COMMAND_ADD_AOV:
            {
                magik_command_add_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                magik::framebuffer_t fb;
                fb.channels = cmd.channels;
                manager->framebuffer_swapchain.render_framebuffer.collection.emplace(aov_name, fb);
                break;
            }

            case MAGIK_COMMAND_REMOVE_AOV:
            {
                magik_command_remove_aov_t cmd;
                memcpy(&cmd, playhead, command_size);
                std::string aov_name(cmd.name, cmd.length_of_name);
                manager->framebuffer_swapchain.render_framebuffer.collection.erase(aov_name);
                break;
            }



            // ################################
            // ### 2000-2999 Built-in tests ###
            // ################################
            case MAGIK_COMMAND_PRINTF:
            {
                magik_command_printf_t cmd;
                memcpy(&cmd, playhead, command_size);
                if(cmd.length_of_text < 512) printf("%.*s \n", cmd.length_of_text, cmd.text);
                break;
            }

            case MAGIK_COMMAND_SET_RESOLUTION:
            {
                magik_command_set_resolution_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->framebuffer_swapchain.x_resolution_target = cmd.x_resolution;
                manager->framebuffer_swapchain.y_resolution_target = cmd.y_resolution;
                break;
            }



            // ##########################
            // ### 3000-3999 Settings ###
            // ##########################



            // #######################
            // ### 4000-4999 Scene ###
            // #######################


            
            // ########################
            // ### 5000-5999 Camera ###
            // ########################
            case MAGIK_COMMAND_SET_ACTIVE_CAMERA:
            {
                magik_command_set_active_camera_t cmd;
                memcpy(&cmd, playhead, command_size);
                break;
            }

            case MAGIK_COMMAND_SET_CAMERA_POSITION:
            {
                magik_command_set_camera_position_t cmd;
                memcpy(&cmd, playhead, command_size);
                manager->stage.optical_systen.position.x = cmd.position_x;
                manager->stage.optical_systen.position.y = cmd.position_y;
                manager->stage.optical_systen.position.z = cmd.position_z;
                
                manager->stage.c0 = cmd.position_x;
                manager->stage.c1 = cmd.position_y;
                manager->stage.c2 = cmd.position_z;
                break;
            }

            case MAGIK_COMMAND_SET_CAMERA_ORIENTATION:
            {
                magik_command_set_camera_orientation_t cmd;
                memcpy(&cmd, playhead, command_size);
                mat3f m;
                m.make_identity();
                m.rotate(cmd.rotation_x, cmd.rotation_y, cmd.rotation_z);
                manager->stage.optical_systen.orientation = m;

                manager->stage.real = cmd.rotation_x;
                manager->stage.imag = cmd.rotation_y;
                break;
            }



            // #################################
            // ### 6000-6999 Hittable Object ###
            // #################################



            // ################################
            // ### 7000-7999 bxdf materials ###
            // ################################ 



            default:
            {
                break;
            }
        }
    }

    e_magik_result_types push_command(magik_render_manager_t manager, const void* command)
    {
        if(!manager || !command) return MAGIK_ERROR_INVALID_POINTER;

        if(reinterpret_cast<uintptr_t>(command) % sizeof(uint32_t) != 0) return MAGIK_ERROR_PACKED_COMMAND_NOT_ALLIGNED;

        e_magik_cqs_command_types command_type;
        memcpy(&command_type, command, sizeof(e_magik_cqs_command_types)); 
        
        bool is_valid = false;
        size_t command_size = 0;
        fetch_command_info(command_type, &is_valid, &command_size);

        if(!is_valid) return MAGIK_ERROR_INVALID_COMMAND;

        if(command_size % sizeof(uint32_t) != 0) return MAGIK_ERROR_COMMAND_SIZE_NOT_A_MULTIPLE_OF_4;

        size_t command_buffer_occupancy = (size_t)(manager->command_context.front->n_occupied_chunk)*sizeof(uint32_t);
        size_t command_buffer_capacity = (size_t)(manager->command_context.n_reserved_chunk)*sizeof(uint32_t);

        if((command_buffer_occupancy+command_size) > command_buffer_capacity)
        {
            if(manager->command_context.drop_overflows)
            {
                return MAGIK_SUCCESS;
            }
            else
            {
                return MAGIK_ERROR_COMMAND_BUFFER_OVERFLOW;
            }
        }

        uint32_t* head_ptr = manager->command_context.front->data.get() + manager->command_context.front->n_occupied_chunk;
        memcpy(head_ptr, command, command_size);
        manager->command_context.front->n_occupied_chunk += static_cast<uint32_t>(command_size / sizeof(uint32_t));

        return MAGIK_SUCCESS;
    }

    e_magik_result_types dispatch_command_buffer(magik_render_manager_t manager, bool* is_dispatched)
    {
        if(!manager) 
        {
            *is_dispatched = false;
            return MAGIK_ERROR_INVALID_POINTER;
        }

        if(manager->command_context.is_swap_ready.load(std::memory_order_acquire))
        {
            manager->command_context.front.swap(manager->command_context.back);
            manager->command_context.is_swap_ready.store(false, std::memory_order_release);

            *is_dispatched = true;
            return MAGIK_SUCCESS;
        }
        else
        {
            *is_dispatched = false;
            return MAGIK_SUCCESS;
        }
    }

    e_magik_result_types consume_command_buffer(magik_render_manager_t manager, command_buffer_t* command_buffer)
    {
        /*
        * We ultimately want to apply the commands on the DCC as well to maintain a 
        * mirror copy of the render graph. This can be done with this function, we 
        * just need to copy the buffer before consuming it. 
        * And, once it exists, pass in the correct render graph. 
        */

        if(!manager) return MAGIK_ERROR_INVALID_POINTER;

        size_t command_buffer_occupancy = (size_t)(command_buffer->n_occupied_chunk);
        uint32_t* playhead = command_buffer->data.get();
        size_t playhead_offset = 0;

        e_magik_cqs_command_types command_type;
        bool is_valid = false;
        size_t command_size = 0;

        while(command_buffer_occupancy > playhead_offset)
        {
            memcpy(&command_type, (playhead + playhead_offset), sizeof(e_magik_cqs_command_types));

            fetch_command_info(command_type, &is_valid, &command_size);

            if(!is_valid || command_size == 0 || (command_size % sizeof(uint32_t) != 0)) return MAGIK_ERROR_INVALID_COMMAND;

            if(((playhead_offset + command_size) / sizeof(uint32_t)) > command_buffer_occupancy) return MAGIK_ERROR_OUT_OF_BOUNDS_COMMAND_BUFFER_READ;

            apply_command(manager, (playhead + playhead_offset), command_buffer, command_type, command_size);

            playhead_offset += (command_size/sizeof(uint32_t));
        }

        command_buffer->n_occupied_chunk = 0;
        return MAGIK_SUCCESS;
    }

    e_magik_result_types consume_back_command_buffer(magik_render_manager_t manager)
    {
        e_magik_result_types error = consume_command_buffer(manager, manager->command_context.back.get());
        manager->command_context.is_swap_ready.store(true, std::memory_order_release);
        return error;
    }
}
