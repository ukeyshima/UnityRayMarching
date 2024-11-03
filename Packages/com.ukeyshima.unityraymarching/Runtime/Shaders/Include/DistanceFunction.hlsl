#ifndef DISTANCE_FUNCTION_INCLUDED
#define DISTANCE_FUNCTION_INCLUDED

float sdSphere(float3 p, float r)
{
    return length(p) - r;
}

float sdPlane(float3 p, float3 n, float h)
{
  return dot(p, n) + h;
}

float sdBox( float3 p, float3 b )
{
  float3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdStairs(float2 p)
{
    float2 pf = float2(p.x + p.y, p.x + p.y) * 0.5;
    float2 d = p - float2(floor(pf.x), ceil(pf.y));
    float2 d2 = p - float2(floor(pf.x + 0.5), floor(pf.y + 0.5));
    float d3 = length(float2(min(d.x, 0.0), max(d.y, 0.0)));
    float d4 = length(float2(max(d2.x, 0.0), min(d2.y, 0.0)));
    return d3 - d4;
}

float sdStairs(float2 p, float h)
{
    p.xy = p.y < p.x ? p.yx : p.xy;
    return sdStairs(p - float2(0.0, h));
}

float sdStairs(float3 p, float h, float w)
{
    float x = abs(p.x) - w;
    float d = sdStairs(p.zy, h);
    return max(x, d);
}

float sdWireframeBox(float3 p, float3 s, float e)
{
    float b = sdBox(p, float3(s.x * 0.5, s.y * 0.5, s.z * 0.5));
    b = max(b, -sdBox(p, float3(s.x, s.y * 0.5 - e, s.z * 0.5 - e)));
    b = max(b, -sdBox(p, float3(s.x * 0.5 - e, s.y, s.z * 0.5 - e)));
    b = max(b, -sdBox(p, float3(s.x * 0.5 - e, s.y * 0.5 - e, s.z)));
    return b;
}

#endif