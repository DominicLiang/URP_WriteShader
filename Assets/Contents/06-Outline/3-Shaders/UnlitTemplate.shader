Shader "Custom/ToonTest"
{
  Properties
  {
    [NoScaleOffset]_MainTex ("主贴图", 2D) = "white" { }
    [NoScaleOffset]_LightMap ("LightMap", 2D) = "white" { }
    [NoScaleOffset]_RampMapCool ("CoolRamp", 2D) = "white" { }
    [NoScaleOffset]_RampMapWarm ("WarmRamp", 2D) = "white" { }


    _Step ("Step", Range(0, 1)) = 0.5

    _RampCoolWarmLerpFactor ("Cool / Warm", Range(0, 1)) = 1
  }
  SubShader
  {
    LOD 200

    Tags
    {
      "Queue" = "Geometry"
      "RenderPipeline" = "UniversalPipeline"
    }

    Cull Back
    ZTest LEqual
    ZWrite On

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    CBUFFER_START(UnityPerMaterial)

      TEXTURE2D(_MainTex);
      SAMPLER(sampler_MainTex);

      TEXTURE2D(_LightMap);
      SAMPLER(sampler_LightMap);

      TEXTURE2D(_RampMapCool);
      SAMPLER(sampler_RampMapCool);

      TEXTURE2D(_RampMapWarm);
      SAMPLER(sampler_RampMapWarm);

      real4 _MainColor;
      real _Step;

      real _RampCoolWarmLerpFactor;

    CBUFFER_END

    ENDHLSL

    Pass
    {
      Name "BasePass"

      Tags
      {
        "LightMode" = "UniversalForward"
      }

      HLSLPROGRAM

      #pragma vertex vert
      #pragma fragment frag

      struct appdata
      {
        real2 uv : TEXCOORD0;
        real4 positionOS : POSITION;
        real3 normalOS : NORMAL;
        real3 tangentOS : TANGENT;
        real4 color : COLOR;
      };

      struct v2f
      {
        real2 uv : TEXCOORD0;
        real4 positionCS : SV_POSITION;
        real3 positionWS : TEXCOORD1;
        real3 normalWS : TEXCOORD2;
        real3 tangentWS : TEXCOORD3;
        real4 color : COLOR;
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;

        VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS);
        
        o.uv = v.uv;

        o.positionCS = positionInputs.positionCS;
        o.positionWS = positionInputs.positionWS;
        o.normalWS = normalInputs.normalWS;
        o.tangentWS = v.tangentOS;

        o.color = v.color;

        return o;
      }

      struct Directions
      {
        // Common Directions
        float3 N;
        float3 V;
        float3 L;
        float3 H;

        // Dot Products
        float NoL;
        float NoH;
        float NoV;
        float LoH;
      };

      struct DiffuseData
      {
        float NoL;
        bool singleMaterial;
        float rampCoolOrWarm;
      };



      Directions GetWorldSpaceDirections(Light light, float3 positionWS, float3 normalWS)
      {
        Directions dirWS;

        dirWS.N = normalize(normalWS);
        dirWS.V = normalize(GetWorldSpaceViewDir(positionWS));
        dirWS.L = normalize(light.direction);
        dirWS.H = normalize(dirWS.V + dirWS.L);

        dirWS.NoL = dot(dirWS.N, dirWS.L);
        dirWS.NoH = dot(dirWS.N, dirWS.H);
        dirWS.NoV = dot(dirWS.N, dirWS.V);
        dirWS.LoH = dot(dirWS.L, dirWS.H);

        return dirWS;
      }

      float2 GetRampUV(float NoL, bool singleMaterial, float4 vertexColor, float4 lightMap, half shadowAttenuation)
      {
        // 头发 Ramp 上一共 2 条颜色，对应一个材质
        // 身体 Ramp 上一共 16 条颜色，每两条对应一个材质，共 8 种材质

        float ao = lightMap.g;
        float material = singleMaterial ? 0 : lightMap.a;

        // // 游戏内模型有顶点 AO
        // #if defined(_MODEL_GAME)
        //   ao *= vertexColor.r;
        // #endif

        float NoL01 = NoL * 0.5 + 0.5;


        
        float shadow = min(1.0f, dot(NoL01.xx, 2 * ao.xx));


        shadow = max(0.001f, shadow) * 0.75f + 0.25f;
        shadow = (shadow > 1) ? 0.99f : shadow;

        shadow = lerp(0.20, shadow, saturate(shadowAttenuation + HALF_EPS));
        shadow = lerp(0, shadow, step(0.05, ao)); // AO < 0.05 的区域（自阴影区域）永远不受光
        shadow = lerp(1, shadow, step(ao, 0.95)); // AO > 0.95 的区域永远受最强光



        return float2(shadow, material + 0.05);
      }

      float3 GetRampDiffuse(
        DiffuseData data,
        Light light,
        float4 vertexColor,
        float3 baseColor,
        float4 lightMap,
        TEXTURE2D_PARAM(rampMapCool, sampler_rampMapCool),
        TEXTURE2D_PARAM(rampMapWarm, sampler_rampMapWarm))
      {
        float2 rampUV = GetRampUV(data.NoL, data.singleMaterial, vertexColor, lightMap, light.shadowAttenuation);
        float3 rampCool = SAMPLE_TEXTURE2D(rampMapCool, sampler_rampMapCool, rampUV).rgb;
        float3 rampWarm = SAMPLE_TEXTURE2D(rampMapWarm, sampler_rampMapWarm, rampUV).rgb;
        float3 rampColor = lerp(rampCool, rampWarm, data.rampCoolOrWarm);

        return rampColor * baseColor * light.color * light.distanceAttenuation;
      }

      real4 frag(v2f i) : SV_TARGET
      {
        Light light = GetMainLight();

        float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
        float4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, i.uv.xy);

        Directions dirWS = GetWorldSpaceDirections(light, i.positionWS, i.normalWS);

        DiffuseData diffuseData;
        diffuseData.NoL = dirWS.NoL;
        diffuseData.singleMaterial = false;
        diffuseData.rampCoolOrWarm = _RampCoolWarmLerpFactor;
        
        float3 diffuse = GetRampDiffuse(diffuseData, light, i.color, texColor.rgb, lightMap,
        TEXTURE2D_ARGS(_RampMapCool, sampler_RampMapCool), TEXTURE2D_ARGS(_RampMapWarm, sampler_RampMapWarm));

        return real4(diffuse, 1);
      }

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
