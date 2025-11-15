#include <metal_stdlib>
using namespace metal;
using namespace metal::raytracing;

// Metal 4 Ray Tracing Support
#pragma metal ray_tracing

// MARK: - Data Structures
struct Vertex {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float time;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float3 worldPosition;
    float3 normal;
};

// MARK: - Vertex Shader
vertex VertexOut vertex_main(Vertex in [[stage_in]],
                           constant Uniforms& uniforms [[buffer(1)]],
                           constant float4x4& modelMatrix [[buffer(2)]]) {
    VertexOut out;
    
    // Transform position to world space using per-object model matrix
    float4 worldPosition = modelMatrix * float4(in.position, 1.0);
    
    // Transform to view space
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    
    // Transform to clip space
    out.position = uniforms.projectionMatrix * viewPosition;
    
    // Pass through color
    out.color = in.color;
    
    // Pass world position for lighting calculations
    out.worldPosition = worldPosition.xyz;
    
    // Calculate normal (simplified for cube)
    out.normal = normalize((modelMatrix * float4(in.position, 0.0)).xyz);
    
    return out;
}

// MARK: - Fragment Shader
fragment float4 fragment_main(VertexOut in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    // Simple lighting calculation
    float3 lightDirection = normalize(float3(1.0, 1.0, 1.0));
    float3 normal = normalize(in.normal);
    
    // Ambient lighting - increased for better visibility
    float ambient = 0.5;
    
    // Diffuse lighting
    float diffuse = max(dot(normal, lightDirection), 0.0);
    
    // Combine lighting - ensure minimum brightness
    float lighting = max(ambient + diffuse, 0.6);
    
    // Apply time-based color variation (reduced effect)
    float timeVariation = sin(uniforms.time * 2.0) * 0.05 + 0.95;
    
    // Final color - ensure objects are bright and visible
    float4 finalColor = in.color * lighting * timeVariation;
    
    // Clamp to ensure visibility (minimum 0.3 brightness)
    finalColor.rgb = max(finalColor.rgb, float3(0.3, 0.3, 0.3));
    
    return finalColor;
}

// MARK: - Compute Shader for Advanced Effects
kernel void compute_main(device float* data [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]],
                        uint2 gSize [[threads_per_grid]]) {
    if (gid.x >= gSize.x || gid.y >= gSize.y) {
        return;
    }
    
    uint index = gid.y * gSize.x + gid.x;
    
    // Perform some computation (e.g., particle simulation, audio visualization)
    data[index] = sin(float(gid.x) * 0.01) * cos(float(gid.y) * 0.01);
}

