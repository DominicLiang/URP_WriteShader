Shader "Custom/06-Outline/Outline"
{
  Properties
  {
    [NoScaleOffset]_MainTex ("主贴图", 2D) = "white" { }
    [HDR]_MainColor ("主颜色", Color) = (1, 1, 1, 1)
    
    [Toggle(_Outline_ON)]_OutlineSwitch ("描边开关", Float) = 0
    [HDR]_OutlineColor ("描边颜色", Color) = (0, 0, 0, 1)
    _OutlineWidth ("描边宽度", Range(0, 1)) = 0
    _OutlineFixedWidth ("描边根据距离调节", Range(0, 1)) = 1
    [Enum(Off, 8, On, 6)] _OnlyOutside ("只描边外轮廓", float) = 0
    _StencilRef ("模版参考值", int) = 1
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
      real4 _MainColor;

      real4 _OutlineColor;
      real _OutlineWidth;
      real _OutlineFixedWidth;

    CBUFFER_END

    ENDHLSL

    Pass
    {
      Name "BasePass"

      Tags
      {
        "LightMode" = "UniversalForward"
      }

      Stencil
      {
        Ref [_StencilRef]
        Comp Always
        Pass Replace
      }

      HLSLPROGRAM

      #pragma vertex vert
      #pragma fragment frag

      struct appdata
      {
        real2 uv : TEXCOORD0;
        real3 positionOS : POSITION;
        real3 normalOS : NORMAL;
        real4 color : COLOR;
      };

      struct v2f
      {
        real2 uv : TEXCOORD0;
        real4 positionCS : SV_POSITION;
        real3 normalWS : TEXCOORD1;
        real4 color : COLOR;
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;

        VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS);
        
        o.uv = v.uv;

        o.positionCS = positionInputs.positionCS;
        o.normalWS = normalInputs.normalWS;

        o.color = v.color;

        return o;
      }

      real4 frag(v2f i) : SV_TARGET
      {
        real4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
        
        return baseColor * _MainColor;
      }

      ENDHLSL
    }

    Pass
    {
      Name "Outline"

      Tags
      {
        "LightMode" = "Outline"
      }

      Cull Front

      Stencil
      {
        Ref [_StencilRef]
        Comp [_OnlyOutside]
        Pass Keep
      }

      HLSLPROGRAM

      #pragma shader_feature _Outline_ON

      #pragma vertex vert
      #pragma fragment frag

      struct appdata
      {
        real2 uv : TEXCOORD0;
        real3 positionOS : POSITION;
        real3 normalOS : NORMAL;
        real3 tangentOS : TANGENT;
      };

      struct v2f
      {
        real2 uv : TEXCOORD0;
        real4 positionCS : SV_POSITION;
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;
        
        real cameraDistance = length(mul(UNITY_MATRIX_M, v.positionOS).xyz - GetCameraPositionWS());
        real distanceFactor = lerp(1, cameraDistance, _OutlineFixedWidth);
        real outlineWidth = _OutlineWidth * distanceFactor * 0.01;
        real3 outlineVector = v.tangentOS * outlineWidth;
        real3 finalPosOS = v.positionOS + outlineVector;
        
        o.uv = v.uv;

        o.positionCS = GetVertexPositionInputs(finalPosOS).positionCS;

        return o;
      }

      real4 frag(v2f i) : SV_TARGET
      {
        return _OutlineColor;
      }

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
