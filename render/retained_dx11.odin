package render

import D3D11 "vendor:directx/d3d11"
import D3D12 "vendor:directx/d3d12"
import DXGI  "vendor:directx/dxgi"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import runtime "core:runtime"
import la "core:math/linalg"
import m "core:math/linalg/hlsl"
import fmt "core:fmt"
import con "../containers"
import camera "camera"

RECT :: windows.RECT
/*
Create a retained mode renderer 
1. Take in state calls
2. Take in remove state calls
3. Every frame check if state has changed and than remove replace add any state that needs it.
4. Execute the commands on that state.

I like how we structured it in Odin lets replicate that and clean it up here.
*/

@(private="file")
def_renderer : DefferedRenderer
swapchain: ^DXGI.ISwapChain1
@(private="file")
adapt : ^DXGI.IAdapter
@(private="file")
d2 : ^DXGI.IDevice2
@(private="file")
gbuffer_data : GBufferData
@(private="file")
render_texture : con.Buffer(int)
@(private="file")
temp_working_vertex_buffers : con.Buffer(VertexBuffer)

//map of all the active rednerers
renderers_map : map[string]rawptr

//global cpu buffer for all matrices 
//@(private)
//matrix_cpu_buffer : con.Buffer(m.float4x4)
//gpu buffer for all matrices passed to the gpu
//@(private)
//matrix_gpu_buffer : con.Buffer(m.float4x4)

MAX_STRUCT_BUFFER_SIZE :: 512

@(private)
const_buf_matrix_gpu : ConstantBuffer(m.float4x4)

get_renderer ::  proc(name : string,$T : typeid)-> ^T{
	render_ptr : ^rawptr = &renderers_map[name]
	assert(render_ptr != nil)
	return (^T)(render_ptr^)
}

RENDER_TYPE :: enum{
	NONE,
	OPENGL,
	VULKAN,
	METAL,
	DX12,
	DX11,
}

RENDERER : RENDER_TYPE  : RENDER_TYPE.DX11 
DeviceContext :: struct{
	ptr : rawptr,
}

Device :: struct{
	ptr : rawptr,
	con : DeviceContext,
}


//Commands for Renderer
RenderCommand :: struct{
	geometry : RenderGeometry,
	material_id : u64,
	model_matrix_id : int,
	camera_matrix_id:      u64,
	perspective_matrix_id: u64,
	texture_range : m.int2, 
	is_indexed:bool,
	material_name:string,
}

RenderGeometry :: struct {
	buffer_id_range: m.int2,
	count:           int,
	offset:          int,
	index_id:        int,
	index_count:     int,
	is_indexed:      bool,
	base_color:      m.float4,
}

BaseRenderCommandList :: struct{
	list : con.Buffer(RenderCommand),
}

RenderTarget :: struct{
	ptr : rawptr,
	tex_ptr : rawptr,
}

RenderShader :: struct{

}

DepthStencil :: struct{
	ptr : rawptr,
}

PrimitiveTopology :: enum{
    topology_undefined	= 0,
    topology_pointlist	= 1,
    topology_linelist	= 2,
    topology_linestrip	= 3,
    topology_trianglelist	= 4,
    topology_trianglestrip	= 5,
} 

VertexBufferView :: struct{
    buffer_location : u64,
    size_in_bytes : int,
    stride_in_bytes : int,
}

CommandBasicDraw :: struct{
	vertex_offset : int,
	count:         int,
	topology:      PrimitiveTopology,
	heap_count:    int,
	buffer_view:   VertexBufferView, // TODO(Ray Garner): add a way to bind multiples
}

DefferedRenderer :: struct{
	renderer : Renderer,
	gbuff_data : GBufferData,
}

