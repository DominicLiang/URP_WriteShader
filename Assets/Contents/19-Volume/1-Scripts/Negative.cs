using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[VolumeComponentMenu("Custom/Negative")]
public class Negative : VolumeComponent, IPostProcessComponent
{
  public FloatParameter Intensity = new(1);

  public bool IsActive()
  {
    return true;
  }

  public bool IsTileCompatible()
  {
    return true;
  }
}
