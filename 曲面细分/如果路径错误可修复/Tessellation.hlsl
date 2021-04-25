#ifndef TESSELLATIONINCLUDE
#define TESSELLATIONINCLUDE
#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
#define UNITY_CAN_COMPILE_TESSELLATION 1
#   define UNITY_domain                 domain
#   define UNITY_partitioning           partitioning
#   define UNITY_outputtopology         outputtopology
#   define UNITY_patchconstantfunc      patchconstantfunc
#   define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};
struct ControlPoint
{
    float4 positionOS   : INTERNALTESSPOS;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
#if defined(UNIVERSALFORWARD)
    float4 tangentOS    : TANGENT;
    float2 lightmapUV   : TEXCOORD1;
#endif
};
ControlPoint TessellationVertexProgram(Attributes v) //控制点控制如何生成细分面
{
    ControlPoint p;
    //copy and paste, just a pass
    p.positionOS = v.positionOS;
    p.normalOS = v.normalOS;
    p.texcoord = v.texcoord;
#if defined(UNIVERSALFORWARD)
    p.tangentOS = v.tangentOS;
    p.lightmapUV = v.lightmapUV;
#endif

    return p;
}
ControlPoint TessellationShadowVertexProgram(Attributes v) //控制点控制如何生成细分面
{
    ControlPoint p;
    //copy and paste, just a pass
    p.positionOS = v.positionOS;
    p.normalOS = v.normalOS;
    p.texcoord = v.texcoord;

    return p;
}

[UNITY_domain("tri")] 
Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation) //step3
{
    Attributes v;
    #define DomainPos(fieldName) v.fieldName = patch[0].fieldName * barycentricCoordinates.x + patch[1].fieldName * barycentricCoordinates.y + patch[2].fieldName * barycentricCoordinates.z;
    DomainPos(positionOS)
    DomainPos(normalOS)
    DomainPos(texcoord)
#if defined(UNIVERSALFORWARD)
    DomainPos(tangentOS)
    DomainPos(lightmapUV)
    return LitPassTessVertex(v);
#else
    return ShadowPassTessVertex(v);
#endif

}
[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
//[UNITY_partitioning("fractional_even")]
//[UNITY_partitioning("pow2")]
//[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID) //step1
{
    return patch[id];
}
// fade tessellation at a distance
float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
{
    float3 worldPosition = TransformObjectToWorld(vertex.xyz);
    float dist = distance(worldPosition, _WorldSpaceCameraPos);
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
    return (f);
}
// tessellation
TessellationFactors patchConstantFunction(InputPatch<ControlPoint, 3> patch) //step2
{
    // values for distance fading the tessellation
    float minDist = 5.0;
    float maxDist = _MaxTessDistance;

    TessellationFactors f;

    float edge0 = CalcDistanceTessFactor(patch[0].positionOS, minDist, maxDist, _Tess);
    float edge1 = CalcDistanceTessFactor(patch[1].positionOS, minDist, maxDist, _Tess);
    float edge2 = CalcDistanceTessFactor(patch[2].positionOS, minDist, maxDist, _Tess);
    
    // make sure there are no gaps between different tessellated distances, by averaging the edges out.
    f.edge[0] = (edge1 + edge2) / 2;
    f.edge[1] = (edge2 + edge0) / 2;
    f.edge[2] = (edge0 + edge1) / 2;
    f.inside = (edge0 + edge1 + edge2) / 3;
    return f;
}
#endif