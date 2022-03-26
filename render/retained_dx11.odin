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


base_device_context: ^D3D11.IDeviceContext
render_target_view : ^D3D11.IRenderTargetView
swapchain: ^DXGI.ISwapChain1
adapt : ^DXGI.IAdapter
d2 : ^DXGI.IDevice2
global_device : Device

deffered_renderer : Renderer

RENDER_TYPE :: enum{
	NONE,
	OPENGL,
	VULKAN,
	METAL,
	DX12,
	DX11,
}

RENDERER : RENDER_TYPE  : RENDER_TYPE.DX11 

Device :: struct{
	ptr : rawptr,
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

render_commands : con.Buffer(RenderCommand)
render_texture : con.Buffer(int)

RenderTarget :: struct{
	ptr : rawptr,
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
	gbuff_data : GBufferData,
}

GBufferPass :: struct{
	init_gbuffer_pass : proc(),
	setup_gbuffer_pass : proc(),
	render_gbuffer_pass : proc(),
}

Pass :: struct{
	init : proc(data : rawptr),
	setup : proc(data : rawptr),
	execute : proc(data : rawptr),
}

Renderer :: struct{
	passes : con.Buffer(Pass),
}

create_renderer ::  proc($T : typeid)-> Renderer{
	using con
	result : Renderer
	//result.passes = buf_init(Pass(GBufferData),1)
	result.passes = buf_init(1,Pass)
	
	return result
}

create_pass ::  proc(this : ^Renderer,DT : typeid,init : proc(data : rawptr,),setup : proc(data : rawptr),execute : proc(data : rawptr)){
	using con
	result : Pass
	result.init = init
	result.setup = setup
	result.execute = execute
	buf_push(&this.passes,result)
}

init_renderers ::  proc(){
	using con
	deffered_renderer = create_renderer(DefferedRenderer)
	create_pass(&deffered_renderer,GBufferData,gbuffer_init,gbuffer_setup,gbuffer_exec)

	for pass in deffered_renderer.passes.buffer{
		pass.init(&deffered_renderer)
	}
}

execute_renderer ::  proc(renderer : Renderer){
//renderers : con.Buffer(Renderer)
	renderer_ref := renderer
	for pass in renderer.passes.buffer{
		pass.setup(&renderer_ref)
		pass.execute(&renderer_ref)
	}
}
//Pass Definitions 
GBufferData :: struct{
	matrix_buffer:      ^con.Buffer(m.float4x4),
	matrix_quad_buffer: ^con.Buffer(m.float4x4),
	root_sig:           rawptr,
	render_targets:     con.Buffer(RenderTarget),
	shader:             RenderShader,
}

gbuffer_init_dx11 ::  proc(data : rawptr){
	//Create Render Textures
	/*
	diffuse , normal , position buffers
	*/
}

gbuffer_setup_dx11 :: proc(data : rawptr){

	/*add clear commands for all buffers
	and for depth stencil buffer
	*/
}

gbuffer_execute_dx11 ::  proc(data : rawptr){
	/*execute commands*/
}

create_render_target_back_buffer :: proc(device : Device) -> RenderTarget{
	result : RenderTarget
	when RENDERER == RENDER_TYPE.DX11{
		result = create_render_target_back_buffer_dx11(device)
	}
	return result
}

create_render_target_back_buffer_dx11 ::  proc(device : Device)-> RenderTarget{
	//create render target view
	using D3D11
	using fmt

	result : RenderTarget
	back_buffer : ^ITexture2D
	hresult := swapchain->GetBuffer(0,ITexture2D_UUID,(^rawptr)(&back_buffer))
	if hresult != 0x0{
		println("Failed TO Get BackBuffer 0")
	}
	
	hresult = (^IDevice)(device.ptr)->CreateRenderTargetView(back_buffer,nil,&render_target_view)
	if hresult != 0x0{
		println("Failed TO CreateRenderTarget")
	}
	return result
}

gbuffer_init ::  proc(data : rawptr){
	fmt.println("GBUFFINIT")
	data_ref := data
	defered_renderer := (^DefferedRenderer)(data_ref)
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_init_dx11(data)
	}
}

gbuffer_setup ::  proc(data : rawptr){
	//fmt.println("GBUFF SETUP")
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_setup_dx11(data)
	}
}

gbuffer_exec ::  proc(data : rawptr){
	fmt.println("GBUFF EXEC")
	when RENDERER == RENDER_TYPE.DX11{
		gbuffer_execute_dx11(data)
	}
}

create_device ::  proc(hwnd : windows.HWND)-> Device{
	using D3D11

	result : Device
	when RENDERER == RENDER_TYPE.DX11{
		creation_flags : u32
		creation_flags |= u32(D3D11.CREATE_DEVICE_FLAG.DEBUG)//D3D11_CREATE_DEVICE_BGRA_SUPPORT
		new_device_ptr : ^IDevice
		hresult := CreateDevice(nil,DRIVER_TYPE.HARDWARE,nil,nil,nil,0,SDK_VERSION,&new_device_ptr,nil,&base_device_context)
		if hresult != 0x0{
			assert(false)
		}
		result.ptr = new_device_ptr
	}
	return result
}

init_device_render_api :: proc(hwnd : windows.HWND){
	new_device := create_device(hwnd)
	if new_device.ptr != nil{
		create_swapchain(new_device,hwnd)
	}else{
		assert(false)
	}
	
	create_render_target_back_buffer(new_device)
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

set_viewport :: proc(origin : m.float2,size : m.float2,depth : m.float2 = {D3D11.MIN_DEPTH,D3D11.MAX_DEPTH}){
	when RENDERER == RENDER_TYPE.DX11{
		set_viewport_dx11(origin,size,depth)
	}
}

set_viewport_dx11 :: proc(origin : m.float2,size : m.float2,depth : m.float2 = {D3D11.MIN_DEPTH,D3D11.MAX_DEPTH}){
	using D3D11
	viewport : VIEWPORT
	viewport.TopLeftY = origin.x
	viewport.TopLeftX = origin.y
	viewport.Width = size.x
	viewport.Height = size.y
	viewport.MinDepth = depth.x
	viewport.MaxDepth = depth.y
	base_device_context->RSSetViewports(1,&viewport)	
}
