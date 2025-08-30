using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class FullScreenRF : ScriptableRendererFeature
{
  #region FullScreenPass
  private class FullScreenPass : ScriptableRenderPass
  {
    private ProfilingSampler profiling;
    private VolumeValueGetter valueGetter;
    private Material material;

    public void Setup(string passName, VolumeValueGetter valueGetter, Material material)
    {
      profiling = new ProfilingSampler(passName);
      this.valueGetter = valueGetter;
      this.material = material;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
      var cmd = CommandBufferPool.Get();
      using (new ProfilingScope(cmd, profiling))
      {
        valueGetter.SetValue(material);
        CoreUtils.SetRenderTarget(cmd, renderingData.cameraData.renderer.cameraColorTargetHandle);
        Blitter.BlitCameraTexture(cmd, renderingData.cameraData.renderer.cameraColorTargetHandle,
                                  renderingData.cameraData.renderer.cameraColorTargetHandle, material, 0);
      }
      context.ExecuteCommandBuffer(cmd);

      cmd.Clear();
      CommandBufferPool.Release(cmd);
    }
  }
  #endregion

  public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;
  public string valueGetterName;

  private VolumeValueGetter valueGetter;
  private Material material;

  private FullScreenPass pass;

  public override void Create()
  {
    pass = new FullScreenPass
    {
      renderPassEvent = RenderPassEvent.AfterRenderingOpaques
    };
  }

  public VolumeValueGetter GetValueGetter(string name)
  {
    if (string.IsNullOrEmpty(name)) return null;
    var type = Type.GetType(name);
    if (type == null) return null;
    var valueGetter = Activator.CreateInstance(type) as VolumeValueGetter;
    return valueGetter;
  }

  public void GetAllVolumes()
  {
    valueGetter = GetValueGetter(valueGetterName);
    material = CoreUtils.CreateEngineMaterial(valueGetter.shaderPath);
  }

  public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
  {
    GetAllVolumes();
    if (valueGetter == null || material == null || !valueGetter.IsActive()) return;
    // if (renderingData.cameraData.camera.cameraType != CameraType.Game) return;

    renderer.EnqueuePass(pass);
  }

  public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
  {
    pass.renderPassEvent = injectionPoint;
    pass.ConfigureInput(passInput: ScriptableRenderPassInput.Color);
    pass.Setup(name, valueGetter, material);
  }
}


