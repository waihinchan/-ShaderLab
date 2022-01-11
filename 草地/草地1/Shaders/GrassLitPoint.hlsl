#ifndef GRASS_FORWARD_LIT_PASS_INCLUDED
#define GRASS_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#define BLADE_SEGMENTS 4

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

float _MaxHeight;
float _MaxWidth;
float3 _BottomColor;
float3 _TopColor;
float _ScaleFactor;
sampler2D _WindDistortionMap;
//tex2d only used in frag, we use this in vertex stage, so use tex2dlod
// TEXTURE2D(_WindDistortionMap);
// SAMPLER(sampler__WindDistortionMap);

float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;
float _BladeCurve;
float _BladeForward;

sampler2D _InteractMap; //这个用来做交互

//position的WSVS这些似乎在GEO里面失效了。具体原因不明
//所以要保留切线法线texcoord和lightmapuv这些，但是把wsvs这些传递进去。
//refernece:
// VertexPositionInputs GetVertexPositionInputs(float3 positionOS)
// {
//     VertexPositionInputs input;
//     input.positionWS = TransformObjectToWorld(positionOS);
//     input.positionVS = TransformWorldToView(input.positionWS);
//     input.positionCS = TransformWorldToHClip(input.positionWS);

//     float4 ndc = input.positionCS * 0.5f;
//     input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
//     input.positionNDC.zw = input.positionCS.zw;

//     return input;
// }
struct Attributes //appdata to vert
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT; //在shadow仍然需要切线和uv坐标来采样风和增加顶点
    float2 texcoord     : TEXCOORD0;
    #if !defined(SHADOW_CASTER) 
        float2 lightmapUV   : TEXCOORD1;
    #endif
    // UNITY_VERTEX_INPUT_INSTANCE_ID

};


struct v2g //vert to geo
{
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float4 positionOS   : POSITION; //这里用于交互计算，因为intercmap传进来的是localpos，如果传worldpos的话贴图那边不是很好处理
    float4 positionCS   : TEXCOORD4;
    float3 positionWS   : TEXCOORD2;
    #if !defined(SHADOW_CASTER)
        float3 positionVS   : TEXCOORD3;
        float2 lightmapUV   : TEXCOORD1;
    #endif
};

struct Varyings //geo to frag
{   


#if !defined(SHADOW_CASTER) 

        float2 uv                       : TEXCOORD0;
        DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            float3 positionWS               : TEXCOORD2;
        #endif

            float3 normalWS                 : TEXCOORD3;
        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
            float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
        #endif
            float3 viewDirWS                : TEXCOORD5;

            half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            float4 shadowCoord              : TEXCOORD7;
        #endif

        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            float3 viewDirTS                : TEXCOORD8;
        #endif

            float4 positionCS               : SV_POSITION;
            // UNITY_VERTEX_INPUT_INSTANCE_ID
            // UNITY_VERTEX_OUTPUT_STEREO
    #else
        float2 uv           : TEXCOORD0;
        float4 positionCS   : SV_POSITION;
    #endif
};

float3 _LightDirection;
float4 GetShadowPositionHClip(v2g input)
{
    // float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS); //这个要用part1做一下转换

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(input.positionWS, normalWS, _LightDirection));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}


#if !defined(SHADOW_CASTER)
    void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

        half3 viewDirWS = SafeNormalize(input.viewDirWS);
    #if defined(_NORMALMAP) || defined(_DETAIL)
        float sgn = input.tangentWS.w;      
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
#endif
///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////


