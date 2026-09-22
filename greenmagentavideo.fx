// Anaglyph_Video.fx - UPDATED with realistic depth range
// Combines the best of both approaches

uniform float method <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.05;
    ui_label = "3D Method";
    ui_tooltip = "0.0 = Simple (best for text), 1.0 = Advanced (true 3D for video)";
> = 0.5;

uniform float depth <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.012;  // CRITICAL CHANGE: Max usable is about 1.2% of screen width
    ui_step = 0.0005;
    ui_label = "3D Depth";
    ui_tooltip = "WARNING: Values above 0.010 cause ghosting. Advanced method is very sensitive.";
> = 0.006; // Start in the safe middle

texture2D texColorBuffer : COLOR;
sampler2D sColorBuffer { Texture = texColorBuffer; };

struct VS_OUTPUT {
    float4 pos : SV_Position;
    float2 uv : TEXCOORD0;
};

VS_OUTPUT VS(uint id : SV_VertexID)
{
    VS_OUTPUT output;
    float2 texcoord = float2((id << 1) & 2, id & 2);
    output.pos = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);
    output.uv = texcoord;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    float2 uv = input.uv;
    float4 original = tex2D(sColorBuffer, uv);
    
    // Calculate luminance
    float luminance = dot(original.rgb, float3(0.299, 0.587, 0.114));
    
    // Calculate displacement with HARD SAFETY LIMIT
    float rawDisplace = (luminance - 0.5) * depth * 10.0;
    float displace = clamp(rawDisplace, -0.012, 0.012); // Physical limit
    
    // Create shifted UV
    float2 shiftedUV = uv;
    shiftedUV.x = clamp(uv.x + displace, 0.001, 0.999);
    float4 shifted = tex2D(sColorBuffer, shiftedUV);
    
    // --- METHOD BLENDING ---
    float3 result;
    
    if (method < 0.01) {
        // PURE SIMPLE METHOD (your original favorite)
        float shiftedLum = dot(shifted.rgb, float3(0.299, 0.587, 0.114));
        float edge = smoothstep(0.07, 0.2, abs(luminance - shiftedLum));
        float mixedGreen = lerp(shifted.g, original.g, edge * 0.9);
        result = float3(original.r, mixedGreen, original.b);
        
    } else if (method > 0.99) {
        // PURE ADVANCED METHOD (from JavaScript)
        // Note: This method ghosts easily - keep depth LOW
        float3 colLeftEye = original.rgb;
        float3 colRightEye = shifted.rgb;
        
        colLeftEye.g *= 0.8;
        colRightEye.r *= 0.8;
        colRightEye.b *= 0.8;
        
        result = float3(
            0.7 * colLeftEye.r + 0.3 * colLeftEye.b,
            colRightEye.g * 0.92, // Slightly reduced to help with green ghosting
            0.3 * colLeftEye.r + 0.7 * colLeftEye.b
        );
        
    } else {
        // HYBRID BLEND
        // Simple method result
        float shiftedLum = dot(shifted.rgb, float3(0.299, 0.587, 0.114));
        float edge = smoothstep(0.07, 0.2, abs(luminance - shiftedLum));
        float mixedGreen = lerp(shifted.g, original.g, edge * 0.9);
        float3 simpleResult = float3(original.r, mixedGreen, original.b);
        
        // Advanced method result
        float3 colLeftEye = original.rgb;
        float3 colRightEye = shifted.rgb;
        colLeftEye.g *= 0.8;
        colRightEye.r *= 0.8;
        colRightEye.b *= 0.8;
        float3 advancedResult = float3(
            0.7 * colLeftEye.r + 0.3 * colLeftEye.b,
            colRightEye.g * 0.92, // Reduced green contribution
            0.3 * colLeftEye.r + 0.7 * colLeftEye.b
        );
        
        // Blend based on method slider
        result = lerp(simpleResult, advancedResult, method);
    }
    
    // Optional vibrancy
    float lumResult = dot(result, float3(0.299, 0.587, 0.114));
    result = lerp(float3(lumResult, lumResult, lumResult), result, 1.15);
    
    return float4(saturate(result), original.a);
}

technique Anaglyph_Hybrid
{
    pass P0
    {
        VertexShader = VS;
        PixelShader = PS;
    }
}