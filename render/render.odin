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
@(private="file")
selected_renderer : Renderer
@(private="file")
back_buffer_render_target : RenderTarget

RenderTick :: proc(){
	render_targets : []RenderTarget = make([]RenderTarget,1)
	render_targets[0] = back_buffer_render_target
	set_render_targets(render_device,render_targets[:],1)
	clear_color := [4]f32{0,0,1,1}
	clear_render_target(render_device,render_targets[0],clear_color)

	execute_renderer("deffered",DefferedRenderer)

	end_frame()
}

render_init ::  proc(){
	init_renderers(render_device)

	bb_size := get_backbuffer_size()
	set_viewport(render_device,m.float2{0,0},m.float2{bb_size.x,bb_size.y})
}

init_device_render_api :: proc(hwnd : windows.HWND){
	create_device(hwnd)
	if render_device.ptr != nil{
		create_swapchain(render_device,hwnd)
	}else{
		assert(false)
	}
	
	back_buffer_render_target = create_render_target_back_buffer(render_device)
}

init :: proc(hwnd : windows.HWND){
	using fmt
	using D3D11
	init_device_render_api(hwnd)

	render_init()
}

end_frame :: proc(){
	when RENDERER == RENDER_TYPE.DX11{
		finalize_frame_dx11()
	}
}
