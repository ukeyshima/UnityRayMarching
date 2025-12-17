#ifndef DISTANCE_FUNCTION_INCLUDED
#define DISTANCE_FUNCTION_INCLUDED

//https://iquilezles.org/articles/distfunctions/

float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

float sdPlane(float3 p, float3 n, float h)
{
  return dot(p, n) + h;
}

float sdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdCapsule(float3 p, float3 a, float3 b, float r )
{
    float3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdTorus(float3 p, float2 t)
{
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

#endif