package render

import "core:fmt"
import "core:c"

import m "core:math/linalg/hlsl"
import linalg "core:math/linalg"

Transform :: struct{
//world trans   s
    p : m.float3,
    r : linalg.Quaternionf32,
    s : m.float3,
//local trans
    local_p : m.float3,    
    local_r : linalg.Quaternionf32,
    local_s : m.float3,
//matrix
    mat  : m.float4x4,
//local axis
    forward : m.float3,
    up : m.float3,
    right : m.float3,
}

transform_init :: proc() -> Transform{
    using linalg;
    ot : Transform;
    ot.r = QUATERNIONF32_IDENTITY;
    ot.s = m.float3{1,1,1};
    ot.p = m.float3{0,0,0};
    ot.local_r = QUATERNIONF32_IDENTITY;
    ot.local_s = m.float3{1,1,1};
    ot.local_p = m.float3{0,0,0};
    transform_update(&ot);
    return ot;
}

transform_matrix_set :: proc(ot : ^Transform){
	using linalg
    ot.mat = m.float4x4(linalg.matrix4_from_trs(Vector3f32( ot.p),ot.r,Vector3f32(ot.s)))
}

quaternion_up :: proc(q : linalg.Quaternionf32) -> m.float3{
	using linalg
    a := linalg.quaternion_mul_vector3(q, m.float3{0, 1, 0});
    return linalg.vector_normalize(a);
}

quaternion_forward :: proc(q : linalg.Quaternionf32) -> m.float3{
	using linalg
    return vector_normalize(mul(q, m.float3{0, 0, 1}));
}

quaternion_right :: proc(q : linalg.Quaternionf32) -> m.float3
{
	using linalg
    return vector_normalize(mul(q, m.float3{1, 0, 0}));
}

transform_update :: proc(ot : ^Transform)
{
    transform_matrix_set(ot);
    ot.up = quaternion_up(ot.r); 
    ot.right = quaternion_right(ot.r);
    ot.forward = quaternion_forward(ot.r);
}

set_camera_view_pos_forward_up :: proc(p : m.float3,d : m.float3,u : m.float3) -> m.float4x4{
    using linalg
    cam_right := cross(u, d);
    cam_up := cross(d, cam_right);
    d := normalize(d);
    m : m.float4x4 = m.float4x4{}

    m[0][0] = cam_right.x
    m[0][1] = cam_up.x
    m[0][2] = d.x

    m[1][0] = cam_right.y
    m[1][1] = cam_up.y
    m[1][2] = d.y

    m[2][0] = cam_right.z
    m[2][1] = cam_up.z
    m[2][2] = d.z

    m[3][0] = -dot(cam_right,p)
    m[3][1] = -dot(cam_up,p)
    m[3][2] = -dot(d,p)
    m[3][3] = 1

    return m
}

set_camera_view_ot :: proc(ot : ^Transform) -> m.float4x4{
    transform_update(ot);
    return set_camera_view(ot.p,ot.forward,ot.up);
}

set_camera_view :: proc{set_camera_view_ot,set_camera_view_pos_forward_up}



