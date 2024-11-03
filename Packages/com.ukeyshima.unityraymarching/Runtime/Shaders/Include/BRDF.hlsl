#ifndef BRDF_INCLUDED
#define BRDF_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"

float DistributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float nom = a2;
    float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return nom / denom;
}

float GeometrySmith(float NdotV, float NdotL, float roughness) {
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

float3 FresnelSchlick(float VdotH, float3 F0) {
    // return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
    return F0 + (1.0 - F0) * exp2((-5.55473 * VdotH - 6.98316) * VdotH);
}

float3 MicrofacetGGXBRDF(float3 N, float3 V, float3 L, float3 baseColor, float roughness) {
    float3 H = normalize(L + V);
    float NdotH = max(dot(N, H), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    float3 F0 = baseColor;
    float3 F = FresnelSchlick(VdotH, F0);
	float D = DistributionGGX(NdotH, roughness);
	float G = GeometrySmith(NdotV, NdotL, roughness);
    float3 nominator = D * G * F;
	float denominator = 4.0 * NdotV * NdotL;
	return nominator / denominator;
}

float3 LambertBRDF(float3 baseColor) {
    return baseColor / PI;
}

#endif