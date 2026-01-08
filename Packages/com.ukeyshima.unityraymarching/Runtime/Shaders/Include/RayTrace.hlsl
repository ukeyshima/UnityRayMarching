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

#define ROUGHNESS_MIN 1e-4

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

void SampleBRDF(float2 xi, Material m, float3 n, bool withSample, in float3 v, inout float3 l, inout float3 ro, out float3 brdf, out float pdf, out float ndotl)
{
    bool entering = dot(v, n) > 0.0;
    float3 normal = entering ? n : -n;
    float ior = max(m.refraction, 1.0);
    float etaI = entering ? 1.0 : ior;
    float etaO = entering ? ior : 1.0;
    float r = max(m.roughness, ROUGHNESS_MIN);
    float3 F0 = lerp(pow((ior - 1.0) / (ior + 1.0), 2.0) * III, m.baseColor, m.metallic);
    float3 albedo = lerp(m.baseColor, OOO, m.metallic);
    float3 F = FresnelSchlick(dot(v, normal), F0);
    
    float wSpec = (F.x + F.y + F.z) / 3.0;
    float wDiff = (1.0 - wSpec) * (1.0 - m.transmission);
    float wTrans = (1.0 - wSpec) * m.transmission;

    ndotl = max(dot(normal, l), 0.0);
    
    if (withSample)
    {
        float2 x = Pcg01(xi);
        if (x.x < wSpec)
        {
            l = reflect(-v, ImportanceSampleGGX(xi, r, normal));
            ndotl = max(dot(normal, l), 0.0);
            ro = ro + normal * EPS * 2.0;
        }
        else if (x.x < wSpec + wDiff)
        {
            l = ImportanceSampleCosine(xi, normal);
            ndotl = max(dot(normal, l), 0.0);
            ro = ro + normal * EPS * 2.0;
        }
        else
        {
            float3 h = ImportanceSampleGGX(xi, r, normal);
            l = refract(-v, h, etaI / etaO);
            ndotl = max(-dot(normal, l), 0.0);
            ro = ro - normal * EPS * 2.0;
        }
    }
    
    float3 h = normalize(v + l);
    float3 hTrans = -normalize(l * etaO + v * etaI);
    F = FresnelSchlick((dot(v, h)), F0);
    brdf = MicrofacetGGXBRDF(normal, v, l, h, F0, r) +
           LambertBRDF(n, v, l, albedo) * (1.0 - F) * (1.0 - m.transmission) +
           MicrofacetGGXBTDF(normal, v, l, hTrans, F0, r, etaI, etaO) * m.baseColor * m.transmission;
    pdf = GGXPDF(normal, v, h, r) * wSpec +
          LambertPDF(normal, l) * wDiff +
          GGXPDF(normal, v, l, hTrans, r, etaI, etaO) * wTrans;
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
            acc += m.emission * weight * wBRDF;
            
            float4 rand = Pcg01(float4(hitPos, (iter * BOUNCE_LIMIT + bounce) + _ElapsedTime));
#ifdef NEXT_EVENT_ESTIMATION
            {
                int lightId;
                float3 lro = hitPos + n * EPS * 2.0;
                float3 lLight = SAMPLE_LIGHT(rand.w, hitPos, lightId);
                float pdfLight = SAMPLE_LIGHT_PDF(hitPos, lLight);
                float3 hitLightPos;
                Surface sLight;
                bool hitLight = INTERSECTION(lro, lLight, hitLightPos, sLight);
                if (hitLight && sLight.surfaceId == lightId)
                {
                    Material mLight = GET_MATERIAL(sLight, hitLightPos);
                    float3 brdfLight;
                    float pdfBrdf;
                    float ndotl;
                    SampleBRDF(rand.xy, m, n, false, -rd, lLight, hitPos, brdfLight, pdfBrdf, ndotl);
                    acc += mLight.emission * brdfLight / max(pdfLight + pdfBrdf, 1e-20) * ndotl * weight;
                }
            }
#endif

            float3 brdf;
            float pdf;
            float ndotl;
            ro = hitPos;
            SampleBRDF(rand.xy, m, n, true, -rd, rd, ro, brdf, pdf, ndotl);
            
#ifdef NEXT_EVENT_ESTIMATION
            float pdfLight = SAMPLE_LIGHT_PDF(hitPos, rd);
            wBRDF = pdf / max(pdf + pdfLight, 1e-20);
#endif
            
            weight *= brdf / max(pdf, 1e-20) * ndotl;

            if (rand.z < RUSSIAN_ROULETTE){ break; }
            weight /= (1.0 - RUSSIAN_ROULETTE);
            
            if (dot(weight, weight) < EPS) { break; }
        }
        sum += acc;
    }
    return sum / ITER_MAX;
}

#endif