//Pass Definitions 
GBufferData :: struct{
	device : Device,
	matrix_buffer:      ^con.Buffer(m.float4x4),
	matrix_quad_buffer: ^con.Buffer(m.float4x4),
	//TODO(Ray):Want to keep the concept so we have good correlation with dx12/VULKAN
	//root_sig:           rawptr,
	render_targets:     map[string]RenderTarget,
	depth_stencils : map[string]DepthStencil,
	shader:             RenderShader,
	camera : ^camera.Camera,
	render_commands : con.Buffer(RenderCommand),
}

Pass :: struct{
	init : proc(data : rawptr),
	setup : proc(data : rawptr),
	execute : proc(data : rawptr),
}

Renderer :: struct{
	passes : con.Buffer(Pass),
}

create_renderer ::  proc()-> Renderer{
	using con
	result : Renderer
	result.passes = buf_init(1,Pass)
	return result
}

create_pass ::  proc(this : ^Renderer,init : proc(data : rawptr,),setup : proc(data : rawptr),execute : proc(data : rawptr)){
	using con
	result : Pass
	result.init = init
	result.setup = setup
	result.execute = execute
	buf_push(&this.passes,result)
}


execute_renderer ::  proc(name : string,$T : typeid){
	//TODO(Ray):We need a where clause to make sure we dont pass invalid types
	fmt.println(name)
	
	renderer_to_exec : ^DefferedRenderer = get_renderer(name,T)
	fmt.println(renderer_to_exec)
fmt.println("\n")
	for pass in renderer_to_exec.renderer.passes.buffer{
		pass.setup(renderer_to_exec)
		pass.execute(renderer_to_exec)
	}
}

gbuffer_init_dx11 ::  proc(data : rawptr){
	//Create Render Textures
	/*
	diffuse , normal , position buffers
	*/
	bb_dim := get_backbuffer_size()
	def_ren_data := (^DefferedRenderer)(data)
	diffuse_rt := create_render_target(def_ren_data.gbuff_data.device,Format.B8G8R8A8_UNORM,bb_dim)
	normal_rt := create_render_target(def_ren_data.gbuff_data.device,Format.B8G8R8A8_UNORM,bb_dim)
	position_rt := create_render_target(def_ren_data.gbuff_data.device,Format.B8G8R8A8_UNORM,bb_dim)
	depth_stencil := create_depth_stencil(def_ren_data.gbuff_data.device,Format.D24_UNORM_S8_UINT,bb_dim)
	
	def_ren_data.gbuff_data.render_targets["diffuse"] = diffuse_rt
	def_ren_data.gbuff_data.render_targets["normal"] = normal_rt
	def_ren_data.gbuff_data.render_targets["position"] = position_rt
	def_ren_data.gbuff_data.depth_stencils["default"] = depth_stencil
}

gbuffer_setup_dx11 :: proc(data : rawptr){
	using con
	def_data : ^DefferedRenderer = (^DefferedRenderer)(data)
	clear_color : [4]f32 = {0,0,0,0}
	diffuse_rt : RenderTarget = def_data.gbuff_data.render_targets["diffuse"]
	normal_rt : RenderTarget = def_data.gbuff_data.render_targets["normal"]
	position_rt : RenderTarget = def_data.gbuff_data.render_targets["position"]
	default_depth_stencil : DepthStencil = def_data.gbuff_data.depth_stencils["default"]
	assert(diffuse_rt.ptr != nil)
	assert(normal_rt.ptr != nil)
	assert(position_rt.ptr != nil)

	clear_render_target(def_data.gbuff_data.device,diffuse_rt,clear_color)
	clear_render_target(def_data.gbuff_data.device,normal_rt,clear_color)
	clear_render_target(def_data.gbuff_data.device,position_rt,clear_color)
	clear_depth_stencil(def_data.gbuff_data.device,default_depth_stencil,D3D11.CLEAR_FLAG.DEPTH | D3D11.CLEAR_FLAG.STENCIL,0,0)
}

init_temp_mem :: proc(){
	temp_working_vertex_buffers = con.buf_init(1,VertexBuffer)
}

