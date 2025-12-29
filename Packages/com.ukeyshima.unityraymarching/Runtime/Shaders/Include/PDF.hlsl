#ifndef PDF_INCLUDED
#define PDF_INCLUDED

float GGXPDF(float3 N, float3 V, float3 H, float roughness)
{
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    float D = DistributionGGX(NdotH, roughness);
    return D * NdotH / (4.0 * VdotH);
}

float LambertPDF(float3 N, float3 L)
{
    return dot(N, L) / PI;
}

float HemiSpherePDF()
{
    return 0.5 / PI;
}

#endif
