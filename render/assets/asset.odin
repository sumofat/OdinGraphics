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

@(private="file")
asset_table : AssetTable

AssetTable :: struct{
	materials : con.Buffer(Material),
}

init_asset_table :: proc(){
	using con
	asset_table.materials = buf_init(1,Material)
}

get_material_by_id :: proc(id : u64)-> Material{
	using con
	material := buf_get(&asset_table.materials,id)
	//COuld do a check based on seslected render api for valid material
	return material
}

