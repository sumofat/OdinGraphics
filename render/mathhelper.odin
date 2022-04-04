
package render
import m "core:math/linalg/hlsl"
import "core:fmt"
import "core:c"
import la "core:math/linalg"

f4x4 :: la.Matrix4x4f32;
Quat :: la.Quaternionf32;

f4x4_identity :: la.MATRIX4F32_IDENTITY;
quat_identity :: la.QUATERNIONF32_IDENTITY

screen_to_world :: proc(projection_matrix : m.float4x4,cam_matrix : m.float4x4,buffer_dim : m.float2,screen_xy :  m.float2,z_depth :  f32) -> m.float3{
	using m
    result : float3;

    pc_mat := projection_matrix * cam_matrix
    inv_pc_mat := la.transpose(la.matrix4_inverse(la.Matrix4x4f32(pc_mat)));
    p := float4{
        2.0 * screen_xy.x / buffer_dim.x - 1.0,
        2.0 * screen_xy.y / buffer_dim.y - 1.0,
        z_depth,
        1.0,
    };

    w_div := la.matrix_mul_vector(inv_pc_mat,p);

    float3_w_div := float3{w_div.x,w_div.y,w_div.z};
    //    w := safe_ratio_zero(1.0f, w_div.w);
    w := 1 / w_div.w;

    return float3_w_div * w;
}

f4x4_create_row ::  proc(a,b,c,d : f32) -> f4x4
{
    r := f4x4{};
    r[0] = [4]f32{a,0,0,0};
    r[1] = [4]f32{0,b,0,0};
    r[2] = [4]f32{0,0,c,0};
    r[3] = [4]f32{0,0,0,d};    
    return r;    
}

rotate :: proc(q : la.Quaternionf32 ,dir : m.float3) -> m.float3{
	using m
    qxyz := float3{q.x,q.y,q.z};
    c := la.vector_cross3(qxyz, dir);
    t : float3 = 2.0 * c;
    a : float3 = q.w*t;
    ca : float3 = la.vector_cross3(qxyz, t);
    return (dir+a)+ca;
}

//allows for negative number wrap
safe_modulo :: proc(x : int , n : int)-> int{
    return (x % n + n) % n
}
