#ifndef RAY_TRACE_INCLUDED
#define RAY_TRACE_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"

#ifndef MAP
#define MAP(P) {0, 0, FLOAT_MAX}
#endif

#ifndef GET_MATERIAL
#define GET_MATERIAL(S, RP) {IOI, 0, OOO}
#endif

#ifndef LIMIT_MARCHING_DISTANCE
#define LIMIT_MARCHING_DISTANCE(D, RD, RP) (D)
#endif

bool RayMarching(float3 ro, float3 rd, int stepCount, float maxDistance, out float3 rp, out Surface s)
{
    rp = ro;
    float rl = 0.0;
    [loop]
    for (int i = 0; i < stepCount; i++)
    {
        s = MAP(rp);
        float d = s.distance;
        if (abs(d) < EPS){ return true; }
        if (rl > maxDistance){ break; }
        d = LIMIT_MARCHING_DISTANCE(d, rd, rp);
        rl += d;
        rp = ro + rd * rl;
    }
    return false;
}

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
    return normalize(GetGrad(p));
}

float3 Unlit(float3 ro, float3 rd, float3 color, int stepCount, float maxDistance)
{
    float3 hitPos;
    Surface s;
    bool hit = RayMarching(ro, rd, stepCount, maxDistance, hitPos, s);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
        return m.baseColor;
    }
    return color;
}

float3 Diffuse(float3 ro, float3 rd, float3 color, int stepCount, float maxDistance)
{
    float3 hitPos;
    Surface s;
    bool hit = RayMarching(ro, rd, stepCount, maxDistance, hitPos, s);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
        float3 n = GetNormal(hitPos);
        return dot(n, -rd) * m.baseColor;
    }
    return color;
}

float3 PathTrace(float3 ro0, float3 rd0, float3 color, int stepCount, float maxDistance, int iterMax, int bounceLimit, int seed)
{
    float3 sum = OOO;
    Surface s;
    bool hit;
    Material m;
    float3 n;
    float2 rand;
    float3 v;
    float3 hitPos;
    [loop]
    for(int iter = 0; iter < iterMax; iter++)
    {
        float3 ro = ro0;
        float3 rd = rd0;
        float3 acc = OOO;
        float3 weight = III;
        [loop]
        for (int bounce = 0; bounce <= bounceLimit; bounce++)
        {
            hit = RayMarching(ro, rd, marchingStep, maxDistance, hitPos, s);
            if(!hit) {
                acc += color * weight;
                break;
            }
            m = GET_MATERIAL(s, hitPos);
            float d = s.distance;
            float3 e = m.emission;
            float r = m.roughness;
            float3 c = m.baseColor;
            n = GetNormal(hitPos);
            v = -rd;
            rand = Pcg01(float4(hitPos, iter * bounceLimit + bounce + _ElapsedTime)).xy;
            ro = hitPos + n * EPS * 2.0;

            float3 brdf;
            float pdf;
            if(r > 0.99) {
                rd = ImportanceSampleLambert(rand, n);
                brdf = LambertBRDF(c);
                pdf = LambertPDF(n, rd);
            }else{
                rd = ImportanceSampleGGX(rand, r, n, rd);
                if ( dot( rd, n ) < 0.0 ) { break; }
                brdf = MicrofacetGGXBRDF(n, v, rd, c, r);
                pdf = GGXPDF(n, v, rd, r);
            }

            acc += e * clamp(weight, 0.0, 1.0);
            weight *= brdf / pdf * max(dot(rd, n), 0.0);
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / float(iterMax);
}

#endif