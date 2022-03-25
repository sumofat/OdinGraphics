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

base_device_context: ^D3D11.IDeviceContext
render_target_view : ^D3D11.IRenderTargetView
swapchain: ^DXGI.ISwapChain1
selected_renderer : Renderer
RenderTick :: proc(){
	base_device_context->OMSetRenderTargets(1,&render_target_view,nil)
	clear_color := [4]f32{0,0,1,1}
	base_device_context->ClearRenderTargetView(render_target_view,&clear_color)

	selected_renderer.execute()
	swapchain->Present(1,0)
}
render_init ::  proc(){
	
	init_renderers()
}

init :: proc(hwnd : windows.HWND){
	using fmt
	using D3D11
	device : ^IDevice
	creation_flags : u32
	creation_flags |= u32(D3D11.CREATE_DEVICE_FLAG.DEBUG)//D3D11_CREATE_DEVICE_BGRA_SUPPORT
	hresult := CreateDevice(nil,DRIVER_TYPE.HARDWARE,nil,nil,nil,0,SDK_VERSION,&device,nil,&base_device_context)

	mode_desc : DXGI.MODE_DESC1
	mode_desc.Width = 0
	mode_desc.Height = 0
	mode_desc.Format = DXGI.FORMAT.R8G8B8A8_UNORM 
	mode_desc.Scaling = DXGI.MODE_SCALING.UNSPECIFIED
	mode_desc.RefreshRate = {}
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
	
//	hresult := CreateDeviceAndSwapChain(nil,DRIVER_TYPE.HARDWARE,nil,creation_flags,nil,u32(creation_flags),SDK_VERSION,&swap_chain_desc,&swap_chain,&device,nil,nil)
	print(hresult)

	if device == nil{
		println("Could not find or create device for D3d11")
	}else{
		println("Created D3D11	device")
	}

	adapt : ^DXGI.IAdapter
	d2 : ^DXGI.IDevice2

	device->QueryInterface(DXGI.IDevice2_UUID,(^rawptr)(&d2))

	hresult = d2.GetAdapter(d2,&adapt)
	if hresult == 0x0{
		println("WE HAVE THE ADAPTER")
	}

	fac2 : ^DXGI.IFactory2
	hresult = adapt->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&fac2))
	if hresult == 0x0{
		println("WE HAVE THE Parent")
	}

	d2.SetMaximumFrameLatency(d2,1)
	hresult = fac2.CreateSwapChainForHwnd(fac2,d2,hwnd,&swap_chain_desc,nil,nil,&swapchain)
	if hresult != 0x0{
		println("Did not create swapchain")
	}else {
		println("Created SwapChain")
	}

	//create render target view
	back_buffer : ^ITexture2D
	hresult = swapchain->GetBuffer(0,ITexture2D_UUID,(^rawptr)(&back_buffer))
	if hresult != 0x0{
		println("Failed TO Get BackBuffer 0")
	}
	
	hresult = device->CreateRenderTargetView(back_buffer,nil,&render_target_view)
	if hresult != 0x0{
		println("Failed TO CreateRenderTarget")
	}
	
	back_buffer_desc : TEXTURE2D_DESC
	back_buffer->GetDesc(&back_buffer_desc)

	viewport : VIEWPORT
	viewport.TopLeftY = 0.0
	viewport.TopLeftX = 0.0
	viewport.Width = f32(back_buffer_desc.Width)
	viewport.Height = f32(back_buffer_desc.Height)
	viewport.MinDepth = MIN_DEPTH
	viewport.MaxDepth = MAX_DEPTH

	base_device_context->RSSetViewports(1,&viewport)	
	render_init()
}

