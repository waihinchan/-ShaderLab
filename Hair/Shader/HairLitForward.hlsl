#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


//各向异性+头发高光参数
TEXTURE2D(_ShiftMap);
SAMPLER(sampler_ShiftMap);
TEXTURE2D(_NoiseMap);
SAMPLER(sampler_NoiseMap);
float _primaryshift;
float _secnodaryshift;
float _exp1;
float _exp2;
float3 _SpecColor1;
float3 _SpecColor2;


struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings 
{   

    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1); 
    //这里等同于的效果就是
    // float2 lightmapUV: TEXCOORD1;
    // 或者： float2 vertexSH : TEXCOORD1;
    

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR) 
    float3 positionWS               : TEXCOORD2;
#endif
    float3 normalWS                 : TEXCOORD3;
    
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) //这里如果用了normal贴图就需要tangentWS了，但是我们一定需要使用，所以把这里注释掉
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
// #endif
    float3 viewDirWS                : TEXCOORD5; //同样这个也需要

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR) 
    float4 shadowCoord              : TEXCOORD7;
#endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR) //这个看看能用来干嘛，看意思应该是在切线空间下的viewspace，但是如果我们把所有的space都转换到worldspace的话这个应该也是不需要的
    float3 viewDirTS                : TEXCOORD8;
#endif

    float4 positionCS               : SV_POSITION; 
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData) 
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = SafeNormalize(input.viewDirWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output); 

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);


    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z); //fog还没有加入去后面再加
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap); 

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR) //我们一定需要tangentWS，所以这里屏蔽掉
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
// #endif
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
// #endif

#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR) 
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

//关键是获得main light 和 addition light，这里singleforward pass就是直接pass的，我们直接用来作为L即可
float3 shiftTangent(float3 T, float3 N, float shift){
    float3 shiftedT = T + shift * N;
    return normalize(shiftedT);
}
float StandardSpecular(float3 T, float3 V,float3 L,float exponent){
    float3 H = normalize(L + V);
    float3 dotTH = dot(T,H);
    float sinTH = sqrt(1.0 - dotTH * dotTH);
    float dirAtten = smoothstep(-1.0,0.0,dotTH);
    return dirAtten * pow(sinTH,exponent); 
    //这个指数越大应该影响范围越小 测试了一下的确可以控制范围但是高光总体感觉不是很平滑，有点硬，加了噪声会好一点，可能和贴图有一些关系
}
float3 HairSpecular(float3 tangent,float3 normal,float3 lightVec,float3 viewVec,float2 uv){
    float shiftTex = SAMPLE_TEXTURE2D(_ShiftMap,sampler_ShiftMap,uv).r; //假设shift是r通道
    float3 t1 = shiftTangent(tangent,normal,shiftTex + _primaryshift);
    float3 t2 = shiftTangent(tangent,normal,shiftTex + _secnodaryshift);

    float3 specular = _SpecColor1 * StandardSpecular(t1,viewVec,lightVec,_exp1); 
    float specMask = SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,uv).r; //这里其实可以合并到上面的shift纹理，然后甚至可以把alpha也合并到shift纹理中
    specular += _SpecColor2 * specMask * StandardSpecular(t2,viewVec,lightVec,_exp2); 

    return specular; //其他计算部分在外面完成
}
float3 HairDiffuse(float3 normal,float3 lightVec,float3 albedo){
    float3 diffuse = saturate(lerp(0.25,1.0,dot(normal,lightVec))) * albedo;//这个albedo直接来自于surfaceData，也就是maintex * baseColor的结果
    return diffuse;
}


float4 HairLighting(Varyings input){
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData); 
    //用副法线，unity的切线的方向有点问题（虽然不知道具体什么问题，但是知乎上是这么说，同时测试出来的结果也是这样）
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);

    Light mainLight;//copy from UniversalFragmentPBR function
    #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
        half4 shadowMask = inputData.shadowMask;
    #elif !defined (LIGHTMAP_ON)
        half4 shadowMask = unity_ProbesOcclusion;
    #else
        half4 shadowMask = half4(1, 1, 1, 1);
    #endif
    mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, shadowMask);
    #if defined(_SCREEN_SPACE_OCCLUSION)
        AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
        // mainLight.color *= aoFactor.directAmbientOcclusion; 
        //这里如果开启了screenspaceAO的话，光本身是会受到screenspaceAO的影响的，同时surfacedata中也自带一个AO，
        //暂时不清楚URP的PBR是怎么样计算AO的（即会不会计算两次还是），但是现阶段我们只计算一次，避免出现过暗的情况
        surfaceData.occlusion = min(surfaceData.occlusion, aoFactor.indirectAmbientOcclusion);
    #endif
    float3 hairdiffuse = HairDiffuse(inputData.normalWS,mainLight.direction,surfaceData.albedo);
    float3 hairspecular = HairSpecular(bitangent,inputData.normalWS,mainLight.direction,inputData.viewDirectionWS,input.uv);
    float4 final;
    final.rgb = (hairdiffuse + hairspecular) * mainLight.color * surfaceData.occlusion; 
    //ppt里面是把maintex放在最后来*的，而这里我把mainex放到albedo也就是diffuse那一项了

    //叠加addition lights
    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, inputData.positionWS, shadowMask);
            #if defined(_SCREEN_SPACE_OCCLUSION)
            light.color *= aoFactor.directAmbientOcclusion; //还是和上面提及到的一个问题
            #endif
            hairdiffuse = HairDiffuse(inputData.normalWS,light.direction,surfaceData.albedo);
            hairspecular = HairSpecular(bitangent,inputData.normalWS,light.direction,inputData.viewDirectionWS,input.uv);
            final.rgb += (hairdiffuse + hairspecular) * light.color;
        }
    #endif
    //叠加addition lights

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    final.rgb += inputData.vertexLighting * surfaceData.albedo; //这个顶点光默认使用一个one minuse diffuse来计算的，这里暂时先用albedo
    #endif
    final.a = surfaceData.alpha;
    return final;

}

half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
// #if defined(_PARALLAXMAP) 
// #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
//     half3 viewDirTS = input.viewDirTS;
// #else
//     half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS); 
// #endif
//     ApplyPerPixelDisplacement(viewDirTS, input.uv); 
// #endif
    // // 这里开始我们用我们自己的一些光照的方式。但是也要参照函数内一些获取光照的方法之类的
    // half4 color = UniversalFragmentPBR(inputData, surfaceData);

    // color.rgb = MixFog(color.rgb, inputData.fogCoord);
    // color.a = OutputAlpha(color.a, _Surface);

    // return color;
    // // 这里开始我们用我们自己的一些光照的方式。但是也要参照函数内一些获取光照的方法之类的

    float4 hairlight = HairLighting(input);
    return hairlight;
}

#endif

