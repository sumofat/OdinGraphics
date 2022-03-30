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
render_commands : con.Buffer(RenderCommand)
@(private="file")
render_texture : con.Buffer(int)

//map of all the active rednerers
renderers_map : map[string]rawptr

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
	material_id : int,
	model_matrix_id : int,
	camera_matrix_id:      int,
	perspective_matrix_id: int,
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
	shader:             RenderShader,
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
	def_ren_data.gbuff_data.render_targets["diffuse"] = diffuse_rt
	def_ren_data.gbuff_data.render_targets["normal"] = normal_rt
	def_ren_data.gbuff_data.render_targets["position"] = position_rt
}

gbuffer_setup_dx11 :: proc(data : rawptr){
	using con
	def_data : ^DefferedRenderer = (^DefferedRenderer)(data)
	clear_color : [4]f32 = {0,0,0,0}
	diffuse_rt : RenderTarget = def_data.gbuff_data.render_targets["diffuse"]
	normal_rt : RenderTarget = def_data.gbuff_data.render_targets["normal"]
	position_rt : RenderTarget = def_data.gbuff_data.render_targets["position"]
	assert(diffuse_rt.ptr != nil)
	assert(normal_rt.ptr != nil)
	assert(position_rt.ptr != nil)
fmt.println(diffuse_rt)
	clear_render_target(def_data.gbuff_data.device,diffuse_rt,clear_color)
	clear_render_target(def_data.gbuff_data.device,normal_rt,clear_color)
	clear_render_target(def_data.gbuff_data.device,position_rt,clear_color)
}

gbuffer_execute_dx11 ::  proc(data : rawptr){
	/*execute commands*/
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
	renderers_map = make(map[string]rawptr)
	def_renderer.gbuff_data.device = device
	def_renderer.gbuff_data.render_targets = make(map[string]RenderTarget)
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
