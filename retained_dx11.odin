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

/*
Create a retained mode renderer 
1. Take in state calls
2. Take in remove state calls
3. Every frame check if state has changed and than remove replace add any state that needs it.
4. Execute the commands on that state.

I like how we structured it in Odin lets replicate that and clean it up here.
*/