Varyings ShadowPassVertex(v2g input)
{
    Varyings output;
    // UNITY_SETUP_INSTANCE_ID(input);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);//这个basemap后面可以改成别的，因为如果分层或者是给草的纹理贴图的话就没有basemap的说法
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}
#if !defined(SHADOW_CASTER)
VertexPositionInputs rePackVertexInputs(v2g v){ //这里就是把上面某一些数给重新打包回来了
    VertexPositionInputs input;
    input.positionWS = v.positionWS;
    input.positionVS = v.positionVS;
    input.positionCS = v.positionCS;
    float4 ndc = input.positionCS * 0.5f;
    input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
    input.positionNDC.zw = input.positionCS.zw;
    return input;
}
#endif
v2g LitPassVertexPart1(Attributes input)
{
    v2g output;
    output.positionOS = input.positionOS;
    // UNITY_SETUP_INSTANCE_ID(input);
    // UNITY_TRANSFER_INSTANCE_ID(input, output);
    // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    #if !defined(SHADOW_CASTER) 
        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        //custom here:
        output.positionWS = vertexInput.positionWS;
        output.positionVS = vertexInput.positionVS;
        output.positionCS = vertexInput.positionCS;
        output.texcoord = input.texcoord;
        output.lightmapUV = input.lightmapUV;
        output.tangentOS = input.tangentOS;
        output.normalOS = input.normalOS;
        // 法线切线转换与否目前没有法线什么区别。
        // 原做法是object space + tangenttolocal， 然后再把整体转换到object
        // 现在是world space + tangenttoworld， 然后就不用在转换了。
        // 所以关键在于法线应该要转换到world的，但是这里似乎不转换也不影响结果。。
    #else
        //在常规阴影下只需要cs和uv，但是由于这个部分是pass到geo,所以还需要ws normal 和 tangent
        //这里参照上面的写一下，把不需要的删除掉即可
        //然后同样地在geo里面把真正的shadow vertex写进去
        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        output.positionWS = vertexInput.positionWS;
        output.positionCS = vertexInput.positionCS;
        output.texcoord = input.texcoord;
        output.tangentOS = input.tangentOS;
        output.normalOS = input.normalOS;

    #endif

    return output;
}
#if !defined(SHADOW_CASTER)
    Varyings LitPassVertexPart2(v2g input) //这个部分不要涉及到o2w的操作因为不明原因失效。
    {
        Varyings output = (Varyings)0;


        // UNITY_SETUP_INSTANCE_ID(input);
        // UNITY_TRANSFER_INSTANCE_ID(input, output);
        // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        // VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); //already done at part1
        VertexPositionInputs vertexInput = rePackVertexInputs(input);

        // normalWS and tangentWS already normalize.
        // this is required to avoid skewing the direction during interpolation
        // also required for per-vertex lighting and SH evaluation
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

        half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

        // already normalized from normal transform to WS.
        output.normalWS = normalInput.normalWS;
        output.viewDirWS = viewDirWS;
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        output.tangentWS = tangentWS;
    #endif

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
#endif
half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}
#if !defined(SHADOW_CASTER)
half4 LitPassFragment(Varyings input) : SV_Target
{
    // UNITY_SETUP_INSTANCE_ID(input);
    // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    // half4 color = half4(0,0,0,1);
    // #ifndef UNIVERSALFORWARD
        // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
        // return color;
    // #else
    
        #if defined(_PARALLAXMAP)
        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirTS = input.viewDirTS;
        #else
            half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
        #endif
            ApplyPerPixelDisplacement(viewDirTS, input.uv);
        #endif


            SurfaceData surfaceData;
            InitializeStandardLitSurfaceData(input.uv, surfaceData);

            InputData inputData;
            InitializeInputData(input, surfaceData.normalTS, inputData);
            surfaceData.albedo = lerp(_BottomColor,_TopColor,input.uv.y);
            half4 color = UniversalFragmentPBR(inputData, surfaceData);

            color.rgb = MixFog(color.rgb, inputData.fogCoord);
            color.a = OutputAlpha(color.a, _Surface);

            return color;
    // #endif
}
#endif
float3x3 GetTangetMartix(float4 t, float3 b, float3 n){
  return float3x3(
	t.x, b.x, n.x,
	t.y, b.y, n.y,
	t.z, b.z, n.z
	);
    
}

