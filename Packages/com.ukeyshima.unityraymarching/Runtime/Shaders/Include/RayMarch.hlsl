#ifndef RAY_MARCH_INCLUDED
#define RAY_MARCH_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"

#ifndef MAP
#define MAP(P) {0, 0, FLOAT_MAX}
#endif

#ifndef STEP_COUNT
#define STEP_COUNT 70
#endif

#ifndef MAX_DISTANCE
#define MAX_DISTANCE 1000.0
#endif

#ifndef LIMIT_MARCHING_DISTANCE
#define LIMIT_MARCHING_DISTANCE(D, RD, RP) (D)
#endif

float3 GetGrad(float3 p)
{
    const float e = EPS;
    const float2 k = float2(1, -1);
    return k.xyy * MAP(p + k.xyy * e).distance +
           k.yyx * MAP(p + k.yyx * e).distance +
           k.yxy * MAP(p + k.yxy * e).distance +
           k.xxx * MAP(p + k.xxx * e).distance;
}

float3 GetNormal(float3 p)
{
    float3 g = GetGrad(p);
    return length(g) < FLOAT_MIN ? OOO : normalize(g);
}

bool RayMarching(float3 ro, float3 rd, out float3 rp, out Surface s)
{
    rp = ro;
    float rl = 0.0;
    bool hit = false;
    [loop]
    for (int i = 0; i < STEP_COUNT; i++)
    {
        s = MAP(rp);
        float d = s.distance;
        hit = abs(d) < EPS;
        if (hit){ break; }
        if (rl > MAX_DISTANCE){ break; }
        d = LIMIT_MARCHING_DISTANCE(d, rd, rp);
        rl += d;
        rp = ro + rd * rl;
    }
    return hit;
}

bool RayMarching(float3 ro, float3 rd, out float3 rp, out Surface s, out float3 normal)
{
    bool hit = RayMarching(ro, rd, rp, s);
    if (hit) normal = GetNormal(rp);
    return hit;
}

#endif