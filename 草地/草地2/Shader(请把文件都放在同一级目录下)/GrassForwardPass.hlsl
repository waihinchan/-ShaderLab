#ifndef GRASS_LIT_FORWARD_PASS_INLUDED
#define GRASS_LIT_FORWARD_PASS_INLUDED

// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

//CUSTOM:
// 我们没有视差贴图：
// // GLES2 has limited amount of interpolators
// #if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
// #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
// #endif

//CUSTOM:
//同理这里删掉(defined(_PARALLAXMAP)
//然后我们也需要切线空间下的ViewDir插值器，但是这些东西由我们自己来计算就可以了。
// #if (defined(_NORMALMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
// #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
// #endif

// keep this file in sync with LitGBufferPass.hlsl

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
//CUSTOM:
// #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR) //我们这里可以定义然后找到我们需要的东西 但实际上我们直接手写插值器就可以了
    float3 positionWS               : TEXCOORD2;
// #endif

    float3 normalWS                 : TEXCOORD3;
//CUSTOM:
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) //同上
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
// #endif
    float3 viewDirWS                : TEXCOORD5;

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD7;
#endif

//CUSTOM:
// #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR) //我们把切线空间的ViewDir留到Frag阶段再去计算
    // float3 viewDirTS                : TEXCOORD8;
// #endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};
//CUSTOM:
struct FragmentOutput //输出color和深度 SV_POSITION不用修改
{
    float4 color : SV_Target0;
    float outdepth : SV_Depth;
    
};
void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

// #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
// #endif

    half3 viewDirWS = SafeNormalize(input.viewDirWS);
// #if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
// #else
    inputData.normalWS = input.normalWS;
// #endif

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
    //CUSTOM:
    //Unity默认的应该是view - vertex, 但实际数学运算中我们应该是用vertex - view. 且我们在视差的计算需要的方向的确为vertex to veiw，而非view to vertex。
    half3 viewDirWS = -(_WorldSpaceCameraPos - vertexInput.positionWS ); //faster than GetCurrentViewPosition()
    // half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    //CUSTOM:
    output.uv = input.texcoord; //草切片的UV和Ground的UV要分开，我们先默认这里不做任何tilling(可以考虑做一下offset)

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    
    
    output.viewDirWS = viewDirWS;
//CUSTOM:
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
// #endif
//CUSTOM:
// #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
// #endif

//CUSTOM 在Fragment阶段在做这个事情
// #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    // half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    // output.viewDirTS = viewDirTS;
// #endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

// #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
// #endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
//CUSTOM:
//我们需要输出Color和Depth 所以这里修改一下语义
FragmentOutput LitPassFragment(Varyings input) 
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    //CUSTOM:
    FragmentOutput o = (FragmentOutput)0;

//CUSTOM 无视差：
// #if defined(_PARALLAXMAP)
// #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
//     half3 viewDirTS = input.viewDirTS;
// #else
//     half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
// #endif
//     ApplyPerPixelDisplacement(viewDirTS, input.uv);
// #endif
    GrassRawData rawdata;
    rawdata.viewDirWS = input.viewDirWS;

    rawdata.uv = input.uv;
    rawdata.tangentWS = input.tangentWS;
    rawdata.normalWS = input.normalWS;
    rawdata.posWS = input.positionWS;
    rawdata.winduv = (input.uv + _Time.y * _WindSpeed)/2;

    GrassParllaxResult grass_result = getGrass(rawdata);

    SurfaceData surfaceData;
    InitializeGrassSurfaceData(input.uv,grass_result,surfaceData);
    input.viewDirWS *= -1;
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    half4 color = UniversalFragmentPBR(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    // color.rgb = surfaceData.normalTS;
    // color.a = OutputAlpha(color.a, _Surface);
    color.a = 1;
    o.color = color;

    o.outdepth = grass_result.outDepth;
    return o;
}

#endif
