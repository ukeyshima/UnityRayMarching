#ifndef COMMON_INCLUDED
#define COMMON_INCLUDED

#ifndef EPS
#define EPS 0.005
#endif
#define FLOAT_MAX float(0xffffffffu)
#define MOD(A, B) (A - B * floor(A / B))
#define MIN2(A) (min(A.x, A.y))
#define MIN3(A) (min(A.x, min(A.y, A.z)))
#define CROSS(X, Y) float3(X.y*Y.z - X.z*Y.y, X.z*Y.x - X.x*Y.z, X.x*Y.y - X.y*Y.x)
#define SATURATE(A) clamp(A, 0.0, 1.0)
#define PI (3.14159265359)
#define TAU (6.28318530718)

#define OO float2(0.0, 0.0)
#define IO float2(1.0, 0.0)
#define OI float2(0.0, 1.0)
#define II float2(1.0, 1.0)
#define JO float2(-1.0, 0.0)
#define OJ float2(0.0, -1.0)
#define JJ float2(-1.0, -1.0)
#define IJ float2(1.0, -1.0)
#define JI float2(-1.0, 1.0)

#define OOO float3(0.0, 0.0, 0.0)
#define OOI float3(0.0, 0.0, 1.0)
#define OOJ float3(0.0, 0.0, -1.0)
#define OIO float3(0.0, 1.0, 0.0)
#define OII float3(0.0, 1.0, 1.0)
#define OIJ float3(0.0, 1.0, -1.0)
#define OJO float3(0.0, -1.0, 0.0)
#define OJI float3(0.0, -1.0, 1.0)
#define OJJ float3(0.0, -1.0, -1.0)

#define IOO float3(1.0, 0.0, 0.0)
#define IOI float3(1.0, 0.0, 1.0)
#define IOJ float3(1.0, 0.0, -1.0)
#define IIO float3(1.0, 1.0, 0.0)
#define III float3(1.0, 1.0, 1.0)
#define IIJ float3(1.0, 1.0, -1.0)
#define IJO float3(1.0, -1.0, 0.0)
#define IJI float3(1.0, -1.0, 1.0)
#define IJJ float3(1.0, -1.0, -1.0)

#define JOO float3(-1.0, 0.0, 0.0)
#define JOI float3(-1.0, 0.0, 1.0)
#define JOJ float3(-1.0, 0.0, -1.0)
#define JIO float3(-1.0, 1.0, 0.0)
#define JII float3(-1.0, 1.0, 1.0)
#define JIJ float3(-1.0, 1.0, -1.0)
#define JJO float3(-1.0, -1.0, 0.0)
#define JJI float3(-1.0, -1.0, 1.0)
#define JJJ float3(-1.0, -1.0, -1.0)

#endif