gbuffer_execute_dx11 ::  proc(data : rawptr){
	using m
	using con
	def_data : ^DefferedRenderer = (^DefferedRenderer)(data)
	for command in def_data.gbuff_data.render_commands.buffer{
		//world_matrix := buf_get(&matrix_cpu_buffer,u64(command.model_matrix_id))
		world_matrix := cpu_matrix_buffer->get_matrix(u64(command.model_matrix_id))
		camera := def_data.gbuff_data.camera
		camera_matrix := camera.mat
		projection_matrix := camera.projection_matrix
		view_matrix : float4x4 = camera_matrix * world_matrix
		clip_matrix : float4x4 = projection_matrix * view_matrix

		base_color := command.geometry.base_color
		
		//push to gpu buffer
		view_matrix_id := gpu_matrix_buffer->get_current_matrix_id()
		//view_matrix_id := buf_len(matrix_gpu_buffer) * size_of(m.float4x4)
		//buf_push(&matrix_gpu_buffer,view_matrix)
		gpu_matrix_buffer->add_matrix(view_matrix)

		//clip_matrix_id := buf_len(matrix_gpu_buffer) * size_of(m.float4x4)
		clip_matrix_id := gpu_matrix_buffer->get_current_matrix_id()

	//	buf_push(&matrix_gpu_buffer,clip_matrix)
		gpu_matrix_buffer->add_matrix(clip_matrix)
		//set rendertargets
		device := def_data.gbuff_data.device
		
		render_targets_to_set : []RenderTarget = make([]RenderTarget,3)
		render_targets_map := def_data.gbuff_data.render_targets
		render_targets_to_set[0] = render_targets_map["diffuse"]
		render_targets_to_set[1] = render_targets_map["normal"]
		render_targets_to_set[2] = render_targets_map["position"]
		
		set_render_targets(device,render_targets_to_set,3)
		//set viewport 
		bb_size := get_backbuffer_size()
		set_viewport(device,float2{0,0},bb_size)
		//set scissor rect
		s_rect : RECT = {0,0,i32(bb_size.x),i32(bb_size.y)}
		slice_rect : []RECT = {s_rect}
		set_scissor_rects(device,1,slice_rect)
		//get the material
		get_material_by_id(command.material_id)
		//set pipeline state not needed for dx11 
		set_primitive_topology_dx11(device,D3D11.PRIMITIVE_TOPOLOGY.TRIANGLELIST)
		//context->IASetInputLayout(m_pInputLayout.Get());
		//sets constants
		constant_matrix_buffer_slice := []ConstantBuffer(float4x4){const_buf_matrix_gpu}
		set_constant_buffers(device,0,float4x4,constant_matrix_buffer_slice)
		
		//set buffers for stages
		strides : con.Buffer(u32) = buf_init(1,u32)
		offsets : con.Buffer(u32) = buf_init(1,u32)
		defer{
			buf_free(&offsets)
			buf_free(&strides)
		}
		for i : int = command.geometry.buffer_id_range.x;i < command.geometry.buffer_id_range.y;i += 1{
			bv := buf_get(&buffer_table.vertex_buffers,u64(i))
			buf_push(&temp_working_vertex_buffers,bv)
			buf_push(&strides,bv.stride_in_bytes)
			buf_push(&offsets,0)
		}
		defer{buf_clear(&temp_working_vertex_buffers)}
		set_vertex_buffers(device,0,1,temp_working_vertex_buffers.buffer[:],strides.buffer[:],offsets.buffer[:])

		//than execute draw commands
		if command.is_indexed{
			ibv := buf_get(&buffer_table.index_buffers,u64(command.geometry.index_id))
			offset : u32 = 0

			set_index_buffer(device,ibv,ibv.format,offset)
			index_count : u32 = u32(command.geometry.index_count)
			start_index_location : u32 = u32(command.geometry.offset)
			base_vertex_location : i32 = 0
			draw_indexed(device,index_count,start_index_location,base_vertex_location)
		}else{
			draw(device,u32(command.geometry.count), u32(command.geometry.offset))
		}

		//end command list
	}
}

