Shader "Unlit/WaveletTransform"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalDepthTex ("Normal Depth Texture", 2D) = "white" {}
        _PositionTex ("Position Texture", 2D) = "white" {}
        _IDTex ("ID Texture", 2D) = "white" {}
        _CS ("Color Sigma", float) = 0.0001
        _NS ("Normal Sigma", float) = 0.0025
        _PS ("Position Sigma", float) = 0.005
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

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            Texture2D _MainTex, _NormalDepthTex, _PositionTex, _IDTex;
            SamplerState _Linear_Mirror, _Point_Mirror;
            float4 _MainTex_ST, _MainTex_TexelSize;
            int _Count;
            float _CS;
            float _NS;
            float _PS;

            static const float kernel[25] = {
                1.0 / 256.0, 1.0 / 64.0, 3.0 / 128.0, 1.0 / 64.0, 1.0 / 256.0,
                1.0 / 64.0, 1.0 / 16.0, 3.0 / 32.0, 1.0 / 16.0, 1.0 / 64.0,
                3.0 / 128.0, 3.0 / 32.0, 9.0 / 64.0, 3.0 / 32.0, 3.0 / 128.0,
                1.0 / 64.0, 1.0 / 16.0, 3.0 / 32.0, 1.0 / 16.0, 1.0 / 64.0,
                1.0 / 256.0, 1.0 / 64.0, 3.0 / 128.0, 1.0 / 64.0, 1.0 / 256.0
            };

            static const float2 offset[25] = {
                float2(-2, -2), float2(-1, -2), float2(0, -2), float2(1, -2), float2(2, -2),
                float2(-2, -1), float2(-1, -1), float2(0, -1), float2(1, -1), float2(2, -1),
                float2(-2, 0), float2(-1, 0), float2(0, 0), float2(1, 0), float2(2, 0),
                float2(-2, 1), float2(-1, 1), float2(0, 1), float2(1, 1), float2(2, 1),
                float2(-2, 2), float2(-1, 2), float2(0, 2), float2(1, 2), float2(2, 2)
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 sum = float4(0.0, 0.0, 0.0, 0.0);
                float2 step = _MainTex_TexelSize.xy;

                float4 c = _MainTex.Sample(_Point_Mirror, i.uv);
                float4 n = _NormalDepthTex.Sample(_Point_Mirror, i.uv);
                float4 p = _PositionTex.Sample(_Point_Mirror, i.uv);
                int4 id = int4(_IDTex.Sample(_Point_Mirror, i.uv));
                
                float acc = 0.0;
                int stepWidth = (1 << _Count);

                for(int j = 0; j < 25; j++)
                {
                    float2 uv = i.uv + offset[j] * step * stepWidth;

                    int4 nid = int4(_IDTex.Sample(_Point_Mirror, uv));
                    if (any(id != nid)) continue;

                    float4 nc = _MainTex.Sample(_Point_Mirror, uv);
                    float4 t = c - nc;
                    float dist2 = dot(t, t);
                    float cw = _Count < 1 ? 1.0 : min(exp(-dist2 / _CS), 1.0);

                    float4 nn = _NormalDepthTex.Sample(_Point_Mirror, uv);
                    t = n - nn;
                    dist2 = dot(t, t);
                    float nw = min(exp(-dist2 / _NS), 1.0);

                    float4 np = _PositionTex.Sample(_Point_Mirror, uv);
                    t = p - np;
                    dist2 = dot(t, t);
                    float pw = min(exp(-dist2 / _PS), 1.0);

                    float weight = cw * nw * pw;
                    sum += nc * weight * kernel[j];
                    acc += weight * kernel[j];
                }

                return sum / acc;
            }
            ENDCG
        }
    }
}