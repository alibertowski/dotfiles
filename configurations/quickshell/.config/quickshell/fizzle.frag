#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fizzleAmount;
    float time;
};

layout(binding = 1) uniform sampler2D source;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// 1. Create a jittering horizontal offset
void main() {
    highp vec2 uv = qt_TexCoord0;
    // This creates the "torn" look seen in the anime's transitions
    highp float jitter = (random(vec2(floor(uv.y * 100.0), time)) - 0.5) * fizzleAmount;

    // 2. Sample the texture with the jitter
    highp vec4 tex = texture(source, uv + vec2(jitter, 0.02));

    // 3. Add the "Lain" Static (from our previous step)
    highp float n = random(uv + floor(time * 12.0));

    // 4. Create the CRT Scanlines
    // This creates a dark line every few pixels vertically
    highp float scanline = sin(uv.y * 900.0 + time * 1.5) * 0.001;

    // Combine everything
    highp vec3 finalColor = tex.rgb + (n * 0.02); // Add a little static
    finalColor -= scanline; // Subtract the scanline darkness

    // Make the colors slightly "blown out" like a bright CRT
    fragColor = vec4(finalColor, tex.a) * qt_Opacity;
}
