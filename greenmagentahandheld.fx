// Anaglyph_LegionGo.fx
// SPECIALLY TUNED FOR HIGH-PPI HANDHELDS (Legion Go, Steam Deck, ROG Ally)
// Unlocked depth limits to force "Pop" on small screens.

uniform float depth <
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 3.0;  // CHANGED: Increased max from 0.5 to 3.0 for handhelds
    ui_step = 0.01;
    ui_label = "3D Strength";
    ui_tooltip = "Crank this up! Handhelds need higher values.";
> = 1.0;

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
    float luminance = 0.5 + (rawLum - 0.5) * 1.3; 
    
    // NON-LINEAR displacement
    float shapedDepth = (luminance - 0.5);
    shapedDepth = shapedDepth * (1.0 + abs(shapedDepth) * 2.5); // Slightly steeper curve for small screens
    
    // LEGION GO FIX: Increased multiplier from 0.03 to 0.08
    // This forces the pixels to move further apart physically
    float displace = shapedDepth * depth * 0.08; 
    
    // LEGION GO FIX: Widen the hard clamp. 
    // Old limit was 0.015, new is 0.08 (allows 8% screen shift)
    displace = clamp(displace, -0.08, 0.08);
    
    float2 shiftedUV = uv;
    shiftedUV.x = clamp(uv.x + displace, 0.001, 0.999);
    float4 shifted = tex2D(sColorBuffer, shiftedUV);
    
    // Calculate edge detection
    float shiftedLum = dot(shifted.rgb, float3(0.299, 0.587, 0.114));
    
    // Widen edge detection slightly to account for the larger gap
    float edge = smoothstep(0.05, 0.25, abs(rawLum - shiftedLum));
    
    // GREEN CONTROL
    float greenMix = lerp(shifted.g, original.g, edge * 0.95);
    greenMix *= greenControl; 
    
    // Final color with vibrancy boost
    float3 result = float3(original.r * 1.1, greenMix, original.b * 1.05);
    
    // Smart saturation boost
    float lumResult = dot(result, float3(0.299, 0.587, 0.114));
    result = lerp(float3(lumResult, lumResult, lumResult), result, 1.3); // Bumped sat slightly for small screen
    
    return float4(saturate(result), original.a);
}

technique Anaglyph_LegionGo
{
    pass P0
    {
        VertexShader = VS;
        PixelShader = PS;
    }
}