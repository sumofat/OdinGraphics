package asset

import D3D11 "vendor:directx/d3d11"
import D3D12 "vendor:directx/d3d12"
import DXGI  "vendor:directx/dxgi"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import runtime "core:runtime"
import la "core:math/linalg"
import m "core:math/linalg/hlsl"
import fmt "core:fmt"
import con "../../containers"
import camera "../camera"

Material :: struct{
	id : u64,
	name : string,
	pipeline_state : rawptr,
	base_textue_id : u64,
	base_color : m.float4,
}



