Shader "Custom/07-Water/Water"
{
  Properties
  {
    _DepthMin ("深度最小值", Range(0, 10)) = 0
    _DepthMax ("深度最大值", Range(0, 10)) = 1
    
    _WaterColorDeep ("深水颜色", Color) = (0, 0, 0, 1)
    _WaterColorShallow ("浅水颜色", Color) = (1, 1, 1, 1)

    _FoamShapeTexture ("泡沫形状纹理", 2D) = "" { }
    _FoamRange ("泡沫范围", Range(0, 10)) = 1
    _FoamSmoothness ("泡沫平滑", Float) = 1
    _FoamColor ("泡沫颜色", Color) = (1, 1, 1, 1)

    _RefractTex ("折射扰动纹理", 2D) = "bump" { }
    _RefractFactor ("折射扰动系数", Range(0, 1)) = 1

    _ShineFactor ("高光强度", Range(1, 128)) = 1
    _ShineTex ("高光纹理", 2D) = "bump" { }
    _ShineColor ("高光颜色", Color) = (1, 1, 1, 1)

    _CubeMap ("环境反射贴图", Cube) = "" { }

    _CausticsTex ("焦散贴图", 2D) = "white" { }
    _CausticsIntensity ("焦散强度", Range(0, 1)) = 1
    _CausticsColor ("焦散颜色", Color) = (1, 1, 1, 1)
  }
  SubShader
  {
    LOD 200

    Tags
    {
      "Queue" = "Transparent"
      "RenderPipeline" = "UniversalPipeline"
    }

    HLSLINCLUDE

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    CBUFFER_START(UnityPerMaterial)

      TEXTURE2D(_CameraDepthTexture);
      SAMPLER(sampler_CameraDepthTexture);

      TEXTURE2D(_CameraOpaqueTexture);
      SAMPLER(sampler_CameraOpaqueTexture);

      real _DepthMin;
      real _DepthMax;
      real4 _WaterColorDeep;
      real4 _WaterColorShallow;

      TEXTURE2D(_FoamShapeTexture);
      SAMPLER(sampler_FoamShapeTexture);
      real4 _FoamShapeTexture_ST;
      real _FoamRange;
      real _FoamSmoothness;
      real4 _FoamColor;

      TEXTURE2D(_RefractTex);
      SAMPLER(sampler_RefractTex);
      real4 _RefractTex_ST;
      real _RefractFactor;

      TEXTURE2D(_ShineTex);
      SAMPLER(sampler_ShineTex);
      real4 _ShineTex_ST;
      real _ShineFactor;
      real4 _ShineColor;
      
      TEXTURECUBE(_CubeMap);
      SAMPLER(sampler_CubeMap);

      TEXTURE2D(_CausticsTex);
      SAMPLER(sampler_CausticsTex);
      real4 _CausticsTex_ST;
      real _CausticsIntensity;
      real4 _CausticsColor;

    CBUFFER_END

    ENDHLSL

    Pass
    {
      Name "BasePass"

      Tags
      {
        "LightMode" = "UniversalForward"
      }

      Cull Back
      ZTest LEqual
      ZWrite On
      // Blend One One

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
        real2 uv2 : TEXCOORD1;
        real2 uv3 : TEXCOORD2;
        real4 positionCS : SV_POSITION;
        real3 positionVS : TEXCOORD4;
        real3 positionWS : TEXCOORD5;
        real3 normalWS : TEXCOORD6;
      };

      v2f vert(appdata v)
      {
        v2f o = (v2f)0;

        VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS);
        
        o.uv = TRANSFORM_TEX(v.uv, _FoamShapeTexture) + _Time.x;
        o.uv2 = TRANSFORM_TEX(v.uv, _RefractTex) + _Time.x;
        o.uv3 = TRANSFORM_TEX(v.uv, _ShineTex) + _Time.x;

        o.positionCS = positionInputs.positionCS;
        o.positionVS = positionInputs.positionVS;
        o.positionWS = positionInputs.positionWS;
        o.normalWS = normalInputs.normalWS;

        return o;
      }

      void Unity_Remap_float4(float In, float2 InMinMax, float2 OutMinMax, out float Out)
      {
        Out = OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
      }

      real4 frag(v2f i) : SV_TARGET
      {
        // ! 深度
        real2 orgScreenUV = i.positionCS.xy / GetScaledScreenParams().xy;
        real depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, orgScreenUV).r;
        depth = LinearEyeDepth(depth, _ZBufferParams);
        real height = depth + i.positionVS.z;
        Unity_Remap_float4(height, real2(_DepthMin, _DepthMax), real2(0, 1), height);
        height = saturate(height);

        // ! 泡沫
        real foamRange = _FoamRange * height;
        real foamShape = SAMPLE_TEXTURE2D(_FoamShapeTexture, sampler_FoamShapeTexture, i.uv).r;
        foamShape = pow(foamShape, _FoamSmoothness);
        foamShape = step(foamRange, foamShape);

        // ! 折射
        real uvRefract = SAMPLE_TEXTURE2D(_RefractTex, sampler_RefractTex, i.uv2);
        real2 screenUV = orgScreenUV + uvRefract * _RefractFactor;
        real4 refractColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);

        // ! 高光
        real3 normalMap = normalize(SAMPLE_TEXTURE2D(_ShineTex, sampler_ShineTex, i.uv3) * 2 - 1);
        Light light = GetMainLight();
        real3 n = normalMap;//i.normalWS;
        real3 l = light.direction;
        real3 v = normalize(GetCameraPositionWS() - i.positionWS);
        real3 h = normalize(l + v);
        real spec = pow(max(dot(n, h), 0), _ShineFactor);

        // ! 反射
        // * CubeMap
        real3 rn = lerp(i.normalWS, n, 0.1);
        real3 r = reflect(-v, rn);
        real4 reflectColor = SAMPLE_TEXTURECUBE(_CubeMap, sampler_CubeMap, r);
        // * 反射探针
        // real4 reflectColor = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, r);
        // return real4(reflectColor.rgb, 1);

        // ! 焦散
        real4 objPosVS = 1;
        objPosVS.xy = depth / - i.positionVS.z * i.positionVS.xy;
        objPosVS.z = depth;
        real3 objPosWS = mul(unity_CameraToWorld, objPosVS).xyz;
        real2 uvCaustics = (objPosWS.xz + objPosWS.y) * _CausticsTex_ST.xy + _CausticsTex_ST.zw;
        real4 causticsColor = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, uvCaustics);
        causticsColor *= height;
        causticsColor *= _CausticsIntensity;
        // real4 causticsColor = _CausticsColor * causticsFactor;

        
        // ! 最终
        real4 color = refractColor * _WaterColorShallow;
        // color = lerp(color, _WaterColorDeep, height);
        color = lerp(color, reflectColor, 0.02);
        color = lerp(color, _ShineColor, spec);
        color = lerp(color, _FoamColor, foamShape);
        color += causticsColor;

        return color;
      }

      ENDHLSL
    }
  }

  Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
