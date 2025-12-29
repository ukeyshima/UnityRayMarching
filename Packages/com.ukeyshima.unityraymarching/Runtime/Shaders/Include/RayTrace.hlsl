#ifndef RAY_TRACE_INCLUDED
#define RAY_TRACE_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Pcg.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/RayMarch.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Sampling.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/BRDF.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/PDF.hlsl"

#ifndef GET_MATERIAL
#define GET_MATERIAL(S, RP) {IOI, 0, OOO}
#endif

#ifndef SAMPLE_LIGHT
#define SAMPLE_LIGHT(X) {0, float3(0, 0, 0)}
#endif

#ifndef RUSSIAN_ROULETTE
#define RUSSIAN_ROULETTE 0.0
#endif

#ifndef ITER_MAX
#define ITER_MAX 1
#endif

#ifndef BOUNCE_LIMIT
#define BOUNCE_LIMIT 1
#endif

#ifndef INTERSECTION
#define INTERSECTION(RO, RD, HIT_POS, SURFACE) (RayMarching(RO, RD, HIT_POS, SURFACE))
#endif

#ifndef INTERSECTION_WITH_NORMAL
#define INTERSECTION_WITH_NORMAL(RO, RD, HIT_POS, SURFACE, NORMAL) (RayMarching(RO, RD, HIT_POS, SURFACE, NORMAL))
#endif

#define REFLECT_THRESHOLD 0.01
#define LAMBERT_THRESHOLD 0.99

float3 Unlit(float3 ro, float3 rd, float3 color, out float3 pos, out float3 normal, out Surface surface)
{
    float3 hitPos;
    Surface s;
    float3 n;
    bool hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
        pos = hitPos;
        normal = n;
        surface = s;
        return m.baseColor;
    }
    return color;
}

float3 Diffuse(float3 ro, float3 rd, float3 color, out float3 pos, out float3 normal, out Surface surface)
{
    float3 hitPos;
    Surface s;
    float3 n;
    bool hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
        pos = hitPos;
        normal = n;
        surface = s;
        return dot(n, -rd) * m.baseColor;
    }
    return color;
}

void CalcBRDFAndPDF(float2 xi, Material m, float3 n, bool withSample, in float3 v, inout float3 l, out float3 brdf, out float pdf)
{
    float r = m.roughness;
    float me = m.metallic;
    float3 c = m.baseColor;
        
    float specW = lerp(0.04, 1.0, me);
    float diffW = (1.0 - specW);
    if (withSample)
    {
        float x = Pcg01(xi.x);
        if (x < diffW)
        {
            l = ImportanceSampleCosine(xi, n);
        }
        else
        {
            l = reflect(-v, ImportanceSampleGGX(xi, r, n));
        }   
    }

    float3 h = normalize(v + l);
    float3 F0 = lerp(0.04 * III, c, me);
    float3 F = FresnelSchlick(max(dot(v, h), 0.0), F0);
    brdf = LambertBRDF(c) * (1.0 - me) * (1.0 - F) + MicrofacetGGXBRDF(n, v, l, h, F0, r);
    pdf = LambertPDF(n, l) * diffW + GGXPDF(n, v, h, r) * specW;
}

float3 PathTrace(float3 ro0, float3 rd0, float3 color, out float3 pos, out float3 normal, out Surface surface)
{
    float3 sum = OOO;
    Surface s;
    float3 hitPos;
    float3 n;
    bool hit = INTERSECTION_WITH_NORMAL(ro0, rd0, hitPos, s, n);
    if(hit)
    {
        ro0 = hitPos;
        pos = hitPos;
        normal = n;
        surface = s;
    }
    else
    {
        return color;
    }
    [loop]
    for(int iter = 0; iter < ITER_MAX; iter++)
    {
        float3 ro = ro0;
        float3 rd = rd0;
        float3 acc = OOO;
        float3 weight = III;
        [loop]
        for (int bounce = 0; bounce <= BOUNCE_LIMIT; bounce++)
        {
            hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
            if(!hit) {
                acc += color * weight;
                break;
            }
            Material m = GET_MATERIAL(s, hitPos);
            float3 e = m.emission;
            float r = m.roughness;
            float me = m.metallic;
            float3 c = m.baseColor;
            float3 v = -rd;

            ro = hitPos + n * EPS * 2.0;
            
            if (r <= REFLECT_THRESHOLD)
            {
                float3 l = reflect(-v, n);
                float3 h = normalize(l + v);
                float3 F0 = lerp(0.04 * III, c, me);
                rd = l;
                acc += e * weight;
                weight *= FresnelSchlick(max(dot(v, h), 0.0), F0);
                continue;
            }
            
            float4 rand = Pcg01(float4(hitPos, (iter * BOUNCE_LIMIT + bounce) + _ElapsedTime));
            
            float3 brdf;
            float pdf;
            CalcBRDFAndPDF(rand.xy, m, n, true, v, rd, brdf, pdf);
            
            float w = 1.0;
#ifdef NEXT_EVENT_ESTIMATION
            if (dot(e, e) < EPS && r > REFLECT_THRESHOLD)
            {
                SamplePos sampleLight = SAMPLE_LIGHT(rand.w);
                float3 rd_light = normalize(sampleLight.position - ro);
                float3 hit_lightPos;
                Surface s_light;
                bool hit_light = INTERSECTION(ro, rd_light, hit_lightPos, s_light);
                if (hit_light && s_light.objectId == sampleLight.objectId)
                {
                    Material m_light = GET_MATERIAL(s_light, hit_lightPos);
                    float3 e_light = m_light.emission;
                    float3 brdf_light;
                    float pdf_light;
                    CalcBRDFAndPDF(rand.xy, m, n, false, v, rd_light, brdf_light, pdf_light);
                    float pdf_sq = pdf * pdf;
                    float pdf_light_sq = pdf_light * pdf_light;
                    float sum_sq = pdf_sq + pdf_light_sq;
                    float w_light = pdf_light_sq / sum_sq;
                    w = pdf_sq / sum_sq;
                    float weight_light = brdf_light / pdf_light * max(dot(rd_light, n), 0.0) * w_light * weight;
                    acc += e_light * weight_light;
                }
            }   
#endif
            
            acc += e * weight * w;
            weight *= brdf / max(pdf, 1e-5) * max(dot(rd, n), 0.0);

            if (rand.z < RUSSIAN_ROULETTE){ break; }
            weight /= (1.0 - RUSSIAN_ROULETTE);
            
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / ITER_MAX;
}

#endif