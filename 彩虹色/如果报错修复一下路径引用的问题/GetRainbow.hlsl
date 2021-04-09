#ifndef RAINBOW
#define RAINBOW
#include "Assets/Shaders/Zucconi.hlsl"
void GetRainbow_float(float u, float d, out float3 color){


    for (int n = 1; n <= 8; n++)
    {
        float wavelength = u * d / n;
        color += spectral_zucconi(wavelength);
    }
}

#endif