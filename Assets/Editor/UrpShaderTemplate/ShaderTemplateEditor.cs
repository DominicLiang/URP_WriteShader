using System.IO;
using UnityEditor;

public class ShaderTemplateEditor : Editor
{
  private const string TemplateBasePath = "Assets/Editor/UrpShaderTemplate/Template";

  [MenuItem("Assets/Create/Shader/URP无光照Shader")]
  private static void UrpShaderUnlit()
  {
    var templateName = "UnlitTemplate.shader";
    var path = AssetDatabase.GetAssetPath(Selection.activeObject);
    var templatePath = Path.Combine(TemplateBasePath, templateName);
    var newPath = Path.Combine(path, templateName);
    AssetDatabase.CopyAsset(templatePath, newPath);
    AssetDatabase.ImportAsset(newPath);
  }
}
