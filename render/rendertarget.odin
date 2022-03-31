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

//Render Targets
//handles all state of all render targets / buffers
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

	rt_ptr := (^IRenderTargetView)(result.ptr)
	hresult = (^IDevice)(device.ptr)->CreateRenderTargetView(back_buffer,nil,&rt_ptr)
	if hresult != 0x0{
		println("Failed TO CreateRenderTarget")
	}else{
		result.ptr = rt_ptr
	}
	return result
}

Format :: enum{
	UNKNOWN                                 = 0,
	R32G32B32A32_TYPELESS                   = 1,
	R32G32B32A32_FLOAT                      = 2,
	R32G32B32A32_UINT                       = 3,
	R32G32B32A32_SINT                       = 4,
	R32G32B32_TYPELESS                      = 5,
	R32G32B32_FLOAT                         = 6,
	R32G32B32_UINT                          = 7,
	R32G32B32_SINT                          = 8,
	R16G16B16A16_TYPELESS                   = 9,
	R16G16B16A16_FLOAT                      = 10,
	R16G16B16A16_UNORM                      = 11,
	R16G16B16A16_UINT                       = 12,
	R16G16B16A16_SNORM                      = 13,
	R16G16B16A16_SINT                       = 14,
	R32G32_TYPELESS                         = 15,
	R32G32_FLOAT                            = 16,
	R32G32_UINT                             = 17,
	R32G32_SINT                             = 18,
	R32G8X24_TYPELESS                       = 19,
	D32_FLOAT_S8X24_UINT                    = 20,
	R32_FLOAT_X8X24_TYPELESS                = 21,
	X32_TYPELESS_G8X24_UINT                 = 22,
	R10G10B10A2_TYPELESS                    = 23,
	R10G10B10A2_UNORM                       = 24,
	R10G10B10A2_UINT                        = 25,
	R11G11B10_FLOAT                         = 26,
	R8G8B8A8_TYPELESS                       = 27,
	R8G8B8A8_UNORM                          = 28,
	R8G8B8A8_UNORM_SRGB                     = 29,
	R8G8B8A8_UINT                           = 30,
	R8G8B8A8_SNORM                          = 31,
	R8G8B8A8_SINT                           = 32,
	R16G16_TYPELESS                         = 33,
	R16G16_FLOAT                            = 34,
	R16G16_UNORM                            = 35,
	R16G16_UINT                             = 36,
	R16G16_SNORM                            = 37,
	R16G16_SINT                             = 38,
	R32_TYPELESS                            = 39,
	D32_FLOAT                               = 40,
	R32_FLOAT                               = 41,
	R32_UINT                                = 42,
	R32_SINT                                = 43,
	R24G8_TYPELESS                          = 44,
	D24_UNORM_S8_UINT                       = 45,
	R24_UNORM_X8_TYPELESS                   = 46,
	X24_TYPELESS_G8_UINT                    = 47,
	R8G8_TYPELESS                           = 48,
	R8G8_UNORM                              = 49,
	R8G8_UINT                               = 50,
	R8G8_SNORM                              = 51,
	R8G8_SINT                               = 52,
	R16_TYPELESS                            = 53,
	R16_FLOAT                               = 54,
	D16_UNORM                               = 55,
	R16_UNORM                               = 56,
	R16_UINT                                = 57,
	R16_SNORM                               = 58,
	R16_SINT                                = 59,
	R8_TYPELESS                             = 60,
	R8_UNORM                                = 61,
	R8_UINT                                 = 62,
	R8_SNORM                                = 63,
	R8_SINT                                 = 64,
	A8_UNORM                                = 65,
	R1_UNORM                                = 66,
	R9G9B9E5_SHAREDEXP                      = 67,
	R8G8_B8G8_UNORM                         = 68,
	G8R8_G8B8_UNORM                         = 69,
	BC1_TYPELESS                            = 70,
	BC1_UNORM                               = 71,
	BC1_UNORM_SRGB                          = 72,
	BC2_TYPELESS                            = 73,
	BC2_UNORM                               = 74,
	BC2_UNORM_SRGB                          = 75,
	BC3_TYPELESS                            = 76,
	BC3_UNORM                               = 77,
	BC3_UNORM_SRGB                          = 78,
	BC4_TYPELESS                            = 79,
	BC4_UNORM                               = 80,
	BC4_SNORM                               = 81,
	BC5_TYPELESS                            = 82,
	BC5_UNORM                               = 83,
	BC5_SNORM                               = 84,
	B5G6R5_UNORM                            = 85,
	B5G5R5A1_UNORM                          = 86,
	B8G8R8A8_UNORM                          = 87,
	B8G8R8X8_UNORM                          = 88,
	R10G10B10_XR_BIAS_A2_UNORM              = 89,
	B8G8R8A8_TYPELESS                       = 90,
	B8G8R8A8_UNORM_SRGB                     = 91,
	B8G8R8X8_TYPELESS                       = 92,
	B8G8R8X8_UNORM_SRGB                     = 93,
	BC6H_TYPELESS                           = 94,
	BC6H_UF16                               = 95,
	BC6H_SF16                               = 96,
	BC7_TYPELESS                            = 97,
	BC7_UNORM                               = 98,
	BC7_UNORM_SRGB                          = 99,
	AYUV                                    = 100,
	Y410                                    = 101,
	Y416                                    = 102,
	NV12                                    = 103,
	P010                                    = 104,
	P016                                    = 105,
	_420_OPAQUE                             = 106,
	YUY2                                    = 107,
	Y210                                    = 108,
	Y216                                    = 109,
	NV11                                    = 110,
	AI44                                    = 111,
	IA44                                    = 112,
	P8                                      = 113,
	A8P8                                    = 114,
	B4G4R4A4_UNORM                          = 115,

	P208                                    = 130,
	V208                                    = 131,
	V408                                    = 132,

	SAMPLER_FEEDBACK_MIN_MIP_OPAQUE         = 189,
	SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE = 190,

	FORCE_UINT                              = -1,
}

