#ifndef PCG_INCLUDED
#define PCG_INCLUDED

#include "Packages/com.ukeyshima.unityraymarching/Runtime/Shaders/Include/Common.hlsl"

uint Pcg(uint v)
{
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

uint2 Pcg2d(uint2 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v>>16u);
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v>>16u);
    return v;
}

uint3 Pcg3d(uint3 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y*v.z;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    v ^= v >> 16u;
    v.x += v.y*v.z;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    return v;
}

uint4 Pcg4d(uint4 v)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y*v.w;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    v.w += v.y*v.z;
    v ^= v >> 16u;
    v.x += v.y*v.w;
    v.y += v.z*v.x;
    v.z += v.x*v.y;
    v.w += v.y*v.z;
    return v;
}

float Pcg01(uint v) { return Pcg(v) / FLOAT_MAX; }
float2 Pcg01(uint2 v) { return Pcg2d(v) / FLOAT_MAX; }
float3 Pcg01(uint3 v) { return Pcg3d(v) / FLOAT_MAX; }
float4 Pcg01(uint4 v) { return Pcg4d(v) / FLOAT_MAX; }

float Pcg01(float v) { return Pcg01(asuint(v)); }
float2 Pcg01(float2 v) { return Pcg01(asuint(v)); }
float3 Pcg01(float3 v) { return Pcg01(asuint(v)); }
float4 Pcg01(float4 v) { return Pcg01(asuint(v)); }

#endif