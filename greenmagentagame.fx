// Anaglyph_Game.fx
// Based on your original favorite, but optimized to prevent ghosting

uniform float depth <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 0.5;  // Larger range but uses different math
    ui_step = 0.01;
    ui_label = "3D Strength";
> = 0.15;

uniform float greenControl <
    ui_type = "slider";
    ui_min = 0.3;
    ui_max = 1.2;
    ui_step = 0.05;
    ui_label = "Green Control";
    ui_tooltip = "Lower = less ghosting, higher = stronger 3D";
> = 0.7;

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
    
    // Calculate luminance with contrast enhancement
    float rawLum = dot(original.rgb, float3(0.299, 0.587, 0.114));
    float luminance = 0.5 + (rawLum - 0.5) * 1.3;  // Boost contrast
    
    // NON-LINEAR displacement: Stronger response without huge shifts
    float shapedDepth = (luminance - 0.5);
    shapedDepth = shapedDepth * (1.0 + abs(shapedDepth) * 2.0);  // Curve
    float displace = shapedDepth * depth * 0.03;  // Small multiplier
    
    // HARD LIMIT: Never exceed safe range
    displace = clamp(displace, -0.015, 0.015);
    
    float2 shiftedUV = uv;
    shiftedUV.x = clamp(uv.x + displace, 0.001, 0.999);
    float4 shifted = tex2D(sColorBuffer, shiftedUV);
    
    // Calculate edge detection
    float shiftedLum = dot(shifted.rgb, float3(0.299, 0.587, 0.114));
    float edge = smoothstep(0.05, 0.18, abs(rawLum - shiftedLum));
    
    // GREEN CONTROL: The key to reducing ghosting
    float greenMix = lerp(shifted.g, original.g, edge * 0.95);
    greenMix *= greenControl;  // Apply user control
    
    // Final color with vibrancy boost
    float3 result = float3(original.r * 1.1, greenMix, original.b * 1.05);
    
    // Smart saturation boost (preserves 3D)
    float lumResult = dot(result, float3(0.299, 0.587, 0.114));
    result = lerp(float3(lumResult, lumResult, lumResult), result, 1.25);
    
    return float4(saturate(result), original.a);
}

technique Anaglyph_Ghostbuster
{
    pass P0
    {
        VertexShader = VS;
        PixelShader = PS;
    }
}