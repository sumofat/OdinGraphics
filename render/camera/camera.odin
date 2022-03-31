package camera
import m "core:math/linalg/hlsl"

CameraProjectionType :: enum{
	PERSEPCTIVE,
	ORTHOGRAPHIC,
	SCREEN_SPACE,
}

Camera :: struct{
	mat : m.float4x4,
	projection_matrix : m.float4x4,
	projection_type : CameraProjectionType,
	near_far_planes : m.float2,
}
