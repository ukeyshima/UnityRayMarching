#ifndef TRANSFORM_INCLUDED
#define TRANSFORM_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"

float3x3 TransformBasis(float3 up, float3 forward)
{
    up = normalize(up);
    forward = normalize(forward);
    float3 right = cross(up, forward);
    up = cross(forward, right);
    return float3x3(right, up, forward);
}

float2 PolarCoordinates(float2 p)
{
    float r = length(p);
    float a = atan2(p.y, p.x);
    return float2(r, a);
}

float2x2 Rotate2d(float a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(c, -s, s, c);
}

#endif