half2 GetInvSize(Texture2D tex)
{
  half2 texSize = half2(0, 0);
  tex.GetDimensions(texSize.x, texSize.y);
  half2 invSize = 1.0 / texSize;
  return invSize;
}

float Rand(float2 n)
{
  return sin(dot(n, half2(1233.224, 1743.335)));
}

// -----------------------------------------------------------------------------------------------

// Box模糊 4步
half4 BoxBlur_4Tap(Texture2D tex, SamplerState tex_sampler, float2 uv, float2 offset)
{
  float4 d = offset.xyxy * float4(-1.0, -1.0, 1.0, 1.0);
  
  half4 s = 0;
  s = tex.Sample(tex_sampler, uv + d.xy) * 0.25h;  // 1 MUL
  s += tex.Sample(tex_sampler, uv + d.zy) * 0.25h; // 1 MAD
  s += tex.Sample(tex_sampler, uv + d.xw) * 0.25h; // 1 MAD
  s += tex.Sample(tex_sampler, uv + d.zw) * 0.25h; // 1 MAD
  
  return s;
}

// Tent模糊
half4 TentBlur_9Tap(Texture2D tex, SamplerState tex_sampler, float2 uv, float2 offset)
{
  half2 texSize = half2(0, 0);
  tex.GetDimensions(texSize.x, texSize.y);
  half2 texelSize = offset / texSize;

  float4 d = texelSize.xyxy * float4(1.0, 1.0, -1.0, 0.0);
  
  half4 color;
  color = tex.Sample(tex_sampler, uv - d.xy);
  color += tex.Sample(tex_sampler, uv - d.wy) * 2.0;
  color += tex.Sample(tex_sampler, uv - d.zy);
  
  color += tex.Sample(tex_sampler, uv + d.zw) * 2.0;
  color += tex.Sample(tex_sampler, uv) * 4.0;
  color += tex.Sample(tex_sampler, uv + d.xw) * 2.0;
  
  color += tex.Sample(tex_sampler, uv + d.zy);
  color += tex.Sample(tex_sampler, uv + d.wy) * 2.0;
  color += tex.Sample(tex_sampler, uv + d.xy);
  
  return color * (1.0 / 16.0);
}

// Bokeh模糊
half4 BokehBlur(Texture2D tex, SamplerState tex_sampler, half2 uv, half radius, int iteration)
{
  half2x2 rot = half2x2(-0.737277, -0.675590, 0.675590, -0.737277);

  half2 invSize = GetInvSize(tex);

  half4 accumulator = 0.0;
  half4 divisor = 0.0;
  half r = 1.0;
  half2 angle = half2(0.0, radius);

  for (int j = 0; j < iteration; j++)
  {
    r += 1.0 / r;
    angle = mul(rot, angle);
    half2 offset = invSize * (r - 1.0) * angle;
    half4 bokeh = tex.Sample(tex_sampler, uv + offset);
    accumulator += bokeh * bokeh;
    divisor += bokeh;
  }

  return accumulator / divisor;
}

// Kawase模糊
half4 KawaseBlur(Texture2D tex, SamplerState tex_sampler, float2 uv, half pixelOffset)
{
  half2 invSize = GetInvSize(tex);

  half4 o = 0;
  o += tex.Sample(tex_sampler, uv + float2(pixelOffset +0.5, pixelOffset +0.5) * invSize);
  o += tex.Sample(tex_sampler, uv + float2(-pixelOffset -0.5, pixelOffset +0.5) * invSize);
  o += tex.Sample(tex_sampler, uv + float2(-pixelOffset -0.5, -pixelOffset -0.5) * invSize);
  o += tex.Sample(tex_sampler, uv + float2(pixelOffset +0.5, -pixelOffset -0.5) * invSize);
  return o * 0.25;
}

// 高斯模糊
half4 GaussianBlur(Texture2D tex, SamplerState tex_sampler, half2 uv, half intensity)
{
  half kernel[9] = {
    1.0 / 159, 2.0 / 159, 3.0 / 159, 4.0 / 159, 5.0 / 159, 4.0 / 159, 3.0 / 159, 2.0 / 159, 1.0 / 159
  };

  half2 invSize = GetInvSize(tex);

  half4 sum = half4(0, 0, 0, 0);
  half kernelSum = 0;

  [unroll]
  for (int x = -4; x <= 4; x++)
  {
    [unroll]
    for (int y = -4; y <= 4; y++)
    {
      half2 offset = half2(x, y) * invSize * intensity;
      half4 sample = tex.Sample(tex_sampler, uv + offset);
      sum += sample * kernel[x + 4];
      kernelSum += kernel[x + 4];
    }
  }

  return sum / kernelSum;
}

// Grainy模糊
half4 GrainyBlur(Texture2D tex, SamplerState tex_sampler, float2 uv, float2 offset, int iteration)
{
  half2 randomOffset = float2(0.0, 0.0);
  half4 finalColor = half4(0.0, 0.0, 0.0, 0.0);
  float random = Rand(uv);
  
  for (int k = 0; k < iteration; k++)
  {
    random = frac(43758.5453 * random + 0.61432);;
    randomOffset.x = (random - 0.5) * 2.0;
    random = frac(43758.5453 * random + 0.61432);
    randomOffset.y = (random - 0.5) * 2.0;
    half2 uv_offset = randomOffset * offset;

    finalColor += tex.Sample(tex_sampler, uv + uv_offset);
  }
  return finalColor / iteration;
}

// 方向模糊
half4 DirectionalBlur(Texture2D tex, SamplerState tex_sampler, float2 uv, float offset, int iteration, float angle)
{
  float sinVal = sin(angle) * offset * 0.05 / iteration;
  float cosVal = cos(angle) * offset * 0.05 / iteration;
  float2 direction = float2(sinVal, cosVal);

  half4 color = half4(0.0, 0.0, 0.0, 0.0);

  for (int k = -iteration; k < iteration; k++)
  {
    color += tex.Sample(tex_sampler, uv - direction * k);
  }

  return color / (iteration * 2.0);
}

// 径向模糊
half4 RadialBlur(Texture2D tex, SamplerState tex_sampler, float2 uv, float2 offset, int iteration, float2 center)
{
  uv -= center;

  half scale = 1;
  half4 color = tex.Sample(tex_sampler, uv * scale + center);

  for (int i = 1; i < iteration; i++)
  {
    scale = i * offset +1;
    color += tex.Sample(tex_sampler, uv * scale + center);
  }

  color /= iteration;
  return color;
}


