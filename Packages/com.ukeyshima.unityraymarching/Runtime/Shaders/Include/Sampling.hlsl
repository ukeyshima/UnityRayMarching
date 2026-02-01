#ifndef SAMPLING_INCLUDED
#define SAMPLING_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"
#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Transform.hlsl"

float2 SampleCircle(float2 xi)
{
	float phi = 2.0 * PI * xi.x;
	return float2(cos(phi), sin(phi)) * sqrt(xi.y);
}

float3 SampleSphereWeighted(float2 xi, float3 dir, float w)
{
	float phi = 2.0 * PI * xi.x;
	float cosTheta = lerp(w, 1.0, xi.y);
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	float3 h = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
	float3 up = abs(dir.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
	float3 tangentX = normalize(CROSS(up, dir));
	float3 tangentY = normalize(CROSS(dir, tangentX));
	return tangentX * h.x + tangentY * h.y + dir * h.z;
}

float3 SampleSphere(float2 xi)
{
	return SampleSphereWeighted(xi, float3(0, 0, 1), -1.0);
}

float3 SampleHemiSphere(float2 xi, float3 n)
{
	return SampleSphereWeighted(xi, n, 0.0);
}

float3 SampleVisibleSphere(float2 xi, float3 r, float3 c, float3 p)
{
	float3 diff = c - p;
	float3 dir = normalize(diff);
	float sinThetaMax2 = (r * r) / dot(diff, diff);
	float cosThetaMax = sqrt(max(0.0, 1.0 - sinThetaMax2));
	return c + r * SampleSphereWeighted(xi, -dir, cosThetaMax);
}

float3 ImportanceSampleCosine(float2 xi, float3 n)
{
	float phi = 2.0 * PI * xi.x;
	float cosTheta = sqrt(xi.y);
	float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	float3 h = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
	float3 up = abs(n.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
	float3 tangentX = normalize(CROSS(up, n));
	float3 tangentY = normalize(CROSS(n, tangentX));
	return tangentX * h.x + tangentY * h.y + n * h.z;
}

float3 ImportanceSampleGGX(float2 xi, float roughness, float3 n)
{
    float a = roughness * roughness;
    float phi = 2.0 * PI * xi.x;
    float cosTheta = SATURATE(sqrt((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y)));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float3 h = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
    float3 up = abs(n.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 tangentX = normalize(CROSS(up, n));
    float3 tangentY = normalize(CROSS(n, tangentX));
    return tangentX * h.x + tangentY * h.y + n * h.z;
}

#endif