using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
[VolumeComponentMenu("Custom/TintColor")]
public class TintColor : VolumeComponent, IPostProcessComponent
{
  public FloatParameter tintIntensity = new(1);
  public ColorParameter tintColor = new(Color.white);

  public bool IsActive()
  {
    return true;
  }

  public bool IsTileCompatible()
  {
    return true;
  }
}
