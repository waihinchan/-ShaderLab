#ifndef GRASS_INPUT_INCLUDE
#define GRASS_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


CBUFFER_START(UnityPerMaterial)
//Base Stuff:
half4 _BaseColor;
half4 _EmissionColor;
half _BumpScale;
half _OcclusionStrength;
//Grass Stuff:
float4 _GroundMap_ST;

float _ZoffsetFactor;
float _Zlerp;
float _k;
float4 _ShadowColor;
float _ShadowFactor;
float _SpecularHighlights;
float _WindSpeed;
float _BlendGoundFactor;
CBUFFER_END

//这个部分我也想写进来 但是DOTS我还没看过 不知道是什么逻辑 就先不把额外的属性写进去这里了
#ifdef UNITY_DOTS_INSTANCING_ENABLED
UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DOTS_INSTANCED_PROP(float , _BumpScale)
    UNITY_DOTS_INSTANCED_PROP(float , _OcclusionStrength)
UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
#define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata__BaseColor)
#define _EmissionColor          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata__EmissionColor)
#define _BumpScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata__BumpScale)
#define _OcclusionStrength      UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata__OcclusionStrength)
#endif

//CUSTOM:
//Grass Map:
TEXTURE2D(_MetallicMap); SAMPLER(sampler_MetallicMap);
TEXTURE2D(_RoughnessMap); SAMPLER(sampler_RoughnessMap);
TEXTURE2D(_OcclusionMap);SAMPLER(sampler_OcclusionMap);
// TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);  //这个部分可能在SurfaceInput里面就有定义了 这里我们就不用写了
TEXTURE2D(_GroundBumpMap); SAMPLER(sampler_GroundBumpMap);
TEXTURE2D(_SliceBumpMap); SAMPLER(sampler_SliceBumpMap);
TEXTURE2D(_LookupBumpMap); SAMPLER(sampler_LookupBumpMap);
TEXTURE2D(_GrassBlade); SAMPLER(sampler_GrassBlade);
TEXTURE2D(_GroundMap);SAMPLER(sampler_GroundMap);
TEXTURE2D(_Windnoise);SAMPLER(sampler_Windnoise);
TEXTURE2D(_LookUpTex);SAMPLER(sampler_LookUpTex);
TEXTURE2D(_TileMap); SAMPLER(sampler_TileMap);

//CUSTOM:
//Some prop handle by shader Editor GUI
float _GrassHeight; 
#define MAX_RAYDEPTH 5
#define GRASS_TYPE 8 //分割成8个切片
#define GRASS_TYPE_INV (1.0/GRASS_TYPE)
#define GRASS_TYPE_INV_DIV2 (GRASS_TYPE_INV/2)
#define GRASSDEPTH GRASS_TYPE_INV/_GrassHeight
float _gridPerUnit; 
#define GRASSGRID _gridPerUnit

#define PLANE_NUM_INV 1/GRASSGRID
#define PLANE_NUM_INV_DIV2 PLANE_NUM_INV/2
#define  PREMULT  GRASSGRID * GRASS_TYPE_INV

//CUSTOM:
#include "SpaceTransformUtils.hlsl"
#include "utils.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "GrassParallax.hlsl"

half3 SampleGrassNormal(float2 uv,float alpha,float2 hitStatus,float scale)
{   
    
    #ifdef _GROUNDNORMAL
        half4 samplegroundNormal = SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, uv);
        #if BUMP_SCALE_NOT_SUPPORTED
            half3 groundNormal = UnpackNormal(samplegroundNormal);
        #else //BUMP_SCALE_NOT_SUPPORTED
            half3 groundNormal = UnpackNormalScale(samplegroundNormal, scale);
        #endif
    #else //_GROUNDNORMAL
        half3 groundNormal = half3(0.0h, 0.0h, 1.0h);
    #endif

    #ifdef _SLICENORMAL
        half4 samplesliceNormal = SAMPLE_TEXTURE2D(_SliceBumpMap, sampler_SliceBumpMap, uv);
        #if BUMP_SCALE_NOT_SUPPORTED
            half3 sliceNormal = UnpackNormal(samplesliceNormal);
        #else //BUMP_SCALE_NOT_SUPPORTED
            half3 sliceNormal = UnpackNormalScale(samplesliceNormal, scale);
        #endif
    #else //_SLICENORMAL
        half3 sliceNormal = half3(0.0h, 0.0h, 1.0h);
    #endif

    #ifdef _LOOKUPNORMAL
        half4 samplelookupNormal = SAMPLE_TEXTURE2D(_LookupBumpMap, sampler_LookupBumpMap, uv);
        #if BUMP_SCALE_NOT_SUPPORTED
            half3 lookupNormal = UnpackNormal(samplelookupNormal);
        #else //BUMP_SCALE_NOT_SUPPORTED
            half3 lookupNormal = UnpackNormalScale(samplelookupNormal, scale);
        #endif
    #else //_LOOKUPNORMAL
        half3 lookupNormal = half3(0.0h, 0.0h, 1.0h);
    #endif
    // return groundNormal;
    return groundNormal * hitStatus.x + sliceNormal * hitStatus.y + lookupNormal * (1 - hitStatus.x - hitStatus.y) ;

}