draw_dx11 :: proc(dev : Device,start_index : u32,start_index_location : u32){
	using D3D11
	(^IDeviceContext)(dev.con.ptr)->Draw(start_index,start_index_location)
}
draw ::  proc(dev : Device,start_index : u32,start_index_location : u32){
	when RENDERER == RENDER_TYPE.DX11{
		draw_dx11(dev,start_index,start_index_location)
	}
}

draw_indexed_dx11 ::  proc(dev : Device,index_count : u32,start_index_location : u32,base_vertex_location : i32){
	using D3D11
	(^IDeviceContext)(dev.con.ptr)->DrawIndexed(index_count,start_index_location,base_vertex_location)
}
draw_indexed ::  proc(dev : Device,index_count : u32,start_index_location : u32,base_vertex_location : i32){
	when RENDERER == RENDER_TYPE.DX11{
		draw_indexed_dx11(dev,index_count,start_index_location,base_vertex_location)
	}
}

set_primitive_topology_dx11 :: proc(dev : Device,topology : D3D11.PRIMITIVE_TOPOLOGY){
	using D3D11
	(^IDeviceContext)(dev.con.ptr)->IASetPrimitiveTopology(topology)
}

gbuffer_init ::  proc(data : rawptr){
	fmt.println("GBUFFINIT")
	defered_renderer := (^DefferedRenderer)(data)
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_init_dx11(&def_renderer)
	}
}

gbuffer_setup ::  proc(data : rawptr){
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_setup_dx11(data)
	}
}

gbuffer_exec ::  proc(data : rawptr){
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_execute_dx11(data)

	}
}

create_device ::  proc(hwnd : windows.HWND)-> Device{
	using D3D11
	result : Device
	when RENDERER == RENDER_TYPE.DX11{
		creation_flags : CREATE_DEVICE_FLAGS
		creation_flags = {CREATE_DEVICE_FLAG.DEBUG}//D3D11_CREATE_DEVICE_BGRA_SUPPORT
		new_device_ptr : ^IDevice
		new_device_context : ^IDeviceContext
		hresult := CreateDevice(nil,DRIVER_TYPE.HARDWARE,nil,creation_flags,nil,0,SDK_VERSION,&new_device_ptr,nil,&new_device_context)
		if hresult != 0x0{
			assert(false)
		}
		result.ptr = new_device_ptr
		result.con.ptr = new_device_context
	}
	return result
}

create_swapchain ::  proc(device : Device,hwnd : windows.HWND){
	using D3D11
	using fmt
	(^IDevice)(device.ptr)->QueryInterface(DXGI.IDevice2_UUID,(^rawptr)(&d2))

	hresult := d2.GetAdapter(d2,&adapt)
	if hresult == 0x0{
		println("WE HAVE THE ADAPTER")
	}

	fac2 : ^DXGI.IFactory2
	hresult = adapt->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&fac2))
	if hresult == 0x0{
		println("WE HAVE THE Parent")
	}

	d2.SetMaximumFrameLatency(d2,1)
	swap_chain_desc : DXGI.SWAP_CHAIN_DESC1
	swap_chain_desc.BufferCount = 2
	swap_chain_desc.SwapEffect = DXGI.SWAP_EFFECT.FLIP_SEQUENTIAL
	swap_chain_desc.Stereo = false
	swap_chain_desc.BufferUsage = DXGI.USAGE.RENDER_TARGET_OUTPUT
	swap_chain_desc.Scaling = DXGI.SCALING.NONE
	swap_chain_desc.Flags = 0
	swap_chain_desc.Width = 0
	swap_chain_desc.Height = 0
	swap_chain_desc.Format = DXGI.FORMAT.B8G8R8A8_UNORM
	swap_chain_desc.SampleDesc.Count = 1
	swap_chain_desc.SampleDesc.Quality =0

	hresult = fac2.CreateSwapChainForHwnd(fac2,d2,hwnd,&swap_chain_desc,nil,nil,&swapchain)
	if hresult != 0x0{
		println("Did not create swapchain")
	}else {
		println("Created SwapChain")
	}
}

