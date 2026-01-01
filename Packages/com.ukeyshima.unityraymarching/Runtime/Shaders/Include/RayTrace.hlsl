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
#define SAMPLE_LIGHT(X, P, ID) OOO
#endif

#ifndef SAMPLE_LIGHT_PDF
#define SAMPLE_LIGHT_PDF(P, L) 0.0
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

void SampleBRDF(float2 xi, Material m, float3 n, bool withSample, in float3 v, inout float3 l, out float3 brdf, out float pdf)
{
    float3 albedo = lerp(m.baseColor, OOO, m.metallic);
    float3 F0 = lerp(0.04 * III, m.baseColor, m.metallic);
    float3 F = FresnelSchlick(max(dot(v, n), 0.0), F0);
        
    float wSpec = MAX3(F);
    float wDiff = (1.0 - wSpec);
    if (withSample)
    {
        float x = Pcg01(xi.x);
        if (x < wDiff)
        {
            l = ImportanceSampleCosine(xi, n);
        }
        else
        {
            l = reflect(-v, ImportanceSampleGGX(xi, m.roughness, n));
        }   
    }

    float3 h = normalize(v + l);
    F = FresnelSchlick(max(dot(v, h), 0.0), F0);
    brdf = LambertBRDF(albedo) * (1.0 - F) + MicrofacetGGXBRDF(n, v, l, h, F0, m.roughness);
    pdf = LambertPDF(n, l) * wDiff + GGXPDF(n, v, h, m.roughness) * wSpec;
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
        float wBRDF = 1.0;
        [loop]
        for (int bounce = 0; bounce <= BOUNCE_LIMIT; bounce++)
        {
            hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
            if(!hit) {
                acc += color * weight;
                break;
            }
            Material m = GET_MATERIAL(s, hitPos);
            float3 v = -rd;
            acc += m.emission * weight * wBRDF;

            ro = hitPos + n * EPS * 2.0;
            
            if (m.roughness <= REFLECT_THRESHOLD)
            {
                float3 l = reflect(-v, n);
                float3 h = normalize(l + v);
                float3 F0 = lerp(0.04 * III, m.baseColor, m.metallic);
                float3 F = FresnelSchlick(max(dot(v, h), 0.0), F0); 
                rd = l;
                acc += m.emission * weight;
                weight *= F;
                wBRDF = 1.0;
                continue;
            }
            
            float4 rand = Pcg01(float4(hitPos, (iter * BOUNCE_LIMIT + bounce) + _ElapsedTime));
            
#ifdef NEXT_EVENT_ESTIMATION
            {
                int lightId;
                float3 lLight = SAMPLE_LIGHT(rand.w, hitPos, lightId);
                float pdfLight = SAMPLE_LIGHT_PDF(hitPos, lLight);
                float3 hitLightPos;
                Surface sLight;
                bool hitLight = INTERSECTION(ro, lLight, hitLightPos, sLight);
                if (hitLight && sLight.surfaceId == lightId)
                {
                    Material mLight = GET_MATERIAL(sLight, hitLightPos);

                    float3 brdfLight;
                    float pdfBrdf;
                    SampleBRDF(rand.xy, m, n, false, v, lLight, brdfLight, pdfBrdf);
            
                    float wNEE = pdfLight / max(pdfLight + pdfBrdf, 1e-5);
                    float ndotl = max(dot(n, lLight), 0.0);
                    acc += mLight.emission * brdfLight / max(pdfLight, 1e-5) * ndotl * wNEE * weight;
                }
            }
#endif

            float3 brdf;
            float pdf;
            SampleBRDF(rand.xy, m, n, true, v, rd, brdf, pdf);

#ifdef NEXT_EVENT_ESTIMATION
            float pdfLight = SAMPLE_LIGHT_PDF(hitPos, rd);
            wBRDF = pdf / max(pdf + pdfLight, 1e-5);
#endif
            
            float ndotl = max(dot(rd, n), 0.0);
            weight *= brdf / max(pdf, 1e-5) * ndotl;

            if (rand.z < RUSSIAN_ROULETTE){ break; }
            weight /= (1.0 - RUSSIAN_ROULETTE);
            
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / ITER_MAX;
}

#endif