v2g rePackv2g(v2g input,float3 worldPosition,float2 uv){
    v2g v;
    v.texcoord = uv;
    v.positionWS = worldPosition;
    v.positionCS = TransformWorldToHClip(v.positionWS);
    v.normalOS = input.normalOS; //这个normal应该还需要修改，比如说平面的normal在世界空间下应该是(0,1,0),但是叶片应该是垂直于叶面的（要考虑到旋转的因素）
    v.tangentOS = input.tangentOS;
#if !defined(SHADOW_CASTER) 
    v.lightmapUV = input.lightmapUV;
    v.positionVS = TransformWorldToView(v.positionWS);
#endif
    return v;
}
float rand(float3 seed) {
	return frac(sin(dot(seed.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}
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
[maxvertexcount(BLADE_SEGMENTS * 2 + 1)] 
//BLADE_SEGMENTS 是左右两个控制点个数， 比如说3个控制点，即可左右共6个。最后要加上顶端的一个顶点即*2+1
//如果把循环独立出来的话，那就是 2 + 1(底端两个控制点 + 顶端一个) + N * 2个控制点
//示例中还有一个根据视距来生成点的，这个后期联动镶嵌一起做了。
void GrassGeometry(point v2g input[1], uint pid : SV_PrimitiveID,inout TriangleStream<Varyings> outStream){
    //splatmap在draw的时候需要传递一个程度数值，也就是遮罩的RGB通道指定了方向梯度，也就是这个叶子应该往哪个方向弯折
    //A通道用于指示弯折程度，这些计算可以脚本中计算。

    float4 interactParams =  tex2Dlod(_InteractMap, float4(input[0].texcoord, 0, 0));
    //这里本来应该是用位置，但是这里用程度来代替，也就是说最中央和边缘的范围涉及到他的体积之类的
    float3 interactPos = interactParams.rgb;
    float radius = interactParams.a;

    if(radius>=0.1){ 
        //这里可以防止穿模以及一些交互范围过大出现穿帮的情况
        //测试过如果体积还是很小的话也没办法，始终会穿一些草出来
        return;
    }
    float3 localPos = input[0].positionOS;
    float3 direction = normalize(localPos - interactPos);
    direction = clamp(direction * radius * 10,-0.3,0.3);
    float3 n = input[0].normalOS;
    float4 t = input[0].tangentOS;
    float3 b = cross(n,t) * t.w;
    float3 worldPos = input[0].positionWS;
    // direction.y = 0;
    // worldPos += direction;
    float height =  rand(worldPos.yzx) * _MaxHeight * _ScaleFactor;
    float width =  rand(worldPos.xzy) * _MaxWidth * _ScaleFactor;
    float3x3 facingRotationMatrix = AngleAxis3x3(rand(worldPos) * 3.14 * 2, float3(0, 0, 1));
    float3x3 bendRotationMatrix = AngleAxis3x3(rand(worldPos.zzx) * 0.2 * 3.14 * 0.5, float3(-1, 0, 0));
    float2 wind_uv = input[0].texcoord * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
    

    float2 windSample = (tex2Dlod(_WindDistortionMap, float4(wind_uv, 0, 0)).xy * 2 - 1) * _WindStrength; 
    //这里windsteng参与了矩阵运算，所以如果是0的情况会发生草的位置完全错乱的情况。可以设一个如果是风的强度是0就是风的矩阵单位矩阵之类的。
    //因为整个转换矩阵包含了叶片随机分割的朝向，本来是按照教程做的，但是这里要再分离觉得也有点麻烦（只要单独改风的转换矩阵就可以了）
    float3 wind = normalize(float3(windSample.x,windSample.y,0));
    float3x3 windmartix = AngleAxis3x3(windSample.x ,wind);

    float3x3 transformWindMartix =   mul(mul(mul( GetTangetMartix(t,b,n),facingRotationMatrix),bendRotationMatrix),windmartix);
    // 首先转换到切线空间，然后绕z轴随机旋转。
    // 然后草有一些会低头，所以再给一个绕x轴
    // 最后给一个风向旋转。旋转的轴根据情况可以自己修改。
    float3x3 transformMartix =   mul( GetTangetMartix(t,b,n),facingRotationMatrix); 
    // 根部的不随着风旋转不然会出界
    
    
    //底端的两个形状
    float3 p0 = worldPos + mul(transformMartix,float3(width,0,0)); //left
    v2g v0 = rePackv2g(input[0],p0,float2(0,0)); //这里uv要重新映射一下，三角形底端，x ：0-1，顶点刚好在中间最上方，y：0.5
    float3 p1 = worldPos + mul(transformMartix,float3(-width,0,0)); //right
    v2g v1 = rePackv2g(input[0],p1,float2(1,0));
#if !defined(SHADOW_CASTER) 
    outStream.Append(LitPassVertexPart2(v0));
    outStream.Append(LitPassVertexPart2(v1));
    //底端的两个形状
#else
    outStream.Append(ShadowPassVertex(v0));
    outStream.Append(ShadowPassVertex(v1));
#endif

    


    float forward = rand(worldPos.yyz) * _BladeForward;
    for(int i = 1;  i < BLADE_SEGMENTS; i++){ 
        //从1开始是因为最底端的两个控制点单独生成，然后如果不增加曲面的话BLADE_SEGMENTS最低应该是1。
        // float3x3 tran = i == 0? transformMartix : transformWindMartix;
        float count = i / (float)BLADE_SEGMENTS; //from bottom to top
        float segmentHeight = height * count;
        float segmentWidth = width * (1 - count);
        float segmentForward = pow(count, _BladeCurve) * forward;
        // 中间点的左边
        float3 middlepos_left = worldPos + direction + mul(transformWindMartix,  (float3(segmentWidth,segmentForward,segmentHeight))) ;
        v2g middlspoint_left = rePackv2g(input[0],middlepos_left,float2(count,count));
        //中间点的uv在高度上应该是0-1之间。
        //左右的点在三角面来看应该是介于0，1之间，即可 0.2， 0.8这样
        //即越往上范围越小。 
        
        float3 middlepos_right = worldPos + direction + mul(transformWindMartix,   float3(-segmentWidth,segmentForward,segmentHeight)) ;
        v2g middlspoint_right = rePackv2g(input[0],middlepos_right,float2(1-count,count));
#if !defined(SHADOW_CASTER)        
        outStream.Append(LitPassVertexPart2(middlspoint_left)); 
        outStream.Append(LitPassVertexPart2(middlspoint_right));
#else
        outStream.Append(ShadowPassVertex(middlspoint_left));
        outStream.Append(ShadowPassVertex(middlspoint_right));
#endif
    }
    
    float segmentForward = pow(1, _BladeCurve) * forward;
    float3 p2 = worldPos + direction + mul(transformWindMartix,float3(0,segmentForward,height)); //top
    v2g v2 = rePackv2g(input[0],p2,float2(0.5,1)); //如果顶点的位置是随机的（而不是只有随即高度的话），uv感觉也可以根据随机值来。
    
#if !defined(SHADOW_CASTER)   
    outStream.Append(LitPassVertexPart2(v2));
#else
    outStream.Append(ShadowPassVertex(v2));
#endif


    outStream.RestartStrip();
    //do nothing here
    // outStream.Append(LitPassVertexPart2(input[0]));
    // outStream.Append(LitPassVertexPart2(input[1]));
    // outStream.Append(LitPassVertexPart2(input[2]));
    //do nothing here
}

#endif

//改进思路：顶点颜色用于最后的diffuse，这样方便我们直接用工具来给顶点颜色调（也有一个可能性是用贴图）
//uv用于编辑高低的草高和宽，也就是说我们用工具在不同的地方编辑他的uv来控制草的一些高低长势
//基于distance来减少叶片的分割数量，提升性能
//用point而非三角形，这样同时也不使用曲面细分
//用pass进去的position来使做交互，其实就是弯折叶片的分割位置，使其不一定底部但是移动其上部。
//如果用splatmap来做的话，r通道用于遮罩，g用于position，b用于radius也就是碰撞体积或者说弯折程度
//这样要求uv没有被更改，也就是说不能用来储存草的高低了，因为如果改变了uv的位置就和模型本身的位置对不上了。看看用一个额外的uv2之类的。
//同时工具里面要使得uv和原本用于碰撞检测的模型的uv所匹配（一般是平地），这个需要测试


//TODO：现阶段splatmap部分已经完成了 顶点颜色和基于distance减少分割面数量的还没有做，懒得做- -
//关于diffuse和一些什么混合贴图和法线的也没有做，到时候直接写一个脚本来调整吧。这些都是重复的工作懒得搞了