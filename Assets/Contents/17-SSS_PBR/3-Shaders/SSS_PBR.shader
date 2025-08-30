Shader "Custom/17-SSS_PBR/SSS_PBR"
{
  Properties
  {
    [Enum(Off, 0, Front, 1, Back, 2)]_Cull ("Cull Mode", Float) = 2
    _MainTex ("Main Texture", 2D) = "white" { }
    _MainColor ("Main Color", Color) = (1, 1, 1, 1)
    [Toggle(ALPHATEST_ON)]_AlphaClip ("Alpha Clip", Float) = 0
    _Cutoff ("Alpha Clip Threshold", Range(0, 1)) = 0.5
    [Toggle(_NORMALMAP)]_NormalMapToggle ("Use Normal Map", Float) = 0
    [NoScaleOffset]_BumpMap ("Normal Map", 2D) = "bump" { }
    [Toggle(_EMISSION)]_EmissionToggle ("Use Emission", Float) = 0
    [HDR]_EmissionColor ("Emission Color", Color) = (0, 0, 0, 0)
    [NoScaleOffset]_EmissionMap ("Emission Map", 2D) = "white" { }
    [Toggle(_SPECULAR_SETUP)] _MetallicSpecToggle ("Is Specular Workflow", Float) = 0

    [Toggle(_METALLICSPECGLOSSMAP)]_MetallicSpecularMapToggle ("Use Metallic/Specular Map", Float) = 0
    [NoScaleOffset]_MetallicSpecularMap ("Metallic/Specular Map", 2D) = "white" { }
    _Metallic ("Metallic", Range(0, 1)) = 0
    _SpecualrColor ("Specualr Color", Color) = (0.5, 0.5, 0.5, 0.5)
    _SmoothnessGlossiness ("Smoothness/Glossiness", Range(0, 1)) = 0
    [Toggle(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A))]_SmoothnessGlossinessSource ("Smoothness/Glossiness From Base Alpha", Float) = 0

    [Toggle(_OCCLUSIONMAP)] _OcclusionToggle ("Use Occlusion Map", Float) = 0
    [NoScaleOffset]_OcclusionMap ("Occlusion Map", 2D) = "white" { }
    _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1

    [Toggle(_SPECULARHIGHLIGHTS_OFF)]_SpecularHighlights ("Specular Highlights Off", Float) = 0
    [Toggle(_ENVIRONMENTREFLECTIONS_OFF)]_EnvironmentReflections ("Environment Reflections Off", Float) = 0
    [Toggle(_RECEIVE_SHADOWS_OFF)]_ReceiveShadows ("Receive Shadows Off", Float) = 0

    [Header(SSS)]

    [Toggle(_SSS_ON)]_SSS_Switch ("次表面漫反射开关", Float) = 1
    [NoScaleOffset]_ThicknessMap ("厚度贴图", 2D) = "white" { }
    _ThicknessFactor ("厚度贴图系数", Range(0, 1)) = 1
    [HDR]_SSColor ("次表面颜色", Color) = (1, 1, 1, 1)
    _DistortionFactor ("背光法线扰动系数", Range(0, 1)) = 1
    _BackPower ("背光集中度", Range(1, 4)) = 1
    _BackStrength ("背光强度", Range(1, 4)) = 1
    _FrontStrength ("正面通透强度", Range(0, 4)) = 1
    _BackAmbient ("背光环境光强度", Range(0, 4)) = 0
  }

  SubShader
  {
    LOD 200

    Tags
    {
      "Queue" = "Geometry"
      "RenderPipeline" = "UniversalPipeline"
    }

    Cull [_Cull]
    ZTest LEqual
    ZWrite On

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

    #include "Assets/Contents/01-WriteShader/3-Shaders/pbr.hlsl"

    #include "Assets/Contents/13-CDRom/3-Shaders/spectral.hlsl"

    CBUFFER_START(UnityPerMaterial)

      TEXTURE2D(_MainTex);
      float4 _MainTex_ST;
      SamplerState NewRepeatPointSampler;

      float4 _MainColor;

      float _Cutoff;

      float4 _EmissionColor;

      float _Metallic;
      float4 _SpecualrColor;
      float _SmoothnessGlossiness;

      TEXTURE2D(_MetallicSpecularMap);
      SAMPLER(sampler_MetallicSpecularMap);

      TEXTURE2D(_OcclusionMap);
      SAMPLER(sampler_OcclusionMap);
      float _OcclusionStrength;

      float _Distance;
      float _ColorAlpha;
      float _Length;


      TEXTURE2D(_ThicknessMap);
      SAMPLER(sampler_ThicknessMap);
      real _ThicknessFactor;
      real3 _SSColor;
      real _DistortionFactor;
      real _BackPower;
      real _BackStrength;
      real _BackAmbient;
      real _FrontStrength;

    CBUFFER_END

    ENDHLSL

    pass
    {
      Name "ForwardLit"

      Tags
      {
        "LightMode" = "UniversalForward"
      }

      HLSLPROGRAM

      #pragma shader_feature _SSS_ON

      #pragma shader_feature ALPHATEST_ON
      #pragma shader_feature _NORMALMAP
      #pragma shader_feature _EMISSION

      #pragma shader_feature _SPECULAR_SETUP
      #pragma shader_feature _METALLICSPECGLOSSMAP
      #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
      #pragma shader_feature _OCCLUSIONMAP

      #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
      #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
      #pragma shader_feature_local_fragment _RECEIVE_SHADOWS_OFF

      #pragma multi_compile _MAIN_LIGHT_SHADOWS
      #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
      #pragma multi_compile _ADDITIONAL_LIGHTS
      #pragma multi_compile _ADDITIONAL_LIGHT_SHADOWS
      #pragma multi_compile_fog



      #pragma vertex vert
      #pragma fragment frag

      struct appdata
      {
        float4 posOS : POSITION;
        float4 normalOS : NORMAL;
        
        #ifdef _NORMALMAP
          float4 tangentOS : TANGENT;
        #endif
        
        float2 uv : TEXCOORD0;
        float2 lightmapUV : TEXCOORD1;
        float4 color : COLOR;
      };

      struct v2f
      {
        float4 posCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

        float3 posWS : TEXCOORD2;

        // #ifdef _NORMALMAP
        //   // ! _NORMALMAP ON viewDir float3(normalWS.x,tangentWS.y,bitangentWS.z)
        
        // #else
        //   float3 normalWS : TEXCOORD3;
        // #endif

        float4 normalWS : TEXCOORD3;
        float4 tangentWS : TEXCOORD4;
        float4 bitangentWS : TEXCOORD5;

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
          float4 fogFactorAndVertexLight : TEXCOORD6;
        #else
          float fogFactor : TEXCOORD6;
        #endif

        #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
          float4 shadowCoord : TEXCOORD7;
        #endif

        float4 color : COLOR;
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;

        VertexPositionInputs posInputs = GetVertexPositionInputs(v.posOS.xyz);

        o.posCS = posInputs.positionCS;
        o.posWS = posInputs.positionWS;

        float3 viewDir = GetWorldSpaceViewDir(posInputs.positionWS);

        #ifdef _NORMALMAP
          VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz, v.tangentOS);

          o.normalWS = float4(normalInputs.normalWS, viewDir.x);
          o.tangentWS = float4(normalInputs.tangentWS, viewDir.y);
          o.bitangentWS = float4(normalInputs.bitangentWS, viewDir.z);
        #else
          VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);

          o.normalWS = float4(NormalizeNormalPerVertex(normalInputs.normalWS), 1);
        #endif


        float fogFactor = ComputeFogFactor(posInputs.positionCS.z);
        float3 vertexLight = VertexLighting(posInputs.positionWS, normalInputs.normalWS);

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
          o.fogFactorAndVertexLight = float4(fogFactor, vertexLight);
        #else
          o.fogFactor = fogFactor;
        #endif

        #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
          o.shadowCoord = GetShadowCoord(posInputs);
        #endif

        OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
        OUTPUT_SH(o.normalWS, o.vertexSH);

        o.uv = TRANSFORM_TEX(v.uv, _MainTex);
        o.color = v.color;

        return o;
      }

      half SampleOcclusion(float2 uv)
      {
        #ifdef _OCCLUSIONMAP
          #ifdef SHADER_API_GLES
            return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
          #else
            half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            return LerpWhiteTo(occ, _OcclusionStrength);
          #endif
        #else
          return 1;
        #endif
      }

      half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
      {
        half4 specGloss;
        #ifdef _METALLICSPECGLOSSMAP
          specGloss = SAMPLE_TEXTURE2D(_MetallicSpecularMap, sampler_MetallicSpecularMap, uv);

          #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _SmoothnessGlossiness;
          #else
            specGloss.a *= _SmoothnessGlossiness;
          #endif
        #else
          #if _SPECULAR_SETUP
            specGloss.rgb = _SpecualrColor.rgb;
          #else
            specGloss.rgb = _Metallic.rrr;
          #endif
          #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _SmoothnessGlossiness;
          #else
            specGloss.a = _SmoothnessGlossiness;
          #endif
        #endif
        return specGloss;
      }

      void InitSurfaceData(v2f i, out SurfaceData surfaceData)
      {
        surfaceData = (SurfaceData)0;

        half4 albedoAlpha = SampleAlbedoAlpha(i.uv, _MainTex, NewRepeatPointSampler);
        float3 diffuse = albedoAlpha.rgb * _MainColor.rgb * i.color.rgb;
        surfaceData.albedo = diffuse.rgb;
        surfaceData.alpha = Alpha(albedoAlpha.a, _MainColor, _Cutoff);

        surfaceData.normalTS = SampleNormal(i.uv, _BumpMap, sampler_BumpMap);

        surfaceData.emission = SampleEmission(i.uv, _EmissionColor.rgb, _EmissionMap, sampler_EmissionMap);

        surfaceData.occlusion = SampleOcclusion(i.uv);

        half4 specGloss = SampleMetallicSpecGloss(i.uv, albedoAlpha.a);
        #ifdef _SPECULAR_SETUP
          surfaceData.metallic = 0;
          surfaceData.specular = specGloss.rgb;
        #else
          surfaceData.metallic = specGloss.r ;
          surfaceData.specular = half3(0, 0, 0);
        #endif

        surfaceData.smoothness = specGloss.a;
      }

      void InitInputData(v2f i, float3 noramlTS, out InputData inputData)
      {
        inputData = (InputData)0;

        inputData.positionWS = i.posWS;
        inputData.positionCS = i.posCS;

        #ifdef _NORMALMAP
          float3x3 tangentToWorld = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalWS.xyz);
          inputData.normalWS = TransformTangentToWorld(noramlTS, tangentToWorld);
          inputData.tangentToWorld = tangentToWorld;

          float3 viewDirWS = float3(i.normalWS.w, i.tangentWS.w, i.bitangentWS.w);
        #else
          inputData.normalWS = i.normalWS;

          float3 viewDirWS = GetWorldSpaceViewDir(i.posWS);
        #endif

        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = SafeNormalize(viewDirWS);

        #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
          inputData.shadowCoord = i.shadowCoord;
        #elif defined(MAIN_LIGHT_CALCULATE_SHADOW)
          inputData.shadowCoord = TransformWorldToShadowCoord(i.posWS);
        #else
          inputData.shadowCoord = float4(0, 0, 0, 0);
        #endif

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
          inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
          inputData.fogCoord = i.fogFactorAndVertexLight.x;
        #else
          inputData.vertexLighting = half3(0, 0, 0);
          inputData.fogCoord = i.fogFactor.x;
        #endif

        inputData.bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.posCS);

        inputData.shadowMask = SAMPLE_SHADOWMASK(i.lightmapUV);
      }


      real3 SSS(Light light, real3 N, real3 V, real thickness)
      {
        real3 L = light.direction;
        real3 LN = normalize(L + N * _DistortionFactor);
        
        real sss = pow(saturate(dot(V, -LN)), _BackPower) * _BackStrength + _BackAmbient;
        real sssF = pow(saturate(dot(V, LN)), _BackPower) * _FrontStrength + _BackAmbient;
        sss += sssF;
        
        sss *= thickness;

        return sss * _SSColor * light.color * light.distanceAttenuation * light.shadowAttenuation;
      }

      half4 UniversalFragmentPBR_SSS(InputData inputData, SurfaceData surfaceData)
      {
        // ! SPECULAR高光
        #if defined(_SPECULARHIGHLIGHTS_OFF)
          bool specularHighlightsOff = true;
        #else
          bool specularHighlightsOff = false;
        #endif

        // ! 漫反射和镜面反射颜色
        BRDFData brdfData;

        // NOTE: can modify "surfaceData"...
        InitializeBRDFData(surfaceData, brdfData);

        // ! DEBUG
        #if defined(DEBUG_DISPLAY)
          half4 debugColor;

          if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
          {
            return debugColor;
          }
        #endif

        // ! 车漆效果
        // Clear-coat calculation...
        BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
        
        half4 shadowMask = CalculateShadowMask(inputData);
        
        // ! AO
        AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        uint meshRenderingLayers = GetMeshRenderingLayer();

        // ! 主灯
        Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

        // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

        LightingData lightingData = CreateLightingData(inputData, surfaceData);

        lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
        inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
        inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
        #ifdef _LIGHT_LAYERS
          if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
        {
          lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,
          mainLight,
          inputData.normalWS, inputData.viewDirectionWS,
          surfaceData.clearCoatMask, specularHighlightsOff);
        }

        // ! 额外灯
        #if defined(_ADDITIONAL_LIGHTS)
          uint pixelLightCount = GetAdditionalLightsCount();

          #if USE_FORWARD_PLUS
            for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
            {
              FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

              Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

              #ifdef _LIGHT_LAYERS
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
              #endif
              {
                lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                inputData.normalWS, inputData.viewDirectionWS,
                surfaceData.clearCoatMask, specularHighlightsOff);
              }
            }
          #endif

          LIGHT_LOOP_BEGIN(pixelLightCount)
          Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

          #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
          #endif
          {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
            inputData.normalWS, inputData.viewDirectionWS,
            surfaceData.clearCoatMask, specularHighlightsOff);
          }
          LIGHT_LOOP_END
        #endif

        #if defined(_ADDITIONAL_LIGHTS_VERTEX)
          lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
        #endif

        

        #if REAL_IS_HALF
          // Clamp any half.inf+ to HALF_MAX
          return min(CalculateFinalColor(lightingData, surfaceData.alpha), HALF_MAX);
        #else
          return CalculateFinalColor(lightingData, surfaceData.alpha);
        #endif
      }

      float4 frag(v2f i) : SV_TARGET
      {
        SurfaceData surfaceData;
        InitSurfaceData(i, surfaceData);

        InputData inputData;
        InitInputData(i, surfaceData.normalTS, inputData);

        // ! PBR Color
        float3 color = UniversalFragmentPBR_SSS(inputData, surfaceData).rgb;

        #ifdef _SSS_ON

          real3 N = normalize(i.normalWS);
          real3 V = normalize(_WorldSpaceCameraPos - i.posWS);
          real thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, i.uv).r;
          thickness *= _ThicknessFactor;

          // ! 直接光
          Light mainLight = GetMainLight();
          color += SSS(mainLight, N, V, thickness);

          // ! 间接光(灯光颜色 衰减 方向 与直接光不同)
          for (int j = 0; j < GetAdditionalLightsCount(); j++)
          {
            Light light = GetAdditionalLight(j, i.posWS);
            
            color += SSS(light, N, V, thickness);
          }

        #endif


        color = MixFog(color, inputData.fogCoord);

        return real4(color, 1);
      }

      ENDHLSL
    }

    pass
    {
      Name "ShadowCaster"
      Tags
      {
        "LightMode" = "ShadowCaster"
      }

      ColorMask 0

      HLSLPROGRAM

      #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

      #pragma shader_feature _ALPHATEST_ON
      #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
      #pragma multi_compile_instancing

      #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

      #pragma vertex ShadowPassVertex
      #pragma fragment ShadowPassFragment

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
