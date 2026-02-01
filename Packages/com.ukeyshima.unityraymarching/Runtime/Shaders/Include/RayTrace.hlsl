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

#ifndef BOUNCE_LIMIT
#define BOUNCE_LIMIT 1
#endif

#ifndef FRAME_COUNT
#define FRAME_COUNT 1
#endif

#ifndef FOCUS_DISTANCE
#define FOCUS_DISTANCE 10.0
#endif

#ifndef LENS_DISTANCE
#define LENS_DISTANCE 1.0
#endif

#ifndef LENS_RADIUS
#define LENS_RADIUS 1.0
#endif

#ifndef CAMERA_POS
#define CAMERA_POS OOO
#endif

#ifndef CAMERA_RIGHT
#define CAMERA_RIGHT IOO
#endif

#ifndef CAMERA_UP
#define CAMERA_UP OIO
#endif

#ifndef CAMERA_DIR
#define CAMERA_DIR OOI
#endif

#ifndef INTERSECTION
#define INTERSECTION(RO, RD, HIT_POS, SURFACE) (RayMarching(RO, RD, HIT_POS, SURFACE))
#endif

#ifndef INTERSECTION_WITH_NORMAL
#define INTERSECTION_WITH_NORMAL(RO, RD, HIT_POS, SURFACE, NORMAL) (RayMarching(RO, RD, HIT_POS, SURFACE, NORMAL))
#endif

#define ROUGHNESS_MIN 1e-4

float3 Unlit(float3 ro, float3 rd, float3 color)
{
    float3 hitPos;
    Surface s;
    float3 n;
    bool hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
        return m.baseColor;
    }
    return color;
}

float3 Diffuse(float3 ro, float3 rd, float3 color)
{
    float3 hitPos;
    Surface s;
    float3 n;
    bool hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, s, n);
    if(hit)
    {
        Material m = GET_MATERIAL(s, hitPos);
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
        float2 x = Random2();
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

float ThinLensModel(float2 p, out float3 ro, out float3 rd)
{
    float3 lensCenter = CAMERA_POS + CAMERA_DIR * LENS_DISTANCE;
    float3 sensorPoint = CAMERA_POS + CAMERA_RIGHT * p.x + CAMERA_UP * p.y;
    float2 sampleLensPoint = SampleCircle(Random2()) * LENS_RADIUS;
    float3 lensPoint = lensCenter + CAMERA_RIGHT * sampleLensPoint.x + CAMERA_UP * sampleLensPoint.y;
    float lensArea = PI * LENS_RADIUS * LENS_RADIUS;
    float3 focalDir = normalize(lensCenter - sensorPoint);
    float3 focalPoint = lensCenter + focalDir * (FOCUS_DISTANCE / dot(focalDir, CAMERA_DIR));
    float3 lensDir = lensPoint - sensorPoint;
    float dist = length(lensDir);
    float cosTheta = dot(normalize(lensDir), CAMERA_DIR);
    ro = lensPoint;
    rd = normalize(focalPoint - lensPoint);
    return lensArea * cosTheta / (dist * dist);
}

float PinholeModel(float2 p, out float3 ro, out float3 rd)
{
    float3 sensorPoint = CAMERA_POS + (CAMERA_RIGHT * p.x + CAMERA_UP * p.y);
    float3 lensCenter = CAMERA_POS + CAMERA_DIR * LENS_DISTANCE;
    ro = sensorPoint;
    rd = normalize(lensCenter - sensorPoint);
    return III;
}

float3 PathTrace(float3 ro, float3 rd, float3 color, float3 weight)
{
    Surface surface = {0, 0, 0.0};
    float3 hitPos = OOO;
    float3 normal = OOI;
    float3 acc = OOO;
    float wBRDF = 1.0;
    
    [loop]
    for (int bounce = 0; bounce <= BOUNCE_LIMIT; bounce++)
    {
        bool hit = INTERSECTION_WITH_NORMAL(ro, rd, hitPos, surface, normal);
        if(!hit) {
            acc += color * weight;
            break;
        }
        Material m = GET_MATERIAL(surface, hitPos);
        acc += m.emission * weight * wBRDF;
        
        float4 rand = Random4();
#ifdef NEXT_EVENT_ESTIMATION
        {
            int lightId;
            float3 lro = hitPos + normal * EPS * 2.0;
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
                SampleBRDF(rand.xy, m, normal, false, -rd, lLight, hitPos, brdfLight, pdfBrdf, ndotl);
                acc += mLight.emission * brdfLight / max(pdfLight + pdfBrdf, 1e-20) * ndotl * weight;
            }
        }
#endif

        float3 brdf;
        float pdf;
        float ndotl;
        ro = hitPos;
        SampleBRDF(rand.xy, m, normal, true, -rd, rd, ro, brdf, pdf, ndotl);
        
#ifdef NEXT_EVENT_ESTIMATION
        float pdfLight = SAMPLE_LIGHT_PDF(hitPos, rd);
        wBRDF = pdf / max(pdf + pdfLight, 1e-20);
#endif
        
        weight *= brdf / max(pdf, 1e-20) * ndotl;

        if (rand.z < RUSSIAN_ROULETTE){ break; }
        weight /= (1.0 - RUSSIAN_ROULETTE);
        
        if (dot(weight, weight) < EPS) { break; }
    }
    return acc;
}

#endif