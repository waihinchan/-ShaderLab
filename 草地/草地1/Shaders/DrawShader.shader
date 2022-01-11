Shader "Unlit/DrawShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "balck" {}
        _DrawColor("DrawColor",Color) = (1,0,0,0)
        _Coord("SplatCoord",Vector) = (0,0,0,0)
        _TargetPosition("_TargetPosition",Vector) = (0,1,0,1)

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            // #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                // UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;

                
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _DrawColor,_Coord;
            float _BrushWidth;
            float4 _TargetPosition;
            float4x4 _WorldMatrix;

            v2f vert (appdata v)
            {
                v2f o;
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                // UNITY_APPLY_FOG(i.fogCoord, col);
                // float draw = pow(saturate(1 - distance(i.uv,_Coord.xy)),1000.0f/_BrushWidth); 
                float draw = pow(saturate(1 - distance(i.uv,_Coord.xy)),1000.0f/_BrushWidth); 
                float4 loacalpos = (normalize(mul(_WorldMatrix,_TargetPosition)) + 1)/2; //remap from -1 to 1 to 0 to 1
                //这里计算的逻辑是，脚本中先计算交互物体本身是否有于草地有接触（通过射线判断），如果有“接触”
                //就把交互物体的世界坐标转换成草地的本地坐标，然后再传到贴图里面计算
                float4 drawcolor =  loacalpos * step(0.05,draw);
                drawcolor.a = draw; 
                //这个a通道可以用来计算体积之类的，因为上面的brushwidth实际上把交互对象的体积传进去了，如果体积更大的话这里理应草地会受到更多影响。
                //同时a通道用于计算是否发生交互，因为如果这里是空值的话数值应为000，在草地shader中被解释为坐标，但实际上不应发生计算，所以用a通道控制交互与否。
                //rgb通道控制交互的参数

                 //梯度还是需要在shader里面计算/ 即如果draw是0，那这里就是0
                 //在材质里面可以设置一个step来clamp掉那些距离太远的。
                 //同时得到的position可以考虑作为一个等比例缩放的位置，也就是说直接计算距离
                return saturate(col+drawcolor);
            }
            ENDCG
        }
    }
}

//思路，这里没有办法直接计算梯度，因为梯度本身需要当前顶点的距离，但是这个rendertexutre用的计算起来没有什么意义
//所以这里基于uv来计算距离，如果有position就直接上颜色，没有的话则是0.
//在这里的draw给一个step来控制