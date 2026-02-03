#ifndef INFO_INCLUDED
#define INFO_INCLUDED

struct Surface
{
    int surfaceId;
    int objectId;
    float distance;
};

struct Material
{
    float3 baseColor;
    float3 emission;
    float roughness;
    float metallic;
    float refraction;
    float transmission;
};

Surface MinSurface(Surface a, Surface b)
{
    if (a.distance < b.distance)
    {
        return a;
    }
    return b;
}

Surface MaxSurface(Surface a, Surface b)
{
    if (a.distance > b.distance)
    {
        return a;
    }
    return b;
}

#endif