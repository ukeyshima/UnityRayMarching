Shader "Hidden/CornelBox"
{
    Properties
    {
        _MarchingStep("Marching Step", Float) = 64
        _MaxDistance("Max Distance", Float) = 1000
        _BounceLimit ("Bounce Limit", Int) = 1
        _IterMax ("Iteration Max", Int) = 1
        _FocusDistance("Focus Distance", Float) = 35.0
        _Exposure("Exposure", Float) = 1.0
        _LensRadius("Lens Radius", Float) = 1.0
        _LensDistance("Lens Distance", Float) = 1.5
        _LightPos("Light Pos", Vector) = (0.0, 70.0, 0.0)
        _LightRadius("Light Radius", Float) = 15.0
        [KeywordEnum(Unlit, Basic, PathTrace)] _RayMarching ("Ray Marching", Float) = 0
        [KeywordEnum(BRDF, NEE)] _SAMPLING ("Sampling", Float) = 0
        [KeywordEnum(Pinhole, Thinlens)] _CAMERA ("Camera", Float) = 0
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM

            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/DistanceFunction.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Pcg.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Sampling.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/PDF.hlsl"

            #pragma multi_compile _RAYMARCHING_UNLIT _RAYMARCHING_BASIC _RAYMARCHING_PATHTRACE
            #pragma multi_compile _SAMPLING_BRDF _SAMPLING_NEE
            #pragma multi_compile _CAMERA_PINHOLE _CAMERA_THINLENS
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _BackBuffer;
            float _ElapsedTime;
            int _FrameCount;
            float2 _Resolution;

            float _FocusDistance, _LensRadius, _LensDistance, _Exposure;
            float3 _CameraPos, _CameraDir, _CameraUp;

            float3 _LightPos;
            float _LightRadius;
            
            float _MarchingStep, _MaxDistance;
            int _BounceLimit, _IterMax;

            static const Material materials[7] = {
                {float3(0.0, 0.0, 0.0), float3(0.0, 0.0, 0.0), 0.0, 1.0, 1.5, 0.0},
                {float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), 1.0, 0.0, 1.5, 0.0},
                {float3(0.0, 1.0, 0.0), float3(0.0, 0.0, 0.0), 1.0, 0.0, 1.5, 0.0},
                {float3(1.0, 0.0, 0.0), float3(0.0, 0.0, 0.0), 1.0, 0.0, 1.5, 0.0},
                {float3(1.0, 0.8, 0.6), float3(1.0, 1.0, 1.0), 1.0, 1.0, 1.5, 0.0},
                {float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), 0.2, 1.0, 1.5, 0.0},
                {float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), 0.0, 1.0, 1.5, 0.0}
            };

            Surface Map(float3 p)
            {
                Surface ceil = {0, 1, SdBox(p - float3(0.0, 100.0, 0.0), float3(100.0, 1.0, 100.0))};
                Surface floor = {1, 1, SdBox(p + float3(0.0, 100.0, 0.0), float3(100.0, 1.0, 100.0))};
                Surface backWall = {2, 1, SdBox(p - float3(0.0, 0.0, 99.0), float3(99.0, 99.0, 1.0))};
                Surface rightWall = {3, 2, SdBox(p - float3(99, 0.0, 0.0), float3(1.0, 99.0, 99.0))};
                Surface leftWall = {4, 3, SdBox(p + float3(99, 0.0, 0.0), float3(1.0, 99.0, 99.0))};
                Surface light = {5, 4, SdSphere(p - _LightPos, _LightRadius)};
                Surface box = {6, 5, SdBox(p - float3(-40.0, -40.0, 10.0), float3(30.0, 60.0, 30.0))};
                Surface ball = {7, 6, SdSphere(p - float3(30.0, -70.0, -70.0), 30.0)};
                Surface s = MinSurface(ceil, floor);
                s = MinSurface(s, backWall);
                s = MinSurface(s, rightWall);
                s = MinSurface(s, leftWall);
                s = MinSurface(s, light);
                s = MinSurface(s, box);
                s = MinSurface(s, ball);
                return s;
            }
            
            float3 SampleLight(float x, float3 p, out int id)
            {
                id = 5;
                float2 xi = Pcg01(float2(x, x));
                float3 samplePos = SampleVisibleSphere(xi, _LightRadius, _LightPos, p);
                return normalize(samplePos - p);
            }

            float SampleLightPdf(float3 p, float3 l)
            {
                return VisibleSpherePDF(_LightRadius, _LightPos, p, l);
            }

            #define MAP(P) Map(P)
            #define GET_MATERIAL(S, RP) (materials[S.objectId])
#ifdef _SAMPLING_NEE
            #define NEXT_EVENT_ESTIMATION
            #define SAMPLE_LIGHT(X, P, ID) SampleLight(X, P, ID)
            #define SAMPLE_LIGHT_PDF(P, L) SampleLightPdf(P, L)
#endif
            #define STEP_COUNT (_MarchingStep)
            #define BOUNCE_LIMIT (_BounceLimit)
            #define MAX_DISTANCE (_MaxDistance)
            #define FRAME_COUNT (_FrameCount)
            #define FOCUS_DISTANCE (_FocusDistance)
            #define LENS_RADIUS (_LensRadius)
            #define LENS_DISTANCE (_LensDistance)
            #define CAMERA_POS (_CameraPos)
            #define CAMERA_RIGHT (CROSS(_CameraUp, _CameraDir))
            #define CAMERA_UP (_CameraUp)
            #define CAMERA_DIR (_CameraDir)
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/RayTrace.hlsl"

            #ifdef _RAYMARCHING_UNLIT
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) Unlit(RO, RD, COL)
            #elif _RAYMARCHING_BASIC
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) Diffuse(RO, RD, COL)
            #elif _RAYMARCHING_PATHTRACE
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) PathTrace(RO, RD, COL, WEIGHT)
            #endif

            float4 frag (v2f i) : SV_Target
            {
                float2 r = _Resolution;
                int2 fragCoord = floor(i.uv * r);
                float2 p = float2(fragCoord * 2.0 - r) / min(r.x, r.y) * -1.0;
                randomSeed = Pcg01(float4(p, _FrameCount, Pcg(_FrameCount)));
                float3 ro, rd;
                float3 col = OOO;
                for (int iter = 0; iter < _IterMax; iter++)
                {
#ifdef _CAMERA_THINLENS
                    float3 weight = ThinLensModel(p, ro, rd) * _Exposure * III;
#else
                    float3 weight = PinholeModel(p, ro, rd);
#endif
                    col += SAMPLE_RADIANCE(ro, rd, OOO, weight);    
                }
                col = col / _IterMax;
                float4 backBuffer = tex2D(_BackBuffer, i.uv);
                col = _FrameCount > 0 ? (backBuffer.rgb * (_FrameCount - 1) + col) / _FrameCount : col;
                return float4(col, 1.0);
            }

            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            ENDCG
        }
    }
}
