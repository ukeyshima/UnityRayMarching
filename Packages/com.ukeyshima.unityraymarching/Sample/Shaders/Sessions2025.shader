Shader "Hidden/Sessions2025"
{
    Properties
    {
        _MarchingStep("Marching Step", Float) = 80
        _MaxDistance("Max Distance", Float) = 1000
        _LensDistance("Lens Distance", Float) = 1.5
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
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/PDF.hlsl"
            
            #pragma multi_compile _RAYMARCHING_UNLIT _RAYMARCHING_BASIC _RAYMARCHING_PATHTRACE

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct MRTOutput
            {
                float4 color : SV_Target0;
                float4 normalDepth : SV_Target1;
                float4 position : SV_Target2;
                float4 id : SV_Target3;
            };

            sampler2D _BackBuffer;
            float _ElapsedTime;
            int _FrameCount;
            float2 _Resolution;
            float _MarchingStep, _MaxDistance;
            int _BounceLimit, _IterMax;
            float _LensDistance;

            static float3 _CameraPos, _CameraDir, _CameraUp;

            static const float roomSize = 10.0;
            static const float cubeSize = 2.0;
            static float lightRadius;
            static float3 lightPos;
            static float3 lightEmission;
            static float3 cubePos;
            static float wallRoughness;
            static int cubeType;
            static int wallType;
            static float hilbertStartTime;

            static float time;
            static const float bpm = 118.0;
            #define BPS (bpm / 60.0)
            #define TIME2BEAT(T) (frac(T * BPS) / BPS)
            #define TIME2SEED(T) (floor(T * BPS))
            
            float2 foldRotate(float2 p, float s)
            {
                float t = PI * 2.0 / s;
                float a = -atan2(p.x, p.y) + PI / 2.0 + t / 2.0;
                a = MOD(a, t) - t / 2.0;
                a = abs(a);
                float si = sin(a);
                float co = sqrt(1.0 - si * si);
                return length(p) * float2(co, si);
            }

            float sdBox(float3 p, float3 mn, float3 mx, float w)
            {
                float3 size = float3(w, w, length(mx - mn));
                float3 center = (mn + mx) * 0.5;
                float3 dir = normalize(mx - mn);
                float3 up = abs(dir.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 x = normalize(cross(up, dir));
                up = normalize(cross(dir, x));
                p -= center;
                p = mul(float3x3(x, up, dir), p);
                return sdBox(p, size * 0.5);
            }

            float sdWireframeBox(float3 p, float3 s, float e)
            {
                float b = sdBox(p, float3(s.x, s.y, s.z));
                b = max(b, -sdBox(p, float3(s.x * 2.0, s.y - e, s.z - e)));
                b = max(b, -sdBox(p, float3(s.x - e, s.y * 2.0, s.z - e)));
                b = max(b, -sdBox(p, float3(s.x - e, s.y - e, s.z * 2.0)));
                return b;
            }

            float ifsCube(float3 p0)
            {
                const float scale = 1;
                float seed = TIME2SEED(time);
                float2 rand = Pcg01(float2(seed, seed));
                float2 a = lerp(3.0, 6.0, rand);
                float4 p = float4(p0, 1.0) * scale;
                for (int n = 0; n < 2; n++)
                {
                    p.xy = foldRotate(p.xy, a.x);
                    p.yz = foldRotate(p.yz, a.y);
                    p = abs(p);
                    p *= 3.0;
                    p.xyz -= 2.0;
                    p.z += 1.0;
                    p.yz = mul(rotate2d(PI * 0.1 * time), p.yz);
                    p.xz = mul(rotate2d(PI * 0.1 * time), p.xz);
                    p.z = abs(p.z);
                    p.z -= 1.0;
                }
                float b = sdWireframeBox(p.xyz, III, 0.1) / p.w / scale;
                return b;
            }
            
            float dividedCube(float3 p0, out int id)
            {
                float gap = 0.015;
                float4 seed = float4(OOO, TIME2SEED(time));
                float3 minPos = -III;
                float3 maxPos = III;
                float3 size = maxPos - minPos;
                [loop]
                for (int i = 0; i < 4; i++)
                {
                    float4 r = Pcg01(seed);
                    float3 p = lerp(minPos, minPos + size, r);
                    float3 s = step(p0, p);
                    float3 nextMaxPos = lerp(maxPos, p, s);
                    float3 nextMinPos = lerp(p, minPos, s);
                    float3 nextSize = nextMaxPos - nextMinPos;
                    if (min(MIN3(abs(nextSize)), MIN3(abs(size - nextSize))) < gap * 2.0) break;
                    maxPos = nextMaxPos;
                    minPos = nextMinPos;
                    size = nextSize;
                    seed = float4(minPos, 0);
                }
                float3 center = (minPos + maxPos) * 0.5;
                float b = sdBox(p0 - center, size * 0.5 - gap * III);
                float b1 = sdBox(p0, III * 0.95);
                b = max(b, -b1);
                id = abs(p0.x) < 0.95 && abs(p0.y) < 0.95 && abs(p0.z) < 0.95 ? 1 : 0;
                return b;
            }

            float hilbertCube(float3 p0)
            {
                int id = 0.0;
                float3 s = III;
                float3 p1 = p0.zxy * IJI;
                float3 before = JOO;
                float3 next = JOO;
                const int iter = 3;
                float maxCount = pow(8.0, (float)iter);
                [loop]
                for (int i = 0; i < iter; i++)
                {
                    float3 seed = step(OOO, p1);
                    seed.y = abs(seed.y - seed.z);
                    seed.x = abs(seed.x - seed.y);
                    float localID = seed.z * 4.0 + seed.y * 2.0 + seed.x;
                    id = 8.0 * id + localID;
                    if ((int)localID == 0) { p1.xyz = p1.yzx;       before = before.yzx; next = OOI; }
                    if ((int)localID == 1) { p1.xyz = p1.zxy;       before = OJO;        next = OOI; }
                    if ((int)localID == 2) { p1.xyz = p1.zxy;       before = OOJ;        next = OJO; }
                    if ((int)localID == 3) { p1.xyz = p1.xyz * JJI; before = JOO;        next = OOI; }
                    if ((int)localID == 4) { p1.xyz = p1.xyz * JJI; before = OOJ;        next = JOO; }
                    if ((int)localID == 5) { p1.xyz = p1.zxy * JIJ; before = OJO;        next = OOI; }
                    if ((int)localID == 6) { p1.xyz = p1.zxy * JIJ; before = OOJ;        next = OJO; }
                    if ((int)localID == 7) { p1.xyz = p1.yzx * IJJ; before = OOJ;        next = next.yzx * IJJ; }
                    p1 = MOD(p1, s) - s * 0.5;
                    s *= 0.5;
                }
                
                float w = s * 0.5;
                float t = SATURATE(MOD((time - hilbertStartTime) * BPS * 8.0 * 2.0, maxCount) - id);
                float b = abs(sdBox(p1, s)) + 0.1;
                if (t > 0)
                {
                    float3 mn = before * s;
                    float3 mx = OOO - before * w * 0.5;
                    mx = lerp(mn, mx, SATURATE(t * 2.0));
                    b = min(b, sdBox(p1, mn, mx, w));
                }
                if (t > 0.5)
                {
                    float3 mn = OOO - next * w * 0.5;
                    float3 mx = next * s;
                    mx = lerp(mn, mx, SATURATE(t * 2.0 - 1.0));
                    b = min(b, sdBox(p1, mn, mx, w));      
                }
                b = max(b, sdBox(p0, III * 0.99));
                return b;
            }

            float layeredCube(float3 p0, out int id)
            {
                float gap = 0.15;
                float thick = 0.02;
                float3 p1 = p0;
                p1.z += time * 0.1;
                id = (int)((p1.z - MOD(p1.z, gap)) / gap);
                id = abs(p0.z) < 1 - thick ? id : 0;
                id = step(0.7, Pcg01(id));
                p1.z = MOD(p1.z, gap) - gap * 0.5;
                float b = sdBox(p1, float3(1.0, 1.0, thick));
                b = max(b, sdBox(p0, III));
                b = min(b, sdBox(p0 - OOI, float3(1.0, 1.0, thick)));
                b = min(b, sdBox(p0 - OOJ, float3(1.0, 1.0, thick)));
                return b;
            }

            float hyperCube(float3 p0)
            {
                float4 p[16] = {
                    JJJJ, IJJJ, IIJJ, JIJJ,
                    JJIJ, IJIJ, IIIJ, JIIJ,
                    JJJI, IJJI, IIJI, JIJI,
                    JJII, IJII, IIII, JIII,
                };

                float s, c;
                sincos(time, s, c);

                float d = 1000.0;
                float distance = 2.75;
                [loop]
                for (int i = 0; i < 16; i++)
                {
                    float4 pRot;
                    pRot.x = c * p[i].x - s * p[i].y;
                    pRot.y = s * p[i].x + c * p[i].y;
                    pRot.z = c * p[i].z - s * p[i].w;
                    pRot.w = s * p[i].z + c * p[i].w;
                    float w = rcp(distance - pRot.w);
                    float3 pProj = pRot.xyz * w;
                    p[i].xyz = pProj;
                    d = min(d, sdSphere(p0 - p[i], 0.05));
                }
                [loop]
                for (int i = 0; i < 4; i++)
                {
                    d = min(d, sdCapsule(p0, p[i], p[(i + 1) % 4], 0.025));
                    d = min(d, sdCapsule(p0, p[i], p[i + 4], 0.025));
                    d = min(d, sdCapsule(p0, p[i], p[i + 8], 0.025));
                    d = min(d, sdCapsule(p0, p[i + 4], p[(i + 1) % 4 + 4], 0.025));
                    d = min(d, sdCapsule(p0, p[i + 4], p[i + 12], 0.025));
                    d = min(d, sdCapsule(p0, p[i + 8], p[(i + 1) % 4 + 8], 0.025));
                    d = min(d, sdCapsule(p0, p[i + 8], p[i + 12], 0.025));
                    d = min(d, sdCapsule(p0, p[i + 12], p[(i + 1) % 4 + 12], 0.025));
                }
                return d;
            }

            float truchetWall(float3 p0, float size)
            {
                float3 p1 = p0 - OIO * TIME2SEED(time) * (size * 2);
                float3 seed = float3(p1 - (MOD(p1.xy, size)), 0);
                p1.xy = MOD(p1.xy, size) - size * 0.5;
                float3 rand = Pcg01(seed);
                float d = 1000.0;
                if (rand.x < 0.5)
                {
                    p1.xyz = p1.xzy;
                    d = min(d, sdTorus(p1 - IOI * size * 0.5, float2(size * 0.5, 0.025)));
                    d = min(d, sdTorus(p1 - JOJ * size * 0.5, float2(size * 0.5, 0.025)));
                }
                else
                {
                    p1.xyz = p1.xzy;
                    d = min(d, sdTorus(p1 - IOJ * size * 0.5, float2(size * 0.5, 0.025)));
                    d = min(d, sdTorus(p1 - JOI * size * 0.5, float2(size * 0.5, 0.025)));
                }
                return d;
            }

            float truchetCube(float3 p0, out int id)
            {
                float d  = truchetWall(p0.xyz - OOI, 0.25);
                d = min(d, truchetWall(p0.xyz + OOI, 0.25));
                d = min(d, truchetWall(p0.zyx - OOI, 0.25));
                d = min(d, truchetWall(p0.zyx + OOI, 0.25));
                d = min(d, truchetWall(p0.xzy + OOI, 0.25));
                d = min(d, truchetWall(p0.xzy - OOI, 0.25));
                float b = sdBox(p0, III);
                b = max(b, -sdBox(p0, III * 0.99));
                d = max(-d, b);
                id = abs(p0.x) < 0.99 && abs(p0.y) < 0.99 && abs(p0.z) < 0.99 ? 1 : 0;
                return d;
            }

            float mandelbox(float3 p0, out int id)
            {
                float scale = 2;
                float4 p1 = float4(p0 * 6.0, 0);
                float3 offset = p1.xyz;
                float4 m = lerp(0.0, 0.75, Pcg01(float4(OOO, TIME2SEED(time))));
                [loop]
	            for (int n = 0; n < 10; n++)
                {
		            p1.xyz = clamp(p1.xyz, -1, 1) * 2.0 - p1.xyz;
	                float r = dot(p1.xyz, p1.xyz);
		            p1 = r < m.x ? p1 / m.x : r < m.x + m.y ? p1 / r : p1;
                    p1.xyz = p1.xyz * scale + offset * 1.0;
                    p1.w = p1.w * scale + 1.0;
	            }
                float b = (length(p1.xyz) - 10.0) / abs(p1.w) / 6.0;
                b = max(b, -sdBox(p0, III * 0.95));
                id = abs(p0.x) < 0.95 && abs(p0.y) < 0.95 && abs(p0.z) < 0.95 ? 1 : 0;
                return b;
            }
            
            Surface Map(float3 p)
            {
                int objectID = 0;
                float d0 = 0;
                if (cubeType == 0) d0 = layeredCube(p - cubePos, objectID);
                if (cubeType == 1) d0 = dividedCube(p - cubePos, objectID);
                if (cubeType == 2) d0 = sdBox(p - cubePos, III);
                if (cubeType == 3) d0 = hilbertCube(p - cubePos);
                if (cubeType == 4) d0 = ifsCube(p - cubePos);
                if (cubeType == 5) d0 = hyperCube(p - cubePos);
                if (cubeType == 6) d0 = truchetCube(p - cubePos, objectID);
                if (cubeType == 7) d0 = mandelbox((p - cubePos), objectID);
                float d11 = sdBox(p, III * roomSize);
                float d12 = sdBox(p, III * roomSize);
                float d2 = sdSphere(p - lightPos, lightRadius);
                Surface s0 = {0, objectID, d0};
                objectID = 0;
                if (wallType == 1)
                {
                    float3 p0 = p + OJO * time;
                    float3 p1 = p0;
                    float3 t = float3(1.0, 0.5, 1.0);
                    p1 = MOD(p1, t) / t;
                    float3 r = p0 - MOD(p0, t);
                    r = Pcg01(float4(r, TIME2SEED(time))).xyz;
                    r.y = SATURATE(r.y - lerp(0.5, 0.1, (time - (12.5 * 8.0 / BPS)) / (16.0 / BPS))) * Pcg01(float(TIME2BEAT(time - r.z)));
                    objectID = step(p1.y, r.y);    
                }
                Surface s1 = {1, objectID, max(d11, -d12)};
                Surface s2 = {2, 0, d2};
                Surface s = minSurface(s0, s1);
                s = minSurface(s, s2);
                return s;
            }
            
            Material GetMaterial(Surface s, float3 p)
            {
                Material m = {III, OOO, 0.0, 1.0, 1.5, 0.0};
                if(s.surfaceId == 0) //Cube
                {
                    m.baseColor = III;
                    if (cubeType == 0)
                    {
                        m.emission = SATURATE(s.objectId) * III;
                        m.roughness = 0.0;
                        m.metallic = 1.0;
                        m.refraction = 1.5;
                        m.transmission = 0.0;
                    }
                    else
                    {
                        m.emission = OOO;
                        m.roughness = SATURATE(s.objectId) * III;
                        m.metallic = 1.0 - SATURATE(s.objectId);
                        m.refraction = 1.5;
                        m.transmission = 0.0;
                    }
                    return m;
                }
                else if (s.surfaceId == 1) //Wall
                {
                    m.baseColor = III;
                    m.emission = s.objectId == 0 ? OOO : III;
                    m.roughness = wallRoughness;
                    m.metallic = 1.0 - wallRoughness;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 2) //LIGHT
                {
                    m.baseColor = III;
                    m.emission = lightEmission;
                    m.roughness = 0.0;
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                return m;
            }

            float3 SampleLight(float x, float3 p, out int id)
            {
                id = 2;
                float2 xi = Pcg01(float2(x, x));
                float3 samplePos = SampleVisibleSphere(xi, lightRadius, lightPos, p);
                return normalize(samplePos - p);
            }

            float SampleLightPdf(float3 p, float3 l)
            {
                return VisibleSpherePDF(lightRadius, lightPos, p, l);
            }

            #define RAYMARCH_EPS 0.002
            #define RAY_SURFACE_OFFSET 0.004
            #define MAP(RP) Map(RP)
            #define GET_MATERIAL(S, RP) GetMaterial(S, RP)
            #define NEXT_EVENT_ESTIMATION
            #define SAMPLE_LIGHT(X, P, ID) SampleLight(X, P, ID)
            #define SAMPLE_LIGHT_PDF(P, L) SampleLightPdf(P, L)
            #define STEP_COUNT (_MarchingStep)
            #define BOUNCE_LIMIT (_BounceLimit)
            #define MAX_DISTANCE (_MaxDistance)
            #define FRAME_COUNT (_FrameCount)
            #include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/RayTrace.hlsl"
            
            #ifdef _RAYMARCHING_UNLIT
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) Unlit(RO, RD, COL)
            #elif _RAYMARCHING_BASIC
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) Diffuse(RO, RD, COL)
            #elif _RAYMARCHING_PATHTRACE
                #define SAMPLE_RADIANCE(RO, RD, COL, WEIGHT) PathTrace(RO, RD, COL, WEIGHT)
            #endif

            void Scene()
            {
                float t = time;
                cubePos = OJO * (roomSize - cubeSize * 0.5) +
                          OOI * (roomSize - cubeSize * 0.5) +
                          JOO * (roomSize - cubeSize * 0.5 - 1.0);
                lightPos = cubePos;
                wallRoughness = 1.0;
                lightRadius = 0.02;
                lightEmission = III;
                cubeType = 4;
                wallType = 0;
                _CameraUp = OIO;
                hilbertStartTime = 14.5 * 8.0 / BPS;
                
                 if (t < 2.0 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-1.7, -8.3, 1.0);
                     _CameraPos += IOO * sin(t * 1.2) +
                                  OIO * cos(t * 0.2) * 1.1 + 
                                  OOI * cos(t * 0.5);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 1.2) * 0.2 +
                                  OIO * cos(t * 0.2 - PI) * 0.5;
                     lightRadius = 0.1;
                     cubeType = 0;
                     _BounceLimit = 2;
                     _IterMax = 4;
                 }
                 else if (t < 4.0 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-3.7, -9.3, 5.0);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 1.2) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                     lightRadius = 0.1;
                     cubeType = 0;
                     _BounceLimit = 2;
                     _IterMax = 4;
                 }
                 else if (t < 6.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-6.31, -9.64, 7.49);
                     _CameraDir = normalize(cubePos - OIO - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                     lightRadius = 0.1;
                     cubeType = 0;
                     _BounceLimit = 2;
                     _IterMax = 4;
                 }
                 else if (t < 8.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-6.31, -9.64, 7.49);
                     _CameraDir = normalize(cubePos - OIJ - _CameraPos);
                     cubeType = 1;
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                 else if (t < 10.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.93, -7.4, 7.49);
                     _CameraDir = normalize(cubePos - OJI - _CameraPos);
                     cubeType = 1;
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                 else if (t < 11.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.93, -7.4, 7.49);
                     _CameraDir = normalize(cubePos - OJI - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15) * 0.3;
                     cubeType = 2;
                     wallType = 1;
                     _BounceLimit = 1;
                     _IterMax = 7;
                 }
                 else if (t < 12.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-6.31, -9.64, 7.49);
                     _CameraDir = normalize(cubePos - OIJ - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15) * 0.3;
                     cubeType = 2;
                     wallType = 1;
                     _BounceLimit = 1;
                     _IterMax = 7;
                 }
                 else if (t < 14.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-1.7, -8.3, 1.0);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                     cubeType = 2;
                     wallType = 1;
                     _BounceLimit = 1;
                     _IterMax = 7;
                 }
                 else if (t < 15.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-6.31, -9.4, 7.5);
                     _CameraDir = normalize(cubePos - OIJ - _CameraPos);
                     cubeType = 3;
                     _BounceLimit = 1;
                     _IterMax = 2;
                 }
                 else if (t < 16.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-8.93, -9.05, 6.0);
                     _CameraDir = normalize(cubePos - OIJ - _CameraPos);
                     cubeType = 3;
                     _BounceLimit = 1;
                     _IterMax = 2;
                 }
                 else if (t < 17.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.93, -7.4, 7.49);
                     _CameraDir = normalize(cubePos - OJI - _CameraPos);
                     cubeType = 3;
                     _BounceLimit = 1;
                     _IterMax = 2;
                 }
                 else if (t < 18.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.11, -8.1, 5.9);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     cubeType = 3;
                     _BounceLimit = 1;
                     _IterMax = 2;
                 }
                 else if (t < 20.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.7, -8.0, 6.0);
                     _CameraPos += IOO * sin(t * 1.15) +
                                  OOI * cos(t * 0.75) * 1.2 +
                                  OIO * cos(t * 0.125) * 1.5;
                     _CameraDir = normalize(cubePos - _CameraPos);
                     cubeType = 4;
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                 else if (t < 22.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.7, -8.0, 6.0);
                     _CameraPos += IOO * sin(t * 1.15) +
                                  OOI * cos(t * 0.75) * 1.2 +
                                  OIO * cos(t * 0.125) * 1.5;
                     _CameraDir = normalize(cubePos - _CameraPos);
                     wallRoughness = 0.0;
                     lightPos += OIO * 3.0 +
                                 IOO * sin(time) +
                                 OOI * cos(time);
                     lightRadius = 1.0;
                     lightEmission = IOO;
                     cubeType = 4;
                     _BounceLimit = 2;
                     _IterMax = 5;
                 }
                else if(t < 24.5 * 8.0 / BPS)
                 {
                    _CameraPos = float3(-2.5, -8.3, 4.68);
                    _CameraPos += IOO * sin(t * 1.2) * 1.5 +
                                 OOI * cos(t * 0.5) +
                                 OIO * cos(t * 0.2);
                    _CameraDir = normalize(cubePos - _CameraPos);
                    cubeType = 5;
                    lightRadius += 0.015 * Pcg01(_ElapsedTime);
                    _BounceLimit = 1;
                    _IterMax = 1;
                 }
                 else if (t < 26.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-8.09, -6.46, 7.21);
                     _CameraPos += IOO * sin(t * 1.2) +
                                  OOI * cos(t * 0.5 + PI * 1.5) +
                                  OIO * cos(t * 0.2);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     cubeType = 5;
                     lightRadius += 0.015 * Pcg01(_ElapsedTime);
                     _BounceLimit = 1;
                     _IterMax = 1;
                 }
                 else if(t < 27.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-5.93, -7.4, 7.49);
                     _CameraDir = normalize(cubePos - OJI - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15) * 0.3;
                     cubeType = 6;
                     lightRadius += 0.03 * Pcg01(_ElapsedTime);
                     lightPos.y += (-TIME2BEAT(time * 0.25) + 0.5);
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                  else if (t < 28.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-6.31, -9.64, 7.49);
                     _CameraDir = normalize(cubePos - OIJ - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15) * 0.3;
                     cubeType = 6;
                     lightRadius += 0.03 * Pcg01(_ElapsedTime);
                     lightPos.y += (-TIME2BEAT(time * 0.25) + 0.5);
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                 else if(t < 29.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-1.7, -8.3, 1.0);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                     cubeType = 6;
                     lightRadius += 0.03 * Pcg01(_ElapsedTime);
                     lightPos.y += (-TIME2BEAT(time * 0.5) + 0.5);
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                  else if (t < 30.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-1.7, -8.3, 1.0);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                      cubeType = 7;
                      lightRadius += 0.03 * Pcg01(_ElapsedTime);
                      lightPos.y += (-TIME2BEAT(time * 0.5) + 0.5);
                      _BounceLimit = 2;
                      _IterMax = 2;
                 }
                 else if(t < 31.5 * 8.0 / BPS)
                 {
                     _CameraPos = float3(-1.7, -8.3, 1.0);
                     _CameraDir = normalize(cubePos - _CameraPos);
                     _CameraDir += IOO * sin(t * 0.5) * 0.1 +
                                  OIO * cos(t * 0.15 - PI) * 0.3;
                     cubeType = 7;
                     lightEmission = IOO;
                     _BounceLimit = 2;
                     _IterMax = 2;
                 }
                 else if(t < 35 * 8.0 / BPS)
                 {
                    lightEmission = OOO;
                 }

                lightEmission *= 5000;
                lightEmission *= SATURATE(1 - Pcg01(_FrameCount / 4) * exp(-5.0 * frac(t / 8.0 * BPS + (t < 6.5 * 8.0 / BPS ? 0.0 : 0.5)) / BPS * 8.0));
            }
            
            MRTOutput frag (v2f i)
            {
                time = MOD(_ElapsedTime, 35 * 8.0 / BPS);
                Scene();
                float2 r = _Resolution;
                int2 fragCoord = floor(i.uv * r);
                
                float2 p = float2(fragCoord * 2.0 - r) / min(r.x, r.y);
                randomSeed = Pcg01(float4(p, _FrameCount, Pcg(_FrameCount)));
                _CameraDir = normalize(_CameraDir);
                _CameraUp = normalize(_CameraUp);
                float3 cameraRight = CROSS(_CameraUp, _CameraDir);
                _CameraUp = CROSS(_CameraDir, cameraRight);
                float3 ro = _CameraPos;
                float3 rd = normalize(cameraRight * p.x + _CameraUp * p.y + _CameraDir * _LensDistance);
                float3 col = OOO;
                for (int iter = 0; iter < _IterMax; iter++)
                {
                    col += SAMPLE_RADIANCE(ro, rd, OOO, III);    
                }
                col = col / _IterMax;
                float3 hitPos, normal;
                Surface surface;
                INTERSECTION_WITH_NORMAL(ro, rd, hitPos, surface, normal);
                col = saturate(col);
                col = pow(col, 0.4545455);
                MRTOutput o;
                o.color = float4(col.xyz, 1.0);
                o.normalDepth = float4(normal, 0.0);
                o.position = float4(hitPos, 0.0);
                o.id = float4(surface.surfaceId, surface.objectId, 0.0, 0.0);
                return o;
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
