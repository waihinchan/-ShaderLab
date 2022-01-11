float3x3 AngleAxis3x3(float angle, float3 axis) { //https://github.com/search?q=user%3Akeijiro+AngleAxis3x3&type=code
	float c, s;
	sincos(angle, s, c); //https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-sincos

	float t = 1 - c;
	float x = axis.x;
	float y = axis.y;
	float z = axis.z;

	return float3x3(
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c
	);
}
float3x3 GetTangetMartix(float4 t, float3 b, float3 n){
  return float3x3(
	t.x, b.x, n.x,
	t.y, b.y, n.y,
	t.z, b.z, n.z
	);
    
}
real3 TransformTangentToWorldDir(real3 dirWS, real3x3 tangentToWorld, bool doNormalize = false)
{
    // Note matrix is in row major convention with left multiplication as it is build on the fly
    float3 row0 = tangentToWorld[0];
    float3 row1 = tangentToWorld[1];
    float3 row2 = tangentToWorld[2];

    // these are the columns of the inverse matrix but scaled by the determinant
    float3 col0 = cross(row1, row2);
    float3 col1 = cross(row2, row0);
    float3 col2 = cross(row0, row1);

    float determinant = dot(row0, col0);

    // inverse transposed but scaled by determinant
    // Will remove transpose part by using matrix as the second arg in the mul() below
    // this makes it the exact inverse of what TransformWorldToTangentDir() does.
    real3x3 matTBN_I_T = real3x3(col0, col1, col2);
    real3 result = mul(dirWS, matTBN_I_T);
    if (doNormalize)
    {
        float sgn = determinant < 0.0 ? (-1.0) : 1.0;
        return SafeNormalize(sgn * result);
    }
    else
        return result / determinant;
}