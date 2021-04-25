Shader "Unlit/DrawShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "balck" {}
        _DrawColor("DrawColor",Color) = (1,0,0,0)
        _Coord("SplatCoord",Vector) = (0,0,0,0)

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
                float draw = pow(saturate(1 - distance(i.uv,_Coord.xy)),1000.0f/_BrushWidth);
                float4 drawcolor = _DrawColor * draw;
                return saturate(col+drawcolor);
            }
            ENDCG
        }
    }
}