half3 SampleGrassMRE(float2 uv,float alpha,float2 hitStatus){
    #ifdef _METALLICMAP
        half3 sampleMetalic = SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).rgb;
        half Metalic = sampleMetalic.r * hitStatus.x + sampleMetalic.g * hitStatus.y + sampleMetalic.b * (1 - hitStatus.x - hitStatus.y);
    #else
        half Metalic = 0.1;
    #endif

    #ifdef _ROUGHNESSMAP
        half3 sampleRoughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).rgb;
        half Roughness = sampleRoughness.r * hitStatus.x + sampleRoughness.g * hitStatus.y + sampleRoughness.b * (1 - hitStatus.x - hitStatus.y);
    #else
        half Roughness = 0.5;
    #endif
    #ifdef _EMISSIONMAP
        half3 sampleEmission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb;
        half Emission = sampleEmission.r * hitStatus.x + sampleEmission.g * hitStatus.y + sampleEmission.b * (1 - hitStatus.x - hitStatus.y);
    #else
        half Emission = 0;
    #endif
    return half3(Metalic,Roughness,Emission);
}
half SampleGrassOcclusion(float2 uv,float alpha,float2 hitStatus)
{   
    //我们这里把_OcclusionMap的RGB都用上 R对应的是Ground G对应的是Slice B对应的是LookUp
    #ifdef _OCCLUSIONMAP
        // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
            half3 sampleocc = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).rgb;
            half occ = sampleocc.r * hitStatus.x + sampleocc.g * hitStatus.y + sampleocc.b * (1 - hitStatus.x - hitStatus.y); 

            return occ;       
        #if defined(SHADER_API_GLES)
            return occ;
        #else
            return LerpWhiteTo(occ, _OcclusionStrength);
        #endif

    #else//_OCCLUSIONMAP
        return 1.0;
    #endif
}

inline void InitializeGrassSurfaceData(float2 uv, GrassParllaxResult result,out SurfaceData outSurfaceData)
{   
    //CUSTOM:
    // 我们已经有草的albedo了 而且这个东西他不是透明的（虽然队列里面可能是在opaque后面的）
    // 我们这里直接用MRE的工作流 这个Unity搞一大堆有的没的 其实没啥卵用。
    outSurfaceData.albedo = float4(result.outAlbedo.xyz,1) * _BaseColor;
    outSurfaceData.alpha = 1;
    float2 hitStatus = float2(result.hitGround,result.hitSlice);
    //MREAO
    half3 MRE = SampleGrassMRE(result.outUV,result.outAlbedo.w,hitStatus);
    outSurfaceData.metallic = MRE.x;
    outSurfaceData.smoothness = 1 - MRE.y;
    outSurfaceData.emission = _EmissionColor.rgb * MRE.z;
    outSurfaceData.specular = half3(0.0,0.0,0.0);
    outSurfaceData.occlusion = SampleGrassOcclusion(result.outUV,result.outAlbedo.w,hitStatus);
    //Normal
    outSurfaceData.normalTS = SampleGrassNormal(result.outUV,result.outAlbedo.w,hitStatus,_BumpScale);
    outSurfaceData.clearCoatMask       = 0.0h;
    outSurfaceData.clearCoatSmoothness = 0.0h;

}


#endif
