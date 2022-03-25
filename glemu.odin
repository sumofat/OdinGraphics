
package render

ProgramKey :: struct{
	value : u64,
	f : u64,
}

UniformBindingTableEntry :: struct{
	call_index : int,
	v_size : int,
	f_size : int,
	v_data : rawptr,
	f_data : rawptr,
	v_index : int,
	f_index : int,
}

TextureBindingTableEntry :: struct{
	vertex_or_fragment : int,
	call_index : int,
	size : int,
	texture_ptr : rawptr,
}

BufferBindTarget :: enum{
	ArrayBuffer,
	IndexBuffer,
}

BufferBindingTableEntry :: struct{
	index : int,
	gg_I : int,
	offset : int,
	key : u64,
}

FragmentShaderSTextureBindingTableEntry :: struct{
	sampler_index : int,
	tex_index : int,
	texture : GLEMUTexture, 
}

GLEMUBufferState :: struct{
    glemu_bufferstate_none,
    glemu_bufferstate_start,//start means we are drawing NOW!1
    glemu_bufferstate_viewport_change,//means we are changin viewport size/location2
    glemu_bufferstate_blend_change,
    glemu_bufferstate_blend_change_i,
    glemu_bufferstate_scissor_rect_change,
    glemu_bufferstate_scissor_test_enable,
    glemu_bufferstate_scissor_test_disable,//if disable default is full viewport settings.
    glemu_bufferstate_shader_program_change,
    glemu_bufferstate_bindbuffer,
    glemu_bufferstate_set_uniforms,//this is a lil different than opengl but lets you pass some data easily without creating an intermediate buffer9
    //limited to 4kb<  most uniforms are under that amount
//    glemu_bufferstate_binduniform_buffer,//Note implmenented because have no need for it yet.
    
//Depth and stencils
    glemu_bufferstate_depth_enable,
    glemu_bufferstate_depth_disable,
    glemu_bufferstate_depth_func,
    
    glemu_bufferstate_stencil_enable,
    glemu_bufferstate_stencil_disable,
    glemu_bufferstate_stencil_mask,
    glemu_bufferstate_stencil_mask_sep,
    glemu_bufferstate_stencil_func,
    glemu_bufferstate_stencil_func_sep,
    glemu_bufferstate_stencil_op,
    glemu_bufferstate_stencil_op_sep,
    glemu_bufferstate_stencil_func_and_op,
    glemu_bufferstate_stencil_func_and_op_sep,
    glemu_bufferstate_clear_start,
    glemu_bufferstate_clear_end,
    glemu_bufferstate_clear_color_target,

    glemu_bufferstate_clear_stencil_value,
    glemu_bufferstate_clear_color_value,
    glemu_bufferstate_clear_depth_value,
    glemu_bufferstate_clear_color_and_stencil_value,
    //Debug stuff
    glemu_bufferstate_debug_signpost,
    glemu_bufferstate_draw_arrays,
    glemu_bufferstate_draw_elements,
    glemu_bufferstate_framebuffer_bind,
    
    glemu_bufferstate_end,
}


//TODO(Ray):Could do multiple of these for multithreading and join after done ...
//perhaps something for another day. For now single thread only.
DrawCallTables :: struct{
	uniform_binding_table : [dynamic]rawptr,
    texture_binding_table : [dynamic]rawptr,
	buffer_binding_table : [dynamic]rawptr,
}

GLEMUTextureKey :: struct{
	format : PixelFormat,
	width : int,
	height : int,
	sample_count : int,
	storage_mode : StorageMode,
	allow_gpu_optimized_contents : bool,
	gl_text_id : u64,
}

ReleasedTextureEntry :: struct{
	tex_key : GLEMUTextureKey,
	delete_count : int,
	current_count : int,
	thread_id : u64,
	is_free : bool,
}

UsedButReleasedEntry :: struct{
	texture_key : u64,
	thread_id : u64,
}

ResourceManagementTables :: struct{
	used_but_released_table : [dynamic]rawptr,
	released_textures_table : AnyCache,
}

GLEMURenderCommandList :: struct{
	buffer : Arena,
	count : u32,
}

GLEMUCommandHeader :: struct{
	type : GLEMUBufferState,
	pad : int,
}

GLEMUBlendCommand :: struct{
	source_RGB_blend_factor : BlendFactor,
	destination_RGB_blend_factor : BlendFactor,
}

GlEMUBlendICommand :: struct{
	source_RGB_blend_factor : BlendFactor,
	destination_RGB_blend_factor : BlendFactor,
	index : int,
}

GLEMUUseProgramCommand :: struct{
	program : GLProgram,
}

GLEMUScissorTestCommand :: struct{
	is_enable : bool,
}
