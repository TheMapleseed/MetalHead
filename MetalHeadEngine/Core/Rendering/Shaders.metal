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

// MARK: - Deferred Rendering Structures
struct DeferredMaterial {
    float3 albedo;
    float roughness;
    float metallic;
};

struct DeferredLight {
    float3 position;
    float3 color;
    float intensity;
    float radius;
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
// Functional ray tracing implementation using compute shader
// This performs actual ray tracing with sphere and plane intersections
kernel void ray_generation(uint2 gid [[thread_position_in_grid]],
                          uint2 gSize [[threads_per_grid]],
                          texture2d<float, access::write> outputTexture [[texture(0)]],
                          constant float4x4& viewMatrix [[buffer(0)]],
                          constant float4x4& projectionMatrix [[buffer(1)]],
                          constant float& time [[buffer(2)]]) {
    if (gid.x >= gSize.x || gid.y >= gSize.y) {
        return;
    }
    
    // Generate ray from camera
    float2 uv = float2(float(gid.x) / float(gSize.x), float(gid.y) / float(gSize.y));
    uv = uv * 2.0 - 1.0; // Convert to NDC
    
    // Camera position and direction in view space
    float3 rayOrigin = float3(0.0, 0.0, 5.0);
    float3 rayDirection = normalize(float3(uv.x, uv.y, -1.0));
    
    // Transform ray to world space
    float4 worldOrigin = viewMatrix * float4(rayOrigin, 1.0);
    float4 worldDir = viewMatrix * float4(rayDirection, 0.0);
    rayOrigin = worldOrigin.xyz;
    rayDirection = normalize(worldDir.xyz);
    
    // Perform ray tracing with multiple objects
    float3 hitColor = float3(0.1, 0.1, 0.1); // Default background
    float minT = 1000.0;
    float3 hitNormal = float3(0.0, 1.0, 0.0);
    
    // Test ray-sphere intersection
    float3 sphereCenter = float3(0.0, 0.0, 0.0);
    float sphereRadius = 1.0;
    
    float3 oc = rayOrigin - sphereCenter;
    float a = dot(rayDirection, rayDirection);
    float b = 2.0 * dot(oc, rayDirection);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float discriminant = b * b - 4.0 * a * c;
    
    if (discriminant >= 0.0) {
        float t = (-b - sqrt(discriminant)) / (2.0 * a);
        if (t > 0.001 && t < minT) {
            minT = t;
            float3 hitPoint = rayOrigin + rayDirection * t;
            hitNormal = normalize(hitPoint - sphereCenter);
        }
    }
    
    // Test ray-plane intersection (ground plane)
    float3 planeNormal = float3(0.0, 1.0, 0.0);
    float planeD = 0.0;
    float denom = dot(rayDirection, planeNormal);
    if (abs(denom) > 0.001) {
        float t = -(dot(rayOrigin, planeNormal) + planeD) / denom;
        if (t > 0.001 && t < minT) {
            minT = t;
            hitNormal = planeNormal;
        }
    }
    
    // If we hit something, calculate lighting
    if (minT < 1000.0) {
        float3 hitPoint = rayOrigin + rayDirection * minT;
        
        // Simple lighting with multiple lights
        float3 lightDir1 = normalize(float3(1.0, 1.0, 1.0));
        float3 lightDir2 = normalize(float3(-1.0, 0.5, -1.0));
        
        float ndotl1 = max(0.0, dot(hitNormal, lightDir1));
        float ndotl2 = max(0.0, dot(hitNormal, lightDir2));
        
        // Color based on position, lighting, and time
        float3 baseColor = float3(0.5, 0.7, 1.0);
        float3 color = baseColor * (0.2 + 0.5 * ndotl1 + 0.3 * ndotl2);
        
        // Add distance-based fog
        float distance = length(hitPoint - rayOrigin);
        float fogFactor = 1.0 - min(1.0, distance / 50.0);
        hitColor = mix(float3(0.1, 0.1, 0.1), color, fogFactor);
    } else {
        // No hit - use gradient background with time-based animation
        hitColor = float3(
            uv.x * 0.1 + 0.1 + sin(time) * 0.05,
            uv.y * 0.1 + 0.1 + cos(time) * 0.05,
            0.15
        );
    }
    
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

// MARK: - Particle System Shader
// Note: This struct must match the Swift Particle struct layout exactly
struct ParticleData {
    packed_float3 position;  // SIMD3<Float> = 12 bytes
    float _padding1;          // Padding to align to 16 bytes
    packed_float3 velocity;   // SIMD3<Float> = 12 bytes
    float _padding2;          // Padding to align to 16 bytes
    float4 color;             // SIMD4<Float> = 16 bytes
    float lifetime;           // Float = 4 bytes
    float _padding3[3];       // Padding to align to 16 bytes
};

kernel void particle_update(device ParticleData* particles [[buffer(0)]],
                          constant float& deltaTime [[buffer(1)]],
                          uint gid [[thread_position_in_grid]]) {
    if (gid >= 1024) return; // Max particles
    
    device ParticleData& particle = particles[gid];
    
    // Update lifetime
    particle.lifetime -= deltaTime;
    
    // If particle is dead, reset it
    if (particle.lifetime <= 0.0) {
        particle.position = float3(0.0, 0.0, 0.0);
        particle.velocity = float3(
            (float(gid % 10) - 5.0) * 0.1,
            2.0 + float(gid % 5) * 0.2,
            (float(gid % 8) - 4.0) * 0.1
        );
        particle.lifetime = 5.0 + float(gid % 10) * 0.5;
        particle.color = float4(
            0.5 + float(gid % 3) * 0.2,
            0.5 + float((gid + 1) % 3) * 0.2,
            0.5 + float((gid + 2) % 3) * 0.2,
            1.0
        );
    } else {
        // Apply gravity
        particle.velocity.y -= 9.8 * deltaTime;
        
        // Update position
        particle.position += particle.velocity * deltaTime;
        
        // Fade out as lifetime decreases
        particle.color.a = particle.lifetime / 5.0;
    }
}

// MARK: - Deferred Rendering Shaders

// G-Buffer vertex shader (writes position, normal, albedo to textures)
vertex VertexOut gbuffer_vertex(Vertex in [[stage_in]],
                                constant Uniforms& uniforms [[buffer(1)]],
                                constant float4x4& modelMatrix [[buffer(2)]]) {
    VertexOut out;
    
    // Transform position to world space
    float4 worldPosition = modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    out.position = uniforms.projectionMatrix * viewPosition;
    
    // Pass through color as albedo
    out.color = in.color;
    
    // Calculate world position and normal
    out.worldPosition = worldPosition.xyz;
    out.normal = normalize((modelMatrix * float4(in.position, 0.0)).xyz);
    
    return out;
}

// G-Buffer fragment shader (outputs to multiple render targets)
struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
};

fragment GBufferOut gbuffer_fragment(VertexOut in [[stage_in]],
                                     constant DeferredMaterial& material [[buffer(0)]]) {
    GBufferOut out;
    
    // Output albedo
    out.albedo = float4(material.albedo, 1.0) * in.color;
    
    // Output normal (packed as RGBA16Float)
    out.normal = float4(normalize(in.normal) * 0.5 + 0.5, 1.0);
    
    return out;
}

// Lighting fragment shader (reads G-Buffer and computes lighting)
fragment float4 lighting_fragment(Vertex2DOut in [[stage_in]],
                                  texture2d<float> albedoTexture [[texture(0)]],
                                  texture2d<float> normalTexture [[texture(1)]],
                                  texture2d<float> depthTexture [[texture(2)]],
                                  constant uint& lightCount [[buffer(0)]],
                                  constant DeferredLight* lights [[buffer(1)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    // Sample G-Buffer
    float4 albedo = albedoTexture.sample(textureSampler, in.texCoord);
    float4 normalPacked = normalTexture.sample(textureSampler, in.texCoord);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;
    
    // Unpack normal from [0,1] range to [-1,1]
    float3 normal = normalize(normalPacked.rgb * 2.0 - 1.0);
    
    // Compute lighting
    float3 color = float3(0.1, 0.1, 0.1); // Ambient
    
    // Add light contributions
    for (uint i = 0; i < lightCount; i++) {
        DeferredLight light = lights[i];
        
        // Simple point light calculation
        float3 lightDir = normalize(light.position - float3(in.texCoord * 2.0 - 1.0, depth));
        float ndotl = max(0.0, dot(normal, lightDir));
        
        // Attenuation based on distance
        float distance = length(light.position - float3(in.texCoord * 2.0 - 1.0, depth));
        float attenuation = 1.0 / (1.0 + distance * distance / (light.radius * light.radius));
        
        color += light.color * light.intensity * ndotl * attenuation;
    }
    
    return float4(albedo.rgb * color, 1.0);
}

// MARK: - Intersection Functions (Metal 4)
// Note: For Metal 4, triangle intersections are handled automatically by the system
// Custom intersection functions are only needed for non-triangle primitives
// Since we're using triangle geometry primarily, we'll rely on Metal's built-in intersection

// Custom intersection functions would be implemented here if needed for procedural geometry
// For now, we rely on Metal's automatic triangle intersection handling