set_viewport_dx11 :: proc(device : Device,origin : m.float2,size : m.float2,depth : m.float2 = {D3D11.MIN_DEPTH,D3D11.MAX_DEPTH}){
	using D3D11
	viewport : VIEWPORT
	viewport.TopLeftY = origin.x
	viewport.TopLeftX = origin.y
	viewport.Width = size.x
	viewport.Height = size.y
	viewport.MinDepth = depth.x
	viewport.MaxDepth = depth.y
	(^IDeviceContext)(device.con.ptr)->RSSetViewports(1,&viewport)	
}

set_viewport :: proc(device : Device,origin : m.float2,size : m.float2,depth : m.float2 = {D3D11.MIN_DEPTH,D3D11.MAX_DEPTH}){
	when RENDERER == RENDER_TYPE.DX11{
		set_viewport_dx11(device,origin,size,depth)
	}
}


set_scissor_rects_dx11 :: proc(device : Device,count : u32,rects : []RECT){
	using D3D11
	(^IDeviceContext)(device.con.ptr)->RSSetScissorRects(count,&rects[0])
}
set_scissor_rects :: proc(device : Device,count : u32,rects : []RECT){
	when RENDERER == RENDER_TYPE.DX11{
		set_scissor_rects_dx11(device,count,rects)
	}
}

get_backbuffer_size :: proc() -> m.float2{
	using D3D11
	result : m.float2
	when RENDERER == RENDER_TYPE.DX11{
		back_buffer_desc : TEXTURE2D_DESC
		back_buffer : ^ITexture2D
		hresult := swapchain->GetBuffer(0,ITexture2D_UUID,(^rawptr)(&back_buffer))
		back_buffer->GetDesc(&back_buffer_desc)
		result.x = f32(back_buffer_desc.Width)
		result.y = f32(back_buffer_desc.Height)
	}
	return result
}

init_renderers ::  proc(device : Device){
	using con
	gpu_matrix_buffer = init_matrix_buffer(MAX_STRUCT_BUFFER_SIZE)
	cpu_matrix_buffer = init_matrix_buffer(MAX_STRUCT_BUFFER_SIZE)

	//matrix_cpu_buffer = buf_init(MAX_STRUCT_BUFFER_SIZE,m.float4x4)
	//matrix_gpu_buffer = buf_init(MAX_STRUCT_BUFFER_SIZE,m.float4x4)
	renderers_map = make(map[string]rawptr)
	//buf_push(&matrix_gpu_buffer,m.float4x4{})
	gpu_matrix_buffer->add_matrix(m.float4x4{})
	first_ele_ptr := gpu_matrix_buffer->get_pointer_at_offset()
	//first_ele_ptr := &matrix_gpu_buffer.buffer[0]

	const_buf_matrix_gpu = init_constant_buffer_structured(device,m.float4x4,first_ele_ptr,MAX_STRUCT_BUFFER_SIZE * size_of(m.float4x4))
	init_temp_mem()
	def_renderer.gbuff_data.device = device
	def_renderer.gbuff_data.render_targets = make(map[string]RenderTarget)
	def_renderer.gbuff_data.depth_stencils = make(map[string]DepthStencil)
	def_renderer.renderer = create_renderer()
	
	renderers_map["deffered"] = &def_renderer

	create_pass(&def_renderer.renderer,gbuffer_init,gbuffer_setup,gbuffer_exec)

	for pass in def_renderer.renderer.passes.buffer{
		pass.init(&def_renderer)
	}
}

finalize_frame_dx11 :: proc(){
	swapchain->Present(1,0)
}
