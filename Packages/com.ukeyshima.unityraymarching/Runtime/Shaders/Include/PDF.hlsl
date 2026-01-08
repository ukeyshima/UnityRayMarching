#ifndef PDF_INCLUDED
#define PDF_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/BRDF.hlsl"

float GGXPDF(float3 N, float3 V, float3 H, float roughness)
{
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    float D = DistributionGGX(NdotH, roughness);
    float3 nom = D * NdotH;
    float denom = 4.0 * VdotH;
    return nom / max(denom, 1e-5);
}

float LambertPDF(float3 N, float3 L)
{
    return max(dot(N, L), 0.0) / PI;
}

float HemiSpherePDF()
{
    return 0.5 / PI;
}

float GGXPDF(float3 N, float3 V, float3 L, float3 H, float roughness, float EI, float EO)
{
    float NdotH = abs(dot(N, H));
    float VdotH = abs(dot(V, H));
    float LdotH = abs(dot(L, H));
    float D = DistributionGGX(NdotH, roughness);
    float nom = D * NdotH;
    float sqrtDenom = EI * VdotH + EO * LdotH;
    float jacobian = (EO * EO * LdotH) / (sqrtDenom * sqrtDenom);
    return nom * jacobian;
}

float VisibleSpherePDF(float3 r, float3 c, float3 p, float3 l)
{
    float3 diff = c - p;
    if (dot(diff, diff) < 1e-5) return 0.0;
    float3 dir = normalize(diff);
    float sinThetaMax2 = SATURATE(r * r / max(dot(diff, diff), 1e-5));
    float cosThetaMax = sqrt(1.0 - sinThetaMax2);
    float cosTheta = dot(l, dir);
    if (cosTheta > cosThetaMax)
    {
        return 1.0 / max(2.0 * PI * (1.0 - cosThetaMax), 1e-5);
    }
    return 0.0;
}

#endif
