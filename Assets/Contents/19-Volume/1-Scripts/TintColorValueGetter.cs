using UnityEngine;
using UnityEngine.Rendering;

public class TintColorValueGetter : VolumeValueGetter
{
  private TintColor tintColor;

  public TintColorValueGetter()
  {
    tintColor = VolumeManager.instance.stack.GetComponent<TintColor>();
    shaderPath = "Custom/FullScreen/Tint";
  }

  public override bool IsActive()
  {
    return tintColor.tintIntensity.value > 0;
  }

  public override void SetValue(Material material)
  {
    material.SetFloat("_tintIntensity", tintColor.tintIntensity.value);
    material.SetColor("_tintColor", tintColor.tintColor.value);
  }
}