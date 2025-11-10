#ifndef RAY_TRACE_INCLUDED
#define RAY_TRACE_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Info.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/RayMarch.hlsl"

#ifndef GET_MATERIAL
#define GET_MATERIAL(S, RP) {IOI, 0, OOO}
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

float3 Unlit(float3 ro, float3 rd, float3 color, out float3 pos, out float3 normal)
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
        return m.baseColor;
    }
    return color;
}

float3 Diffuse(float3 ro, float3 rd, float3 color, out float3 pos, out float3 normal)
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
        return dot(n, -rd) * m.baseColor;
    }
    return color;
}

void CalcBRDFAndPDF(float r, float3 n, float3 v, float3 c, float3 rd, out float3 brdf, out float pdf)
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

void CalcBRDFAndPDF(float2 xi, float r, float3 n, float3 v, float3 c, inout float3 rd, out float3 brdf, out float pdf)
{
    if (r <= REFLECT_THRESHOLD) { rd = reflect(rd, n); }
    else if(r > LAMBERT_THRESHOLD) { rd = SampleHemiSphere(xi, n); }
    else { rd = ImportanceSampleGGX(xi, r, n, rd); }
    CalcBRDFAndPDF(r, n, v, c, rd, brdf, pdf);
}

float3 PathTrace(float3 ro0, float3 rd0, float3 color, out float3 pos, out float3 normal)
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
            float3 c = m.baseColor;
            float3 v = -rd;
            float4 rand = Pcg01(float4(hitPos, iter * BOUNCE_LIMIT + bounce + _ElapsedTime));

            ro = hitPos + n * EPS * 2.0;
            
            float3 brdf;
            float pdf;
            CalcBRDFAndPDF(rand.xy, r, n, v, c, rd, brdf, pdf);
            
            float w = 1.0;
            if (NEXT_EVENT_ESTIMATION)
            {
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
                        CalcBRDFAndPDF(r, n, v, c, rd_light, brdf_light, pdf_light);
                        float w_light = pdf_light / (pdf_light + pdf);
                        w = pdf / (pdf + pdf_light);
                        float weight_light = brdf_light / pdf_light * max(dot(rd_light, n), 0.0) * w_light * weight;
                        acc += e_light * weight_light;
                    }
                }   
            }
            
            acc += e * weight * w;
            weight *= brdf / pdf * max(dot(rd, n), 0.0);

            float rr_prob = RUSSIAN_ROULETTE;
            if (rand.z < rr_prob){ break; }
            weight /= (1.0 - rr_prob);
            
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / ITER_MAX;
}

#endif