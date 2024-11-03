#ifndef BRDF_OVER_PDF_INCLUDED
#define BRDF_OVER_PDF_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/BRDF.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/PDF.hlsl"

float3 Lambert(float3 baseColor, float3 N, float3 L)
{
    return baseColor / dot(N, L);
}

float3 GGX(float3 N, float3 V, float3 L, float roughness, float3 baseColor)
{
    float3 H = normalize(L + V);
    float NdotH = max(dot(N, H), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    float3 F = FresnelSchlick(VdotH, baseColor);
    return F * VdotH / (NdotH * (NdotV * (1.0 - k) + k) * (NdotL * (1.0 - k) + k));
}

#endif