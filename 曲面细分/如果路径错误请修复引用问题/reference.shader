
Shader "Example/URPUnlitShaderBasic"
{

    Properties
    { 
        _Tess("Tessellation", Range(1, 32)) = 10
		_MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
		_Noise("Noise", 2D) = "gray" {}
		_Weight("Displacement Amount", Range(0, 1)) = 0
    }

    
    SubShader
    {

        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
           
            HLSLPROGRAM
            //requirement
            #if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
            #define UNITY_CAN_COMPILE_TESSELLATION 1
            #   define UNITY_domain                 domain
            #   define UNITY_partitioning           partitioning
            #   define UNITY_outputtopology         outputtopology
            #   define UNITY_patchconstantfunc      patchconstantfunc
            #   define UNITY_outputcontrolpoints    outputcontrolpoints
            #endif
            //requirement
            
           //***************************************//
            #pragma require tessellation //kind of geometry stage
            #pragma hull hull 
            #pragma domain domain
            #pragma vertex TessellationVertexProgram
           //**************************************//
            // #pragma vertex vert
            #pragma fragment frag

            //**************************************//
            sampler2D _Noise;
            float _Weight;
            float _Tess;
            float _MaxTessDistance;
            //**************************************//
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"     
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            struct Varyings
            {
                float4 color : COLOR;
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };            
            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
            };
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;

            };
            //**************************************//       
            ControlPoint TessellationVertexProgram(Attributes v) //控制点控制如何生成细分面
            {
                ControlPoint p;

                p.vertex = v.vertex;
                p.uv = v.uv;
                p.normal = v.normal;
                p.color = v.color;

                return p;
            }
            Varyings vert(Attributes input) //这个是细分面之后用于displacement的v2f
            {
                Varyings output;
                float Noise = tex2Dlod(_Noise, float4(input.uv, 0, 0)).r;
                input.vertex.xyz += (input.normal) *  Noise * _Weight;
                output.vertex = TransformObjectToHClip(input.vertex.xyz);
                output.color = input.color;
                output.normal = input.normal;
                output.uv = input.uv;
                return output;
            }
            [UNITY_domain("tri")] 
            Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes v;
                #define DomainPos(fieldName) v.fieldName = patch[0].fieldName * barycentricCoordinates.x + patch[1].fieldName * barycentricCoordinates.y + patch[2].fieldName * barycentricCoordinates.z;
                DomainPos(vertex)
                DomainPos(uv)
                DomainPos(color)
                DomainPos(normal)
                return vert(v);  //有点像我们在几何着色器中，生成了几何之后再重新丢回去插值的情况
            }
            [UNITY_domain("tri")]
            [UNITY_outputcontrolpoints(3)]
            [UNITY_outputtopology("triangle_cw")]
            [UNITY_partitioning("fractional_odd")]
            //[UNITY_partitioning("fractional_even")]
            //[UNITY_partitioning("pow2")]
            //[UNITY_partitioning("integer")]
            [UNITY_patchconstantfunc("patchConstantFunction")]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
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
            TessellationFactors patchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                // values for distance fading the tessellation
                float minDist = 5.0;
                float maxDist = _MaxTessDistance;

                TessellationFactors f;

                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);
                
                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }
            //**************************************//

           
            half4 frag(Varyings IN) : SV_Target //can do some custom function here
            {
                half4 tex = tex2D(_Noise, IN.uv);

                return tex;
            }
            ENDHLSL
        }
    }
}