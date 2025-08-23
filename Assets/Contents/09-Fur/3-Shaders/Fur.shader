Shader "Custom/09-Fur/Fur"
{
  Properties
  {
    [NoScaleOffset]_MainTex ("主贴图", 2D) = "white" { }
    [HDR]_MainColor ("主颜色", Color) = (1, 1, 1, 1)

    _FurFactor ("毛发外扩系数", Range(0.0002, 1)) = 0.25
    _FurAlpha ("毛发透明度系数", Range(0, 1)) = 0.5
    _FurAlphaFactor ("毛发边缘系数", Range(0, 1)) = 0.5
  }
  SubShader
  {
    LOD 200

    Tags
    {
      "Queue" = "Transparent"
      "RenderPipeline" = "UniversalPipeline"
    }

    Cull Off
    ZTest LEqual
    ZWrite On
    Blend SrcAlpha OneMinusSrcAlpha

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    CBUFFER_START(UnityPerMaterial)

      TEXTURE2D(_MainTex);
      SAMPLER(sampler_MainTex);
      real4 _MainColor;

      real _FurFactor;
      real _FurAlpha;
      real _FurAlphaFactor;

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
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;

        v.positionOS.xyz += v.normalOS * _FurFactor;

        VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS);
        
        o.uv = v.uv;

        o.positionCS = positionInputs.positionCS;
        o.positionWS = positionInputs.positionWS;
        o.normalWS = normalInputs.normalWS;

        return o;
      }

      real4 frag(v2f i) : SV_TARGET
      {
        real3 viewDir = normalize(GetCameraPositionWS() - i.positionWS);
        real NoV = saturate(dot(i.normalWS, viewDir));

        real4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
        baseColor.a = saturate(baseColor.r - _FurAlpha);
        baseColor.a *= saturate(NoV - _FurAlphaFactor);

        return baseColor * _MainColor;
      }

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
