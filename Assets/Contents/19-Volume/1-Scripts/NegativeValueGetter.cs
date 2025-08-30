using UnityEngine;
using UnityEngine.Rendering;

public class NegativeValueGetter : VolumeValueGetter
{
  private Negative negative;

  public NegativeValueGetter()
  {
    negative = VolumeManager.instance.stack.GetComponent<Negative>();
    shaderPath = "Custom/FullScreen/Negative";
  }

  public override bool IsActive()
  {
    return negative.Intensity.value > 0;
  }

  public override void SetValue(Material material)
  {
    material.SetFloat("_negativeIntensity", negative.Intensity.value);
  }
}