convert_format_dxgi ::  proc(format : Format)-> DXGI.FORMAT{
	result : DXGI.FORMAT
	for e in DXGI.FORMAT{
		if int(format) == int(e){
			return e
		}
	}
	return result
}

create_texture2d_view ::  proc(device : Device,format : Format,dim : m.float2,flags : D3D11.BIND_FLAG)-> ^D3D11.ITexture2D{
	using D3D11
	result : ^ITexture2D
	tex_desc : TEXTURE2D_DESC
	tex_desc.Width = u32(dim.x)
	tex_desc.Height = u32(dim.y)
	tex_desc.Format = convert_format_dxgi(format)
	
	sample_desc : DXGI.SAMPLE_DESC
	sample_desc.Count = 1
	sample_desc.Quality = 0
	tex_desc.SampleDesc = sample_desc
	tex_desc.ArraySize = 1
	tex_desc.BindFlags = flags

	hresult := (^IDevice)(device.ptr)->CreateTexture2D(&tex_desc,nil,&result)
	assert(hresult == 0)
	return result
}

create_render_target_dx11 ::  proc(device : Device,format : Format,dim : m.float2)-> RenderTarget{
	using D3D11
	using fmt
	assert(device.con.ptr != nil)
	assert(device.ptr != nil)

	result : RenderTarget

	result.tex_ptr = create_texture2d_view(device,format,dim,BIND_FLAG.RENDER_TARGET | BIND_FLAG.SHADER_RESOURCE)

	render_target_view : IRenderTargetView
	render_target_desc : RENDER_TARGET_VIEW_DESC

	render_target_desc.Format = DXGI.FORMAT.B8G8R8A8_UNORM
	render_target_desc.ViewDimension = RTV_DIMENSION.TEXTURE2D
	render_target_desc.Texture2D.MipSlice = 0

	render_target_view_ptr : ^IRenderTargetView
	hresult := (^IDevice)(device.ptr)->CreateRenderTargetView((^ITexture2D)(result.tex_ptr),&render_target_desc,&render_target_view_ptr)
	fmt.println(hresult)
	assert(hresult == 0)
	assert(render_target_view_ptr != nil)
	result.ptr = render_target_view_ptr
	return result
}

