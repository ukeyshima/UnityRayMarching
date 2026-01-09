Shader "Hidden/MaterialPreview"
{
    Properties
    {
        marchingStep("Marching Step", Float) = 64
        maxDistance("Max Distance", Float) = 1000
        focalLength("Focal Length", Float) = 1
        bounceLimit ("Bounce Limit", Int) = 1
        iterMax ("Iteration Max", Int) = 1
        [KeywordEnum(Unlit, Basic, PathTrace)] _RayMarching ("Ray Marching", Float) = 0
        [KeywordEnum(BRDF, NEE)] _SAMPLING ("Sampling", Float) = 0
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

            static float3 lightPos = float3(0.0, 500.0, 0.0);
            static float lightRadius = 150;

            Surface Map(float3 p)
            {
                float3 p1 = p;
                p1.xz = MOD(p.xz, 10.0) - 5.0;
                Surface light = {0, 0, sdSphere(p - lightPos, lightRadius)};
                Surface floor = {1, 0, sdPlane(p, OIO, 3.0)};
                Surface ball = {2, 0, sdSphere(p1, 3.0)};
                
                Surface s = light;
                s = minSurface(s, floor);
                s = minSurface(s, ball);
                return s;
            }

            Material GetMaterial(Surface s, float3 p)
            {
                Material m = {III, OOO, 0.0, 1.0, 0.0, 0.0};

                if (s.surfaceId == 0)
                {
                    m.baseColor = III;
                    m.emission = III;
                    m.roughness = 1.0;
                    m.metallic = 0.0;
                    m.refraction = 0.0;
                    m.transmission = 0.0;
                }
                else if (s.surfaceId == 1)
                {
                    int2 seed = floor(p.xz / 10.0);
                    m.baseColor = (seed.x + seed.y) % 2 == 0 ? III * 0.3 : III;
                    m.emission = OOO;
                    m.roughness = 1.0;
                    m.metallic = 0.0;
                    m.refraction = 0.0;
                    m.transmission = 0.0;
                }
                else
                {
                    float2 seed = floor(p.xz / 10.0);
                    float4 seed2 = float4(seed, Pcg01(seed));
                    float4 rand = Pcg01(seed2);
                    float4 rand2 = Pcg01(rand);
                    float4 rand3 = Pcg01(rand2);
                    
                    m.baseColor = rand.xyz;
                    m.emission = step(0.8, rand.w) * rand2.xyz;
                    m.metallic = step(0.5, rand3.x);
                    m.transmission = step(m.metallic, 0.5) * step(0.4, rand3.z);
                    m.roughness = m.transmission < 0.5 ? pow(rand2.w, 2.0) : pow(rand2.w, 3.0);
                    m.refraction = lerp(1.1, 2.0, rand3.y);
                }
                return m;
            }
            
            float3 SampleLight(float x, float3 p, out int id)
            {
                id = 0;
                float2 xi = Pcg01(float2(x, x));
                float3 samplePos = SampleVisibleSphere(xi, lightRadius, lightPos, p);
                return normalize(samplePos - p);
            }

            float SampleLightPdf(float3 p, float3 l)
            {
                return VisibleSpherePDF(lightRadius, lightPos, p, l);
            }

            #define MAP(P) Map(P)
            #define GET_MATERIAL(S, RP) GetMaterial(S, RP)
#ifdef _SAMPLING_NEE
            #define NEXT_EVENT_ESTIMATION
            #define SAMPLE_LIGHT(X, P, ID) SampleLight(X, P, ID)
            #define SAMPLE_LIGHT_PDF(P, L) SampleLightPdf(P, L)
#endif
            #define STEP_COUNT (marchingStep)
            #define ITER_MAX (iterMax)
            #define BOUNCE_LIMIT (bounceLimit)
            #define MAX_DISTANCE (maxDistance)
            #define FRAME_COUNT (_FrameCount)
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
                float3 col = OOO;
                float3 hitPos, normal;
                Surface surface;
                col = SAMPLE_RADIANCE(ro, rd, col, hitPos, normal, surface);
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
