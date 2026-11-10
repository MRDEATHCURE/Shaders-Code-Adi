
Shader "Custom/ToonShader"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Texture", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)

        [Header(Toon Lighting)]
        _ShadowColor ("Shadow Color", Color) = (0.25,0.25,0.35,1)
        _MidColor ("Midtone Color", Color) = (0.7,0.7,0.7,1)
        _HighlightColor ("Highlight Color", Color) = (1,1,1,1)

        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.35
        _HighlightThreshold ("Highlight Threshold", Range(0,1)) = 0.75
        _BandSmoothness ("Band Smoothness", Range(0.001,0.3)) = 0.01

        [Header(Rim Lighting)]
        _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower ("Rim Power", Range(0.5,10)) = 4
        _RimIntensity ("Rim Intensity", Range(0,3)) = 0.3
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        LOD 200
        Cull Back
        ZWrite On

        // ========================================
        // MAIN TOON LIGHTING PASS
        // ========================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half4 _MidColor;
                half4 _HighlightColor;
                half _ShadowThreshold;
                half _HighlightThreshold;
                half _BandSmoothness;
                half4 _RimColor;
                half _RimPower;
                half _RimIntensity;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionWS =
                    TransformObjectToWorld(IN.positionOS.xyz);

                OUT.positionCS =
                    TransformWorldToHClip(OUT.positionWS);

                OUT.normalWS =
                    TransformObjectToWorldNormal(IN.normalOS);

                OUT.uv =
                    TRANSFORM_TEX(IN.uv, _BaseMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(
                    _BaseMap,
                    sampler_BaseMap,
                    IN.uv
                );

                half4 albedo = texColor * _BaseColor;

                half3 normalWS = normalize(IN.normalWS);

                // Main light and shadow coordinates
                float4 shadowCoord =
                    TransformWorldToShadowCoord(IN.positionWS);

                Light mainLight = GetMainLight(shadowCoord);

                half3 lightDir = normalize(mainLight.direction);

                half NdotL = saturate(
                    dot(normalWS, lightDir)
                );

                half lighting =
                    NdotL * mainLight.shadowAttenuation;

                // Toon bands
                half smoothness = max(
                    _BandSmoothness,
                    0.001
                );

                half midBand = smoothstep(
                    _ShadowThreshold - smoothness,
                    _ShadowThreshold + smoothness,
                    lighting
                );

                half brightBand = smoothstep(
                    _HighlightThreshold - smoothness,
                    _HighlightThreshold + smoothness,
                    lighting
                );

                half3 toonColor = lerp(
                    _ShadowColor.rgb,
                    _MidColor.rgb,
                    midBand
                );

                toonColor = lerp(
                    toonColor,
                    _HighlightColor.rgb,
                    brightBand
                );

                toonColor *= mainLight.color;

                half3 finalColor = albedo.rgb * toonColor;

                // Fresnel rim light
                half3 viewDir = normalize(
                    GetWorldSpaceViewDir(IN.positionWS)
                );

                half fresnel = 1.0 - saturate(
                    dot(normalWS, viewDir)
                );

                half rim = pow(fresnel, _RimPower);

                finalColor +=
                    _RimColor.rgb * rim * _RimIntensity;

                return half4(finalColor, albedo.a);
            }

            ENDHLSL
        }

        // ========================================
        // CUSTOM SHADOW CASTER PASS
        // ========================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM

            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma target 3.0

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryings ShadowVert(ShadowAttributes IN)
            {
                ShadowVaryings OUT;

                float3 positionWS =
                    TransformObjectToWorld(IN.positionOS.xyz);

                float3 normalWS =
                    TransformObjectToWorldNormal(IN.normalOS);

                float3 lightDirectionWS;

                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    lightDirectionWS = normalize(
                        _LightPosition - positionWS
                    );
                #else
                    lightDirectionWS = _LightDirection;
                #endif

                float3 biasedPositionWS = ApplyShadowBias(
                    positionWS,
                    normalWS,
                    lightDirectionWS
                );

                float4 positionCS =
                    TransformWorldToHClip(biasedPositionWS);

                // Clamp to near clipping plane
                #if UNITY_REVERSED_Z
                    positionCS.z = min(
                        positionCS.z,
                        positionCS.w * UNITY_NEAR_CLIP_VALUE
                    );
                #else
                    positionCS.z = max(
                        positionCS.z,
                        positionCS.w * UNITY_NEAR_CLIP_VALUE
                    );
                #endif

                OUT.positionCS = positionCS;

                return OUT;
            }

            half4 ShadowFrag(ShadowVaryings IN) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }

        // ========================================
        // CUSTOM DEPTH ONLY PASS
        // ========================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM

            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct DepthAttributes
            {
                float4 positionOS : POSITION;
            };

            struct DepthVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            DepthVaryings DepthVert(DepthAttributes IN)
            {
                DepthVaryings OUT;

                OUT.positionCS =
                    TransformObjectToHClip(IN.positionOS.xyz);

                return OUT;
            }

            half4 DepthFrag(DepthVaryings IN) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
