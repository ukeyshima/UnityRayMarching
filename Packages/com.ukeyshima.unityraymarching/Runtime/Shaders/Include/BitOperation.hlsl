#ifndef BIT_OPERATION_INCLUDED
#define BIT_OPERATION_INCLUDED

float4 EncodeFloatRGBA(float v)
{
    float4 enc = float4(1.0, 255.0, 65025.0, 16581375.0) * v;
    enc = frac(enc);
    enc -= enc.yzww * float4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
    return enc;
}

float DecodeFloatRGBA(float4 rgba)
{
    return dot(rgba, float4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
}

#endif