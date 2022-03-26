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

selected_renderer : Renderer

RenderTick :: proc(){
	base_device_context->OMSetRenderTargets(1,&render_target_view,nil)
	clear_color := [4]f32{0,0,1,1}
	base_device_context->ClearRenderTargetView(render_target_view,&clear_color)

	execute_renderer(selected_renderer)
	swapchain->Present(1,0)
}

render_init ::  proc(){
	init_renderers()
	
	selected_renderer = deffered_renderer

	bb_size := get_backbuffer_size()
	set_viewport(m.float2{0,0},m.float2{bb_size.x,bb_size.y})

}

init :: proc(hwnd : windows.HWND){
	using fmt
	using D3D11
	init_device_render_api(hwnd)

	render_init()
}

