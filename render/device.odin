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

DeviceContext :: struct{
	ptr : rawptr,
}

Device :: struct{
	ptr : rawptr,
	con : DeviceContext,
}

render_device : Device
//TODO(Ray)Here we would handle device attaching and reattaching as well as creation destruction etc..

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
	render_device = result
	return result
}

