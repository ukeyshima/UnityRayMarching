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

#ifndef NEXT_EVENT_ESTIMATION
#define NEXT_EVENT_ESTIMATION false
#endif

#ifndef SAMPLE_LIGHT
#define SAMPLE_LIGHT(X) {0, float3(0, 0, 0)}
#endif

#ifndef RUSSIAN_ROULETTE
#define RUSSIAN_ROULETTE 0.0
#endif

#define REFLECT_THRESHOLD 0.01
#define LAMBERT_THRESHOLD 0.99

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

void CalcBRDFAndPDF(float2 xi, float r, float3 n, float3 v, float3 c, inout float3 rd, out float3 brdf, out float pdf)
{
    if (r <= REFLECT_THRESHOLD)
    {
        rd = reflect(rd, n); 
        brdf = FresnelSchlick(max(dot(rd, v), 0.0), c);
        pdf = 1.0; 
    }
    else if(r > LAMBERT_THRESHOLD)
    {
        rd = SampleHemiSphere(xi, n);
        brdf = LambertBRDF(c);
        pdf = LambertPDF(n, rd);
    }
    else
    {
        rd = ImportanceSampleGGX(xi, r, n, rd);
        if (dot(rd, n) < 0.0) {
            brdf = OOO;
            pdf = 0.0;
            return;
        }
        brdf = MicrofacetGGXBRDF(n, v, rd, c, r);
        pdf = GGXPDF(n, v, rd, r);
    }
}

void CalcLightBRDFAndPDF(float2 xi, float r, float3 n, float3 v, float3 c, float3 rd, out float3 brdf, out float pdf)
{
    if (r <= REFLECT_THRESHOLD)
    {
        brdf = FresnelSchlick(max(dot(rd, v), 0.0), c);
        pdf = 1.0; 
    }
    else if(r > LAMBERT_THRESHOLD)
    {
        brdf = LambertBRDF(c);
        pdf = LambertPDF(n, rd);
    }
    else
    {
        brdf = MicrofacetGGXBRDF(n, v, rd, c, r);
        pdf = GGXPDF(n, v, rd, r);
    }
}

float3 PathTrace(float3 ro0, float3 rd0, float3 color, int stepCount, float maxDistance, int iterMax, int bounceLimit, int seed)
{
    float3 sum = OOO;
    Surface s;
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
            bool hit = RayMarching(ro, rd, stepCount, maxDistance, hitPos, s);
            if(!hit) {
                acc += color * weight;
                break;
            }
            Material m = GET_MATERIAL(s, hitPos);
            float3 e = m.emission;
            float r = m.roughness;
            float3 c = m.baseColor;
            float3 n = GetNormal(hitPos);
            float3 v = -rd;
            float4 rand = Pcg01(float4(hitPos, iter * bounceLimit + bounce + _ElapsedTime));
            float4 rand2 = Pcg01(rand);

            float rr_prob = RUSSIAN_ROULETTE;
            if (rand2.x < rr_prob){ break; }
            weight /= (1.0 - rr_prob);

            ro = hitPos + n * EPS * 2.0;
            
            float3 brdf;
            float pdf;
            CalcBRDFAndPDF(rand.xy, r, n, v, c, rd, brdf, pdf);
            
            float w = 1.0;
            if (NEXT_EVENT_ESTIMATION)
            {
                if (dot(e, e) < EPS && r > REFLECT_THRESHOLD)
                {
                    SamplePos sampleLight = SAMPLE_LIGHT(rand2.y);
                    float3 rd_light = normalize(sampleLight.position - ro);
                    float3 hit_lightPos;
                    Surface s_light;
                    bool hit_light = RayMarching(ro, rd_light, stepCount, maxDistance, hit_lightPos, s_light);
                    if (hit_light && s_light.objectId == sampleLight.objectId)
                    {
                        Material m_light = GET_MATERIAL(s_light, hit_lightPos);
                        float3 e_light = m_light.emission;
                        float3 brdf_light;
                        float pdf_light;
                        CalcLightBRDFAndPDF(rand.zw, r, n, v, c, rd_light, brdf_light, pdf_light);
                        float w_light = (pdf_light) / (pdf_light + pdf);
                        w = (pdf) / (pdf + pdf_light);
                        float weight_light = brdf_light / pdf_light * max(dot(rd_light, n), 0.0) * w_light * weight;
                        acc += e_light * weight_light;
                    }
                }   
            }
            
            acc += e * weight;
            weight *= brdf / pdf * max(dot(rd, n), 0.0) * w;
            
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / iterMax;
}

#endif