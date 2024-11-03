#ifndef TRNASFORM_INCLUDED
#define TRNASFORM_INCLUDED

float3x3 TransformBasis(float3 y, float3 z)
{
    float3 x = normalize(CROSS(y, z));
    y = normalize(CROSS(z, x));
    return float3x3(x, y, z);
}

float3x3 TransformBasis(float3 n)
{
    float3 up = abs(n.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    return TransformBasis(up, n);
}

float2 PolarCoordinates(float2 p){
    float r = length(p);
    float a = atan2(p.y, p.x);
    return float2(r, a);
}

float2x2 rotate2d(float a) {
    float s = sin(a);
    float c = cos(a);
    return float2x2(c, -s, s, c);
}

#endif