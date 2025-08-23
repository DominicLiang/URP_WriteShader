Shader "Custom/08-ParallaxMap/ParallaxMap"
{
  Properties
  {
    [NoScaleOffset]_MainTex ("主贴图", 2D) = "white" { }
    [NoScaleOffset]_NormalMap ("法线贴图", 2D) = "bump" { }
    [NoScaleOffset]_ParallaxMap ("视差贴图", 2D) = "white" { }
    _ParallaxScale ("视差强度", Range(-1, 1)) = 0
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
      TEXTURE2D(_NormalMap);
      SAMPLER(sampler_NormalMap);
      TEXTURE2D(_ParallaxMap);
      SAMPLER(sampler_ParallaxMap);
      real _ParallaxScale;

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
      };

      struct v2f
      {
        real2 uv : TEXCOORD0;
        real4 positionCS : SV_POSITION;
        real3 positionWS : TEXCOORD1;
        real3 normalWS : TEXCOORD2;
        real3 tangentWS : TEXCOORD3;
        real3 bitangentWS : TEXCOORD4;
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
        o.tangentWS = normalInputs.tangentWS;
        o.bitangentWS = normalInputs.bitangentWS;
        
        return o;
      }

      real4 frag(v2f i) : SV_TARGET
      {
        real3 viewDirWS = normalize(GetCameraPositionWS() - i.positionWS);
        real3x3 TBN = real3x3(normalize(i.tangentWS), normalize(i.bitangentWS), normalize(i.normalWS));
        real3 viewDirTS = mul(TBN, viewDirWS);

        real height = SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, i.uv).r;
        height -= 0.5;
        real2 offset = -viewDirTS.xy / max(viewDirTS.z, 0.01) * height * _ParallaxScale;
        real2 parallaxUV = i.uv + offset;

        real4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, parallaxUV);
        real3 tangentNormal = UnpackNormal(packedNormal);
        real3 normalWS = normalize(mul(tangentNormal, TBN));
        Light light = GetMainLight();
        real NoL = dot(normalWS, light.direction);
        real halfLambert = NoL * 0.5 + 0.5;

        real4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, parallaxUV);
        
        return baseColor * halfLambert;
      }

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
