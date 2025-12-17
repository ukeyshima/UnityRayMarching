Shader "Hidden/CornelBox"
{
    Properties
    {
        marchingStep("Marching Step", Float) = 64
        maxDistance("Max Distance", Float) = 1000
        focalLength("Focal Length", Float) = 1
        bounceLimit ("Bounce Limit", Int) = 1
        iterMax ("Iteration Max", Int) = 1
        [KeywordEnum(Unlit, Basic, PathTrace)] _RayMarching ("Ray Marching", Float) = 0
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
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Transform.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Pcg.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Sampling.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/BRDF.hlsl"
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/PDF.hlsl"

            #pragma multi_compile _RAYMARCHING_UNLIT _RAYMARCHING_BASIC _RAYMARCHING_PATHTRACE

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _BackBuffer;
            float _ElapsedTime;
            int _FrameCount;
            float2 _Resolution;

            float3 _CameraPos, _CameraDir, _CameraUp;

            float focalLength, marchingStep, maxDistance;
            int bounceLimit, iterMax;

            static const Material materials[7] = {
                {float3(0.0, 0.0, 0.0), 0.0, float3(0.0, 0.0, 0.0)},
                {float3(1.0, 1.0, 1.0), 1.0, float3(0.0, 0.0, 0.0)},
                {float3(0.0, 1.0, 0.0), 1.0, float3(0.0, 0.0, 0.0)},
                {float3(1.0, 0.0, 0.0), 1.0, float3(0.0, 0.0, 0.0)},
                {float3(1.0, 0.8, 0.6), 0.2, float3(10.0, 10.0, 10.0)},
                {float3(1.0, 1.0, 1.0), 0.25, float3(0.0, 0.0, 0.0)},
                {float3(1.0, 1.0, 1.0), 0.15, float3(0.0, 0.0, 0.0)}
            };

            Surface Map(float3 p)
            {
                Surface ceil = {0, 1, sdBox(p - float3(0.0, 100.0, 0.0), float3(100.0, 1.0, 100.0))};
                Surface floor = {1, 1, sdBox(p + float3(0.0, 100.0, 0.0), float3(100.0, 1.0, 100.0))};
                Surface backWall = {2, 1, sdBox(p - float3(0.0, 0.0, 99.0), float3(99.0, 99.0, 1.0))};
                Surface rightWall = {3, 2, sdBox(p - float3(99, 0.0, 0.0), float3(1.0, 99.0, 99.0))};
                Surface leftWall = {4, 3, sdBox(p + float3(99, 0.0, 0.0), float3(1.0, 99.0, 99.0))};
                Surface light = {5, 4, sdBox(p - float3(0.0, 99.0, 0.0), float3(50.0, 1.0, 50.0))};
                Surface box = {6, 5, sdBox(p - float3(-40.0, -40.0, 10.0), float3(30.0, 60.0, 30.0))};
                Surface ball = {7, 6, sdSphere(p - float3(30.0, -70.0, -70.0), 30.0)};
                Surface s = minSurface(ceil, floor);
                s = minSurface(s, backWall);
                s = minSurface(s, rightWall);
                s = minSurface(s, leftWall);
                s = minSurface(s, light);
                s = minSurface(s, box);
                s = minSurface(s, ball);
                return s;
            }

            #define MAP(P) Map(P)
            #define GET_MATERIAL(S, RP) (materials[S.objectId])
            #define STEP_COUNT (marchingStep)
            #define ITER_MAX (iterMax)
            #define BOUNCE_LIMIT (bounceLimit)
            #define MAX_DISTANCE (maxDistance)
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/RayTrace.hlsl"

            #ifdef _RAYMARCHING_UNLIT
                #define SAMPLE_RADIANCE(RO, RD, COL, POS, NORMAL, SURFACE) Unlit(RO, RD, COL, POS, NORMAL, SURFACE)
            #elif _RAYMARCHING_BASIC
                #define SAMPLE_RADIANCE(RO, RD, COL, POS, NORMAL, SURFACE) Diffuse(RO, RD, COL, POS, NORMAL, SURFACE)
            #elif _RAYMARCHING_PATHTRACE
                #define SAMPLE_RADIANCE(RO, RD, COL, POS, NORMAL, SURFACE) PathTrace(RO, RD, COL, POS, NORMAL, SURFACE)
            #endif

            float4 frag (v2f i) : SV_Target
            {
                float2 r = _Resolution;
                int2 fragCoord = floor(i.uv * r);
                float3 p = float3((fragCoord * 2.0 - r) / min(r.x, r.y), 0.0);
                float3 cameraRight = CROSS(_CameraUp, _CameraDir);
                float3 ray = normalize(cameraRight * p.x + _CameraUp * p.y + _CameraDir * focalLength);
                float3 ro = _CameraPos;
                float3 rd = ray;
                float3 col = float3(0.0, 0.0, 0.0);
                float3 hitPos, normal;
                Surface surface;
                col = SAMPLE_RADIANCE(ro, rd, col, hitPos, normal, surface);
                col = saturate(col);
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
