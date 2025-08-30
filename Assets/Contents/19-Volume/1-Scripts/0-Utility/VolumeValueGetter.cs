using UnityEngine;

public abstract class VolumeValueGetter
{
  public string shaderPath;
  public abstract bool IsActive();
  public abstract void SetValue(Material material);
}