Shader "Custom/Normal/ParallaxMap2"
{
  Properties
  {
    // ! -------------------------------------
    // ! 面板属性
    [NoScaleOffset]_MainTex ("主贴图", 2D) = "white" { }
    [NoScaleOffset]_HeightTex ("高度贴图", 2D) = "white" { }

    _NumLayers ("_NumLayers", Range(1, 50)) = 10
    _ParallaxScale ("_ParallaxScale", Range(0, 5)) = 1
  }
  

  SubShader
  {
    LOD 100

    // ! -------------------------------------
    // ! Tags
    Tags
    {
      "Queue" = "Geometry"
      "RenderPipeline" = "UniversalPipeline"
    }

    HLSLINCLUDE

    // ! -------------------------------------
    // ! 全shader include
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    CBUFFER_START(UnityPerMaterial)

      // ! -------------------------------------
      // ! 变量声明
      TEXTURE2D(_MainTex);
      SAMPLER(sampler_MainTex);
      TEXTURE2D(_HeightTex);
      SAMPLER(sampler_HeightTex);
      int _NumLayers;
      float _ParallaxScale;

    CBUFFER_END

    ENDHLSL

    Pass
    {
      // ! -------------------------------------
      // ! Pass名
      Name "BasePass"

      // ! -------------------------------------
      // ! tags
      Tags
      {
        "LightMode" = "UniversalForward"
      }

      // ! -------------------------------------
      // ! 渲染状态
      Cull Back
      ZTest LEqual
      ZWrite On

      HLSLPROGRAM

      // ! -------------------------------------
      // ! pass include

      // ! -------------------------------------
      // ! Shader阶段
      #pragma vertex vert
      #pragma fragment frag

      // ! -------------------------------------
      // ! 材质关键字 shader_feature

      // ! -------------------------------------
      // ! URP关键字 multi_compile

      // ! -------------------------------------
      // ! Unity关键字 multi_compile

      // ! -------------------------------------
      // ! GPU实例 multi_compile

      // ! -------------------------------------
      // ! 顶点着色器输入
      struct appdata
      {
        real2 uv : TEXCOORD0;
        real4 positionOS : POSITION;
        real3 normalOS : NORMAL;
        real4 tangentOS : TANGENT;
      };

      // ! -------------------------------------
      // ! 顶点着色器输出 片元着色器输入
      struct v2f
      {
        real2 uv : TEXCOORD0;
        real4 positionCS : SV_POSITION;
        real3 positionWS : TEXCOORD1;
        real3 normalWS : TEXCOORD2;
        real3 viewDirTS : TEXCOORD3;
      };

      // ! -------------------------------------
      // ! 顶点着色器
      v2f vert(appdata v)
      {
        v2f o = (v2f)0;


        VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
        
        o.uv = v.uv;

        o.positionCS = positionInputs.positionCS;
        o.positionWS = positionInputs.positionWS;
        o.normalWS = normalInputs.normalWS;

        real3x3 TBN = real3x3(
          normalize(normalInputs.tangentWS),
          normalize(normalInputs.bitangentWS),
          normalize(normalInputs.normalWS)
        );

        real3 cameraPositionTS = mul(TBN, float4(GetCameraPositionWS(), 1)).xyz;
        real3 positionTS = mul(TBN, float4(positionInputs.positionWS, 1)).xyz;
        real3 viewDirTS = normalize(cameraPositionTS - positionTS);
        o.viewDirTS = viewDirTS;

        return o;
      }

      

      half GetParallaxHeight(float2 uv)
      {
        float4 color = SAMPLE_TEXTURE2D(_HeightTex, sampler_HeightTex, uv);
        return saturate(color.r);
      }

      half2 ParallaxOcclusionMapping(v2f i)
      {
        // 切线空间视方向
        real3 viewDir = i.viewDirTS;

        // 细分层数
        int numLayers = _NumLayers;
        // 单层歩进的高度
        half layerStep = 1.0 / numLayers;

        // 层的高度值(初始数最大值)
        half curLayerHeight = 1.0;

        // delta最大值
        half2 p = viewDir.xy / viewDir.z * _ParallaxScale;
        // delta单步逼近值
        const half2 uvDelta = p / numLayers;

        // 开始一步步逼近 直到找到合适的红点
        half2 uvMain = i.uv;
        half2 uvCur = uvMain + p;
        half2 uvFinal = uvMain;
        half mapHeight = GetParallaxHeight(uvCur); // ? GetParallaxHeight 采样高度贴图?

        UNITY_LOOP
        for (int i = 0; i < numLayers; i++)
        {
          if (curLayerHeight <= mapHeight)
          {
            break;
          }
          uvCur -= uvDelta;
          mapHeight = GetParallaxHeight(uvCur);
          curLayerHeight -= layerStep;
        }

        // 计算 h1 和 h2
        half2 uvPrev = uvCur + uvDelta;
        half prevMapHeight = GetParallaxHeight(uvPrev);
        half prevLayerHeight = curLayerHeight + layerStep;
        half beforeHeight = prevLayerHeight - prevMapHeight; // h1
        half afterHeight = mapHeight - curLayerHeight; // h2

        // 利用h1和h2得到权重,在两个红点间使用权重进行插值
        half weight = afterHeight / (afterHeight + beforeHeight);
        uvFinal = lerp(uvPrev, uvCur, weight);

        return uvFinal - uvMain;
      }

      // ! -------------------------------------
      // ! 片元着色器
      real4 frag(v2f i) : SV_TARGET
      {
        half2 offset = ParallaxOcclusionMapping(i);

        real4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + offset);

        return color;
      }

      ENDHLSL
    }
  }

  // ! -------------------------------------
  // ! 紫色报错fallback
  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
