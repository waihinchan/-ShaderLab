#ifndef UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED
#define UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"


float3 _LightDirection;
sampler2D _Noise;
sampler2D _Splat; //control where to displacement
float _Weight;
float _Tess;
float _MaxTessDistance;
TEXTURE2D(_Ground);
SAMPLER(sampler__Ground);
float3 Displacement(float Noise,float Weight,float3 oldPosition){ 
    //can do some custom function here.
    return oldPosition * Noise * Weight;
} 
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    // UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

Varyings ShadowPassTessVertex(Attributes input)
{
    Varyings output;
    // UNITY_SETUP_INSTANCE_ID(input);
    float Noise = tex2Dlod(_Noise, float4(input.texcoord, 0, 0)).r ;
    input.positionOS.xyz += Displacement(Noise,_Weight,input.normalOS) * tex2Dlod(_Splat, float4(input.texcoord, 0, 0)).r;
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

// struct ControlPoint
// {
//     float4 positionOS   : INTERNALTESSPOS;
//     float3 normalOS     : NORMAL;
//     float2 texcoord     : TEXCOORD0;
//     // UNITY_VERTEX_INPUT_INSTANCE_ID
// };
// struct TessellationFactors
// {
//     float edge[3] : SV_TessFactor;
//     float inside : SV_InsideTessFactor;
// };
// ControlPoint TessellationShadowVertexProgram(Attributes v) //控制点控制如何生成细分面
// {
//     ControlPoint p;
//     //copy and paste, just a pass
//     p.positionOS = v.positionOS;
//     p.normalOS = v.normalOS;
//     p.texcoord = v.texcoord;

//     return p;
// }
// [UNITY_domain("tri")] 
// Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation) //step3
// {
//     Attributes v;
//     #define DomainPos(fieldName) v.fieldName = patch[0].fieldName * barycentricCoordinates.x + patch[1].fieldName * barycentricCoordinates.y + patch[2].fieldName * barycentricCoordinates.z;
//     DomainPos(positionOS)
//     DomainPos(normalOS)
//     DomainPos(texcoord)

//     return ShadowPassVertex(v);  
// }
// [UNITY_domain("tri")]
// [UNITY_outputcontrolpoints(3)]
// [UNITY_outputtopology("triangle_cw")]
// [UNITY_partitioning("fractional_odd")]
// //[UNITY_partitioning("fractional_even")]
// //[UNITY_partitioning("pow2")]
// //[UNITY_partitioning("integer")]
// [UNITY_patchconstantfunc("patchConstantFunction")]
// ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID) //step1
// {
//     return patch[id];
// }
// // fade tessellation at a distance
// float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
// {
//     float3 worldPosition = TransformObjectToWorld(vertex.xyz);
//     float dist = distance(worldPosition, _WorldSpaceCameraPos);
//     float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
//     return (f);
// }
// // tessellation
// TessellationFactors patchConstantFunction(InputPatch<ControlPoint, 3> patch) //step2
// {
//     // values for distance fading the tessellation
//     float minDist = 5.0;
//     float maxDist = _MaxTessDistance;

//     TessellationFactors f;

//     float edge0 = CalcDistanceTessFactor(patch[0].positionOS, minDist, maxDist, _Tess);
//     float edge1 = CalcDistanceTessFactor(patch[1].positionOS, minDist, maxDist, _Tess);
//     float edge2 = CalcDistanceTessFactor(patch[2].positionOS, minDist, maxDist, _Tess);
    
//     // make sure there are no gaps between different tessellated distances, by averaging the edges out.
//     f.edge[0] = (edge1 + edge2) / 2;
//     f.edge[1] = (edge2 + edge0) / 2;
//     f.edge[2] = (edge0 + edge1) / 2;
//     f.inside = (edge0 + edge1 + edge2) / 3;
//     return f;
// }
#endif