create_depth_stencil_dx11 :: proc(device : Device,format : Format,dim : m.float2) -> DepthStencil{
	using D3D11
	result : DepthStencil 
	depth_stencil_view_desc : DEPTH_STENCIL_VIEW_DESC 
	depth_stencil_view_desc.Format = convert_format_dxgi(format)
	depth_stencil_view_desc.Texture2D.MipSlice = 0
	depth_stencil_view_desc.Flags = 0
	depth_stencil_view_desc.ViewDimension = DSV_DIMENSION.TEXTURE2D
	
	depth_stencil_ptr : ^IDepthStencilView

	texture_view := create_texture2d_view(device,format,dim,BIND_FLAG.DEPTH_STENCIL)

	(^IDevice)(device.ptr)->CreateDepthStencilView((^ITexture2D)(texture_view),&depth_stencil_view_desc,&depth_stencil_ptr)
	assert(depth_stencil_ptr != nil)
	result.ptr = depth_stencil_ptr
	return result 
}

create_depth_stencil :: proc(device : Device,format : Format,dim : m.float2) -> DepthStencil{
	result : DepthStencil
	when RENDERER == RENDER_TYPE.DX11{
		result = create_depth_stencil_dx11(device,format,dim)
	}
	return result
}
create_render_target ::  proc(device : Device,format : Format,dim : m.float2)-> RenderTarget{
	result : RenderTarget
	when RENDERER == RENDER_TYPE.DX11{
		result = create_render_target_dx11(device,format,dim)
	}
	return result
}

create_render_target_back_buffer :: proc(device : Device) -> RenderTarget{
	result : RenderTarget
	when RENDERER == RENDER_TYPE.DX11{
		result = create_render_target_back_buffer_dx11(device)
	}
	return result
}

set_render_targets ::  proc(device : Device,render_targets : []RenderTarget,count : int){
	when RENDERER == RENDER_TYPE.DX11{
		set_render_targets_dx11(device,render_targets,count)
	}
}

set_render_targets_dx11 ::  proc(device : Device,render_targets : []RenderTarget,count : int){
	assert(device.ptr != nil && device.con.ptr != nil)
	result : [] ^D3D11.IRenderTargetView = make([]^D3D11.IRenderTargetView,count)
	for rt ,i in render_targets{
		assert(rt.ptr != nil)
		result[i] = (^D3D11.IRenderTargetView)(rt.ptr)
	}
	(^D3D11.IDeviceContext)(device.con.ptr)->OMSetRenderTargets(u32(count),&result[0],nil)
}

clear_render_target_dx11 ::  proc(device : Device,render_target : RenderTarget,clear_color : [4]f32){
	assert(device.con.ptr != nil)
	color := clear_color

	(^D3D11.IDeviceContext)(device.con.ptr)->ClearRenderTargetView((^D3D11.IRenderTargetView)(render_target.ptr),&color)
}

clear_render_target ::  proc(device : Device,render_target : RenderTarget,clear_color : [4]f32){
	color := clear_color
	clear_render_target_dx11(device,render_target,color)
}

clear_depth_stencil_dx11 :: proc(device : Device,depth_stencil : DepthStencil,clear_flag : D3D11.CLEAR_FLAG,depth_clear_value : f32,stencil_clear_value : u8){
	using D3D11
	assert(device.ptr != nil)
	assert(depth_stencil.ptr != nil)
	(^IDeviceContext)(device.con.ptr)->ClearDepthStencilView((^IDepthStencilView)(depth_stencil.ptr),clear_flag,depth_clear_value,stencil_clear_value)
}

clear_depth_stencil :: proc(device : Device,depth_stencil : DepthStencil,clear_flag : D3D11.CLEAR_FLAG,depth_clear_value : f32,stencil_clear_value : u8){
	when RENDERER == RENDER_TYPE.DX11{
		clear_depth_stencil_dx11(device,depth_stencil,clear_flag,depth_clear_value,stencil_clear_value)
	}
}
