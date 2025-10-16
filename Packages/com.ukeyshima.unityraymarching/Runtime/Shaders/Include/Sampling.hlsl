#ifndef SAMPLING_INCLUDED
#define SAMPLING_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Transform.hlsl"

float3 SampleSphere(float2 xi)
{
	float a = xi.x * PI * 2.0;
	float z = xi.y * 2.0 - 1.0;
    float r = sqrt(1.0 - z * z);
	return float3(r * cos(a), r * sin(a), z);
}

float3 SampleHemiSphere(float2 xi, float3 dir)
{
	float3 v = SampleSphere(xi);
	return dot(dir, v) < 0.0 ? -v : v;
}

float3 ImportanceSampleGGX(float2 xi, float roughness, float3 n, float3 v)
{
    float a = roughness * roughness;
    float phi = 2.0 * PI * xi.x;
    float cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float3 h = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
    float3 up = abs(n.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 tangentX = CROSS(up, n);
    float3 tangentY = CROSS(n, tangentX);
    return reflect(v, tangentX * h.x + tangentY * h.y + n * h.z);
}

#endif