// MARK: - 2D Graphics Shaders
struct Vertex2D {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct Vertex2DOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex Vertex2DOut vertex_2d_main(Vertex2D in [[stage_in]]) {
    Vertex2DOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    return out;
}

fragment float4 fragment_2d_main(Vertex2DOut in [[stage_in]],
                                texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    if (texture.get_width() > 0) {
        float4 textureColor = texture.sample(textureSampler, in.texCoord);
        return textureColor * in.color;
    } else {
        return in.color;
    }
}

// MARK: - Audio Visualization Shader
kernel void audio_visualization(device float* audioData [[buffer(0)]],
                               texture2d<float, access::write> outputTexture [[texture(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Sample audio data for visualization
    uint audioIndex = (gid.x * outputTexture.get_height() + gid.y) % 1024;
    float audioValue = audioData[audioIndex];
    
    // Create visualization pattern
    float intensity = abs(audioValue);
    float4 color = float4(intensity, intensity * 0.5, intensity * 0.2, 1.0);
    
    outputTexture.write(color, gid);
}

// MARK: - Post-Processing Shader
fragment float4 post_process_main(Vertex2DOut in [[stage_in]],
                                 texture2d<float> inputTexture [[texture(0)]],
                                 constant float& time [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = inputTexture.sample(textureSampler, in.texCoord);
    
    // Apply some post-processing effects
    float2 uv = in.texCoord;
    
    // Chromatic aberration
    float2 offset = float2(sin(time * 2.0) * 0.01, cos(time * 2.0) * 0.01);
    float4 r = inputTexture.sample(textureSampler, uv + offset);
    float4 b = inputTexture.sample(textureSampler, uv - offset);
    
    color = float4(r.r, color.g, b.b, color.a);
    
    // Vignette effect
    float2 center = float2(0.5, 0.5);
    float distance = length(uv - center);
    float vignette = 1.0 - smoothstep(0.3, 0.8, distance);
    
    color *= vignette;
    
    return color;
}

// MARK: - Ray Tracing Structures

struct RayPayload {
    float3 color;
    float distance;
    uint bounceCount;
};

// MARK: - Ray Generation Shader (Metal 4)
[[ray_generation]]
void ray_generation(uint2 gid [[thread_position_in_grid]],
                   uint2 gSize [[threads_per_grid]],
                   acceleration_structure<> accelStructure [[buffer(0)]],
                   intersection_function_table<> intersectionTable [[buffer(1)]],
                   texture2d<float, access::write> outputTexture [[texture(0)]]) {
    if (gid.x >= gSize.x || gid.y >= gSize.y) {
        return;
    }
    
    // Generate ray from camera
    float2 uv = float2(float(gid.x) / float(gSize.x), float(gid.y) / float(gSize.y));
    uv = uv * 2.0 - 1.0; // Convert to NDC
    
    // TODO: Implement proper Metal 4 ray tracing API
    // The exact API for intersection_query needs to be verified against Metal 4 documentation
    // For now, using a simple placeholder that outputs a gradient
    float3 hitColor = float3(uv.x * 0.5 + 0.5, uv.y * 0.5 + 0.5, 0.5);
    outputTexture.write(float4(hitColor, 1.0), gid);
}

// MARK: - Legacy Compute Kernel (Fallback)
kernel void raytracing_kernel(device float* rayData [[buffer(0)]],
                              device float* outputData [[buffer(1)]],
                              constant float4x4& viewMatrix [[buffer(2)]],
                              constant float4x4& projectionMatrix [[buffer(3)]],
                              uint2 gid [[thread_position_in_grid]],
                              uint2 gSize [[threads_per_grid]]) {
    if (gid.x >= gSize.x || gid.y >= gSize.y) {
        return;
    }
    
    uint index = gid.y * gSize.x + gid.x;
    
    // Ray generation
    float2 uv = float2(float(gid.x) / float(gSize.x), float(gid.y) / float(gSize.y));
    uv = uv * 2.0 - 1.0; // Convert to NDC
    
    // Create ray from camera
    float4 rayOrigin = float4(0.0, 0.0, 0.0, 1.0);
    float4 rayDirection = float4(uv.x, uv.y, -1.0, 0.0);
    
    // Transform ray to world space
    rayOrigin = viewMatrix * rayOrigin;
    float4 transformedDir = viewMatrix * rayDirection;
    rayDirection = float4(normalize(transformedDir.xyz), 0.0);
    
    // Simple ray tracing computation (fallback implementation)
    float3 pos = rayOrigin.xyz + rayDirection.xyz * 5.0;
    float dist = length(pos);
    
    // Output result
    outputData[index * 3 + 0] = dist * 0.1; // R
    outputData[index * 3 + 1] = dist * 0.1; // G
    outputData[index * 3 + 2] = dist * 0.1; // B
}

// MARK: - Intersection Functions (Metal 4)
// Note: For Metal 4, triangle intersections are handled automatically by the system
// Custom intersection functions are only needed for non-triangle primitives
// Since we're using triangle geometry primarily, we'll rely on Metal's built-in intersection

// Custom intersection functions would be implemented here if needed for procedural geometry
// For now, we rely on Metal's automatic triangle intersection handling
