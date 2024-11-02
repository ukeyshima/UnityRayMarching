#ifndef INFO_INCLUDED
#define INFO_INCLUDED

struct Surface {
    int surfaceId;
    int objectId;
    float distance;
};

struct Material {
    float3 baseColor;
    float roughness;
    float3 emission;
};

Surface minSurface(Surface a, Surface b)
{
    if (a.distance < b.distance)
    {
        return a;
    }
    return b;
}

Surface maxSurface(Surface a, Surface b)
{
    if (a.distance > b.distance)
    {
        return a;
    }
    return b;
}

#endif