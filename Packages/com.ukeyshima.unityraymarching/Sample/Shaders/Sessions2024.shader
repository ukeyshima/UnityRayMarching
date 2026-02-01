Shader "Hidden/Sessions2024"
{
    Properties
    {
        _MarchingStep("Marching Step", Float) = 80
        _MaxDistance("Max Distance", Float) = 1000
        _BounceLimit ("Bounce Limit", Int) = 1
        _IterMax ("Iteration Max", Int) = 1
        _LensDistance("Lens Distance", Float) = 1.5
        stairsHeight ("Stairs Height", Float) = 10.5
        stairsWidth ("Stairs Width", Float) = 11
        stairsTilingSize ("Stairs Tiling Size", Float) = 150
        ballRadius ("ballRadius", Float) = 5.0
        deltaTime ("deltaTime", Float) = 0.05
        gravity ("gravity", Float) = 1
        attraction ("attraction", Float) = 10
        reflection ("reflection", Float) = 10
        friction ("friction", Float) = -20
        randomize ("randomize", Float) = 1
        ballPosMax ("ballPosMax", Vector) = (200, 150, 400, 0)
        ballPosMin ("ballPosMin", Vector) = (-200, -150, 75, 0)
        ballVelMin ("ballVelMin", Vector) = (-100, -100, -100, 0)
        ballVelMax ("ballVelMax", Vector) = (100, 100, 100, 0)
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
            };

            sampler2D _BackBuffer;
            float _ElapsedTime;
            int _FrameCount;
            float2 _Resolution;
            float _MarchingStep, _MaxDistance;
            int _BounceLimit, _IterMax;
            float _LensDistance;
            
            static float3 _CameraPos, _CameraDir, _CameraUp;
            
            float stairsHeight, stairsWidth, stairsTilingSize;
            static const float wallWidth = 0.48;
            static const int ballNum = 15;
            float ballRadius;
            float deltaTime;
            float gravity;
            float attraction;
            float reflection;
            float friction;
            float randomize;
            float3 ballPosMax;
            float3 ballPosMin;
            float3 ballVelMin;
            float3 ballVelMax;
            static float3 ballPos[ballNum];
            static float3 ballVel[ballNum];

            static const float bpm = 84.0;
            static float beatTime;
            static float sbeatTime;
            static const int phaseNum = 15;
            static const int phaseBPM[phaseNum + 1] = {0, 8, 16, 20, 24, 32, 36, 40, 48, 64, 72, 80, 96, 112, 128, 144};
            static float phasePeriod[phaseNum + 1];
            static float phaseFrag[phaseNum];
            static float phaseTime = 0.0;

            float sdStairs(float2 p)
            {
                float2 pf = float2(p.x + p.y, p.x + p.y) * 0.5;
                float2 d = p - float2(floor(pf.x), ceil(pf.y));
                float2 d2 = p - float2(floor(pf.x + 0.5), floor(pf.y + 0.5));
                float d3 = length(float2(min(d.x, 0.0), max(d.y, 0.0)));
                float d4 = length(float2(max(d2.x, 0.0), min(d2.y, 0.0)));
                return d3 - d4;
            }

            float sdStairs(float2 p, float h)
            {
                p.xy = p.y < p.x ? p.yx : p.xy;
                return sdStairs(p - float2(0.0, h));
            }

            float sdStairs(float3 p, float h, float w)
            {
                float x = abs(p.x) - w;
                float d = sdStairs(p.zy, h);
                return max(x, d);
            }

            void CalcBeatTime()
            {
                float scaledTime = _ElapsedTime * bpm / 60.0;
                beatTime = floor(scaledTime);
                sbeatTime = frac(scaledTime);
                sbeatTime = beatTime + pow(sbeatTime, 5.0);
            }

            void CalcPhase()
            {
                phaseTime = 0.0;
                for(int i = 0; i < phaseNum; i++){
                    phasePeriod[i + 1] = float(phaseBPM[i + 1]) / bpm * 60.0;
                    phaseFrag[i] = step(phasePeriod[i], _ElapsedTime) * step(_ElapsedTime, phasePeriod[i + 1]);
                    phaseTime += phaseFrag[i] * (_ElapsedTime - phasePeriod[i]);
                }
            }

            void CalcCameraParams(){
                if(phaseFrag[10] < 0.5) _CameraUp = float3(0.0, 1.0, 0.0);
                if(phaseFrag[10] > 0.5) _CameraUp = float3(0.0, cos(-phaseTime * 0.1 + PI * 0.25), sin(-phaseTime * 0.1 + PI * 0.25));

                if(phaseFrag[0] > 0.5) _CameraDir = float3(0.0, 0.0, 1.0);
                if(phaseFrag[1] > 0.5) _CameraDir = float3(cos(phaseTime * 0.1), 0.0, sin(phaseTime * 0.1));
                if(phaseFrag[2] > 0.5) _CameraDir = float3(cos(phaseTime * 0.1 + PI * 0.75), 0.0, sin(phaseTime * 0.1 + PI * 0.75));
                if(phaseFrag[3] > 0.5) _CameraDir = float3(cos(-phaseTime * 0.07 + PI), sin(-phaseTime * 0.08 + PI), sin(-phaseTime * 0.07 + PI));
                if(phaseFrag[4] > 0.5) _CameraDir = float3(-1.0, 0.2, 0.8);
                if(phaseFrag[5] > 0.5) _CameraDir = float3(-1.0, 0.0, 1.0);
                if(phaseFrag[6] > 0.5) _CameraDir = float3(-1.5, sin(-phaseTime * 0.08 + PI), 1.0);
                if(phaseFrag[7] > 0.5) _CameraDir = float3(1.0, sin(-phaseTime * 0.08 + PI), 1.0);
                if(phaseFrag[8] > 0.5) _CameraDir = float3(0.0, 0.0, 1.0);
                if(phaseFrag[9] > 0.5) _CameraDir = float3(cos(phaseTime * 0.2 + PI * 0.25), 0.0, sin(phaseTime * 0.2 + PI * 0.25));
                if(phaseFrag[10] > 0.5) _CameraDir = float3(0.0, cos(-phaseTime * 0.1 + PI * 0.6), sin(-phaseTime * 0.1 + PI * 0.6));
                if(phaseFrag[11] > 0.5) _CameraDir = float3(0.0, 0.0, 1.0);
                if(phaseFrag[12] > 0.5) _CameraDir = float3(cos(-phaseTime * 0.1 + PI * 0.25), 0.0, sin(-phaseTime * 0.1 + PI * 0.25));
                if(phaseFrag[13] > 0.5) _CameraDir = float3(float3(cos(phaseTime * 0.1 + PI * 0.5), -sin(phaseTime * 0.1 + PI * 0.5), sin(phaseTime * 0.1 + PI * 0.5)));
                if(phaseFrag[14] > 0.5) _CameraDir = float3(cos(phaseTime * 0.1 + PI * 1.5), -0.5, sin(phaseTime * 0.1 + PI * 1.5));

                if(phaseFrag[0] > 0.5) _CameraPos = (float3(0.0, -20.0, 15.0) + _CameraDir * phaseTime * 0.8);
                if(phaseFrag[1] > 0.5) _CameraPos = (float3(0.0, -20.0, 15.0));
                if(phaseFrag[2] > 0.5) _CameraPos = (float3(0.0, -20.0, 15.0));
                if(phaseFrag[3] > 0.5) _CameraPos = (float3(0.0, -20.0, 15.0));
                if(phaseFrag[4] > 0.5) _CameraPos = (float3(4.0, -62.0, 1.0));
                if(phaseFrag[5] > 0.5) _CameraPos = (float3(0.0, -50.0 + phaseTime * 1.0, -15.0 + phaseTime * 1.0));
                if(phaseFrag[6] > 0.5) _CameraPos = (float3(4.0, -40.0, 1.0));
                if(phaseFrag[7] > 0.5) _CameraPos = (float3(2.0, -30.0, 1.0));
                if(phaseFrag[8] > 0.5) _CameraPos = (float3(0.0, -10.0 + phaseTime * 1.0, 25.0 + phaseTime * 1.0));
                if(phaseFrag[9] > 0.5) _CameraPos = (float3(0.0, 20.0, 55.0));
                if(phaseFrag[10] > 0.5) _CameraPos = (float3(0.0, 20.0, 55.0));
                if(phaseFrag[11] > 0.5) _CameraPos = (float3(0.0, 20.0, 55.0 + phaseTime * 1.5));
                if(phaseFrag[12] > 0.5) _CameraPos = (float3(0.0, 15.0, 225.0) - _CameraDir * 50.0);
                if(phaseFrag[13] > 0.5) _CameraPos = (float3(0.0, 15.0, 225.0)  - _CameraDir * 80.0);
                if(phaseFrag[14] > 0.5) _CameraPos = (float3(0.0, 25.0, 75.0) - _CameraDir * 130.0);
            }

            float sdTruchetStairs(float3 p, float s, float t)
            {
                float hs = s * 0.5;
                float3 p1 = lerp(p - hs * IIO, p + hs * JOJ, t);
                float3 p2 = lerp(p.zyx * JII + hs * IOJ, p.yzx + hs * JIO, t);
                float3 p3 = lerp(p.yxz * JII + hs * IIO, p.zyx * JII + hs * IJO, t);
                float d1 = sdStairs(p1 - OII * sbeatTime * 3.0 * step(phasePeriod[8], _ElapsedTime), stairsHeight, stairsWidth);
                float d2 = sdStairs(p2 - OII * sbeatTime * 3.0 * step(phasePeriod[8], _ElapsedTime), stairsHeight, stairsWidth);
                float d3 = sdStairs(p3 - OII * sbeatTime * 3.0 * step(phasePeriod[8], _ElapsedTime), stairsHeight, stairsWidth);
                return min(min(d1, d2), d3);
            }

            float sdTruchetTiledStairs(float3 p, float s){
                float hs = s * 0.5;
                float3 pf = MOD(p, s);
                float3 pi = p - pf;
                float s1 = Pcg01(pi + float3(0, 38, 0));
                float s2 = Pcg01(pi + float3(hs, 0, 0));
                pf.xz = s1 < 0.25 ? (pf - hs).zx * JI + hs:
                        s1 < 0.5 ? (pf - hs).xz * JJ + hs:
                        s1 < 0.75 ? (pf - hs).zx * IJ + hs:
                        pf.xz;
                return sdTruchetStairs(pf, s, step(s2, 0.5));
            }

            #define STAIRS_MAP(p) sdTruchetTiledStairs(p - float3(stairsTilingSize * 0.5, stairsTilingSize * 0.5, stairsTilingSize * 0.5), stairsTilingSize)
            float3 GetStairsGrad(float3 p)
            {
                const float e = EPS;
                const float2 k = float2(1, -1);
                return k.xyy * STAIRS_MAP(p + k.xyy * e) +
                       k.yyx * STAIRS_MAP(p + k.yyx * e) +
                       k.yxy * STAIRS_MAP(p + k.yxy * e) +
                       k.xxx * STAIRS_MAP(p + k.xxx * e);
            }

            Surface WallMap(float3 p)
            {
               p.y += (phaseTime * 10.0 * Pcg01(int(p.z))) * phaseFrag[14];

                int3 seed = int3(0.0, p.y, p.z);
                float3 hash = Pcg01(seed);

                float3 p1 = float3(p.x, frac(p.y) - 0.5, frac(p.z) - 0.5);

                float dx =
                    SATURATE(-(abs((floor(-p.y) + floor(p.z)) * 0.1 + hash.x * 0.4 - 6.2) - 1.0)) * pow(abs(sin(phaseTime / phasePeriod[1] * 1.0 * PI)), 4.0) * phaseFrag[0] +
                    SATURATE(-(abs((floor(-p.y) + floor(p.z)) * 0.1 + hash.x * 0.4 - 7.5 + phaseTime) - 1.0)) * phaseFrag[1] +
                    SATURATE(-(abs((floor(-p.y) + floor(p.z)) * 0.05 + hash.x * 0.4 - 10.0 + phaseTime * 1.6) - 1.0)) * phaseFrag[1] +
                    SATURATE(-(abs((floor(-p.y) + floor(p.z)) * 0.1 + hash.x * 1.5 - 7.5 + phaseTime) - 1.0)) * phaseFrag[2] +
                    SATURATE(-(abs((floor(-p.y) + floor(p.z)) * 0.1 + hash.x * 1.5 - 5.0 + phaseTime) - 1.0)) * phaseFrag[3] +
                    SATURATE(abs(sin(length(int3(0.0, p.y + 60.0, p.z)) * 0.2 + hash.x * 0.6 - phaseTime * 1.5) * 1.5) - 0.5) * phaseFrag[4] +
                    step(Pcg01(int4(float4(p.x, p.y, floor(p.z) * 0.3 * Pcg01(int(sbeatTime)), sbeatTime * 10.0))).x, 0.3) * (phaseFrag[5] + phaseFrag[6] + phaseFrag[7]) +
                    lerp(
                        step(Pcg01(int4(float4(p.x, p.y, floor(p.z) * 0.3 * Pcg01(int(sbeatTime)), sbeatTime * 10.0))).x, 0.3),
                        SATURATE(sin(sbeatTime * 2.0 + (hash.x + hash.y) * PI) - 0.3),
                        SATURATE(phaseTime / phasePeriod[9] * 1.3)
                    ) * phaseFrag[8] +
                    SATURATE(sin(sbeatTime * 2.0 + (hash.x + hash.y) * PI) - 0.3) * (phaseFrag[9] + phaseFrag[10] + phaseFrag[11]) +
                    3.0 * (phaseFrag[12] + phaseFrag[13] + phaseFrag[14])
                ;

                float d = dx * wallWidth * 2.0;
                float3 delta = IOO * (d - (stairsWidth + wallWidth));
                float3 bSize = III * wallWidth * 0.8;
                float3 pSizeV = bSize * float3(1.0, 0.15, 1.0);
                float3 pSizeH = bSize * float3(1.0, 1.0, 0.15);

                float sdWall1 = sdBox(p1 - delta, wallWidth * III);
                sdWall1 = max(sdWall1,
                    -lerp(
                        min(sdBox(p1 - wallWidth * IOO - delta, pSizeV), sdBox(p1 - wallWidth * IOO - delta, pSizeH)),
                        sdBox(p1 - wallWidth * IOO - delta, bSize), 1.0 - SATURATE(dx)));
                sdWall1 = max(sdWall1, sdBox(p, stairsTilingSize * 0.5));

                float sdWall2 = sdBox(p1 + delta, wallWidth * III);
                sdWall2 = max(sdWall2,
                    -lerp(
                        min(sdBox(p1 + wallWidth * IOO + delta, pSizeV), sdBox(p1 + wallWidth * IOO + delta, pSizeH)),
                        sdBox(p1 + wallWidth * IOO + delta, bSize), 1.0 - SATURATE(dx)));
                sdWall2 = max(sdWall2, sdBox(p, stairsTilingSize * 0.5));

                Surface wall1 = {2, 0, sdWall1};
                Surface wall2 = {2, 1, sdWall2};

                return minSurface(wall1, wall2);
            }

            void LoadBallParams(float2 resolution)
            {
                for(int i = 0; i < ballNum; i++)
                {
                    float2 uv1 = (float2(i, 0) + float2(0.5, 0.5)) / resolution;
                    float2 uv2 = (float2(i, 1) + float2(0.5, 0.5)) / resolution;
                    float3 p = tex2D(_BackBuffer, uv1).xyz;
                    float3 v = tex2D(_BackBuffer, uv2).xyz;
                    ballPos[i] = p * (ballPosMax - ballPosMin) + ballPosMin;
                    ballVel[i] = v * (ballVelMax - ballVelMin) + ballVelMin;
                }
            }

            void SaveBallParams(int2 fragCoord, inout float4 col)
            {
                for(int i = 0; i < ballNum; i++)
                {
                    float3 vel = ballVel[i];
                    float3 pos = ballPos[i];

                    float3 rand = Pcg01(float4(pos.xz, i, _ElapsedTime)) * 2.0 - 1.0;
                    float d = STAIRS_MAP(pos);
                    float3 g = GetStairsGrad(pos);
                    float3 norm = length(g) < 0.001 ? OIO : normalize(g);
                    float3 up = abs(norm.z) < 0.999 ? OOI : IOO;
                    float3 bitangent = CROSS(up, norm);
                    float3 tangent = CROSS(norm, bitangent);
                    vel = d < ballRadius ?
                        reflection * norm - friction * tangent + randomize * rand :
                        vel + (-OIO * gravity - norm * attraction) * deltaTime;

                    pos += vel * deltaTime;
                    if(_ElapsedTime < phasePeriod[11]||
                       pos.x < ballPosMin.x || pos.x > ballPosMax.x ||
                       pos.y < ballPosMin.y || pos.y > ballPosMax.y ||
                       pos.z < ballPosMin.z || pos.z > ballPosMax.z){
                       pos = lerp(ballPosMin, ballPosMax, rand * 0.2 + float3(0.4, 0.6, 0.5));
                       vel = OOO;
                    }

                    vel = SATURATE((vel - ballVelMin) / (ballVelMax - ballVelMin));
                    pos = SATURATE((pos - ballPosMin) / (ballPosMax - ballPosMin));

                    if(fragCoord.x == i)
                    {
                             if(fragCoord.y == 0) { col = float4(pos, 0.0); }
                        else if(fragCoord.y == 1) { col = float4(vel, 0.0); }
                    }
                }
            }

            Surface Map(float3 p)
            {
                float sdStairs = STAIRS_MAP(p);
                Surface s = {0, 0, sdStairs};

                float3 ballPosCenter = (ballPosMax + ballPosMin) * 0.5;
                float3 ballArea = ballPosMax - ballPosMin;

                s = minSurface(s, WallMap(p));

                float3 p1 = p - float3(0.0, 19.0, 75.0);
                p1.x -= 4.0;
                p1.xz = mul(rotate2d(lerp(0.0, -PI * 0.75, SATURATE((_ElapsedTime - phasePeriod[11] - 3.0) * 0.15))), p1.xz);
                p1.x += 4.0;
                Surface door = {3, 0, sdBox(p1, float3(4.0, 9.0, wallWidth * 0.5))};
                s = minSurface(s, door);

                Surface doorWall = {4, 0, max(
                    sdBox(p - float3(0.0, 40.0, stairsTilingSize * 0.5), float3(stairsWidth * 1.2, 30.0, wallWidth)),
                    -sdBox(p - float3(0.0, 19.0, 75.0), float3(4.0, 9.0, wallWidth * 1.1)))
                };
                s = minSurface(s, doorWall);

                Surface monitor = {1, 0, sdBox(p - float3(0.0, 32.0, 73.0), float3(5.333, 3.0, wallWidth * 0.5))};
                s = minSurface(s, monitor);

                Surface room = {5, 0, max(
                    sdBox(p - ballPosCenter, ballArea * 0.5),
                    -sdBox(p - ballPosCenter + float3(0.0, 0.0, 20.0), ballArea * 0.5 - float3(5.0, 5.0, 5.0)))
                };
                s = minSurface(s, room);

                for(int i = 0; i < ballNum; i++){
                    float sd = sdSphere(p - ballPos[i], ballRadius);
                    Surface ball = {6, i, sd};
                    s = minSurface(s, ball);
                }

                return s;
            }

            Material GetMaterial(Surface s, float3 p)
            {
                Material m = {III, OOO, 0.0, 1.0, 1.5, 0.0};

                float3 defaultColor = lerp(
                    lerp(float3(0.7, 0.8, 1.0), float3(0.6, 0.05, 0.1), SATURATE(_ElapsedTime - phasePeriod[9] - 3.0)),
                    float3(0.7, 0.8, 1.0), SATURATE(_ElapsedTime - phasePeriod[10] - 7.0));

                if(s.surfaceId == 0) //Stairs
                {
                    int3 seed = int3(p.x, p.y, p.z);
                    float3 hash = Pcg01(seed);

                    m.baseColor = defaultColor;
                    m.emission = OOO;
                    m.roughness = lerp(0.01, 0.25, hash.x);
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 1) //Monitor
                {
                    float mask = step(sin(p.x * 2.0 + sbeatTime * 3.0 - p.y * 2.0), 0.0);

                    int seed = int((p.x * 2.0 + sbeatTime * 3.0 - p.y * 2.0) / PI);
                    float hash = Pcg01(seed);

                    float3 color =
                    lerp(float3(1.0, 0.7, 0.8),
                    lerp(float3(0.7, 0.8, 1.0),
                    float3(0.7, 1.0, 0.8),
                    step(hash, 0.33)), step(hash, 0.66));

                    color = lerp(defaultColor, color, SATURATE(_ElapsedTime - phasePeriod[10] - 7.0));

                    m.baseColor = OOO;
                    m.emission = mask * color;
                    m.roughness = 1.0;
                    m.metallic = 0.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 2) //Wall
                {
                    float mask = s.objectId == 0 ? SATURATE(p.x + stairsWidth) : SATURATE(- p.x + stairsWidth);
                    mask *= 0.6;

                    int2 seed = int2(p.y, p.z);
                    float2 hash = Pcg01(seed);

                    float3 color =
                    lerp(float3(1.0, 0.7, 0.8),
                    lerp(float3(0.7, 0.8, 1.0),
                    float3(0.7, 1.0, 0.8),
                    step(hash.x, 0.33)), step(hash.x, 0.66));

                    color = lerp(defaultColor, color, SATURATE(_ElapsedTime - phasePeriod[10] - 7.0));

                    m.baseColor = color;
                    m.emission = lerp(float3(0.0, 0.0, 0.0), color, mask);
                    m.roughness = 0.4;
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 3) //door
                {
                    m.baseColor = III;
                    m.emission = OOO;
                    m.roughness = 0.01;
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 4) //door wall
                {
                    int2 seed = int2(p.x, p.y);
                    float2 hash = Pcg01(seed);
                    m.baseColor = III;
                    m.emission = OOO;
                    m.roughness = lerp(0.02, 0.98, hash.x * hash.y);
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 5) //room
                {
                    int3 seed = int3(float3(p.x, p.y, p.z) * 0.1);
                    seed.x += int(sbeatTime * 30.0);
                    seed.y += int(sbeatTime * 30.0);
                    seed.z += int(sbeatTime * 30.0);
                    float3 hash = Pcg01(seed);

                    float mask = step(sin(p.x * 0.1 + _ElapsedTime * 3.0 - p.y * 0.1), 0.0);

                    m.baseColor = III;
                    m.emission = lerp(0.1, 0.5, mask) * defaultColor;
                    m.roughness = lerp(0.03, 0.98, hash.x);
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }
                else if(s.surfaceId == 6) //ball
                {
                    float3 hash = Pcg01(int3(s.objectId, 0, 0));
                    m.baseColor = hash;
                    m.emission = hash * 0.5;
                    m.roughness = 0.03;
                    m.metallic = 1.0;
                    m.refraction = 1.5;
                    m.transmission = 0.0;
                    return m;
                }

                return m;
            }

            #define LIMIT_MARCHING_DISTANCE(D,RD,RP) lerp(D, min(MIN3(((1.0 * step(0.0, RD) - MOD(RP, 1.0)) / RD)) + EPS, D), \
            step(RP.y, stairsTilingSize * 0.5) * step(-stairsTilingSize * 0.5, RP.y) * step(RP.z, stairsTilingSize * 0.5) * step(-stairsTilingSize * 0.5, RP.z) * \
            (step(RP.x, -stairsWidth - wallWidth + wallWidth * 8.0) * step(-stairsWidth - wallWidth - wallWidth * 8.0, RP.x) + step(RP.x, stairsWidth + wallWidth + wallWidth * 8.0) * step(stairsWidth + wallWidth - wallWidth * 8.0, RP.x))\
            )
            #define MAP(P) Map(P)
            #define GET_MATERIAL(S, RP) GetMaterial(S, RP)
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

            float4 frag (v2f i) : SV_Target
            {
                float2 r = _Resolution;
                int2 fragCoord = floor(i.uv * r);
                _ElapsedTime = fmod(_ElapsedTime, phaseBPM[phaseNum] / bpm * 60.0);
                CalcBeatTime();
                CalcPhase();
                CalcCameraParams();
                LoadBallParams(r);
                float2 p = float2(fragCoord * 2.0 - r) / min(r.x, r.y);
                randomSeed = Pcg01(float4(p, _FrameCount, Pcg(_FrameCount)));
                _CameraDir = normalize(_CameraDir);
                _CameraUp = normalize(_CameraUp);
                float3 cameraRight = CROSS(_CameraUp, _CameraDir);
                _CameraUp = CROSS(_CameraDir, cameraRight);
                float3 ro = _CameraPos;
                float3 rd = normalize(cameraRight * p.x + _CameraUp * p.y + _CameraDir * _LensDistance);
                float4 col = OOOO;
                for (int iter = 0; iter < _IterMax; iter++)
                {
                    col.xyz += SAMPLE_RADIANCE(ro, rd, OOO, III);    
                }
                col.xyz = col.xyz / _IterMax;
                SaveBallParams(fragCoord, col);
                return float4(col.xyz, 1.0);
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
