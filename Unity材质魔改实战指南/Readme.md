# Unity材质魔改实战指南

# GUI篇

## 总览

每一个材质引用的GUI文件在Fallback的下面。我们以URP为例子：

```glsl
FallBack "Hidden/Universal Render Pipeline/FallbackError"
CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
```

然后我们只要找到这个UnityEditor.Rendering.Universal.ShaderGUI.LitShader进行魔改就可以。

首先是我们找到这个文件，直接在搜索栏搜LitShader就可以搜到。它的目录在：

```
..\Library\PackageCache\com.unity.render-pipelines.universal@10.6.0\Editor\ShaderGUI\Shaders
```

完整代码这里不贴了，简单说一下这个的结构。

`internal class LitShader : BaseShaderGUI` 它是继承`BaseShaderGUI`的，所以我们同时还需要找到BaseShaderGUI这个文件，位于

```csharp
..\Library\PackageCache\com.unity.render-pipelines.universal@10.6.0\Editor\ShaderGUI
```

其中我们会有一大堆文件带Styles.XXX的，这个是我们GUI对应的材质参数的描述。一般长这个样子

```csharp
protected class Styles{
public static readonly GUIContent SurfaceOptions = new GUIContent("Surface Options", "Controls how Universal RP renders the Material on a screen.");
}

```

其中GUIContent的第一个参数对应的是显示在GUI面板的内容，第二个参数则是悬停在GUI的时候出现的提示文字。

因为我们有大量的贴图、参数、分区需要绘制，所以我们对这些描述性的文字储存起来，也方便我们后期的维护的统一的管理。其中BaseShaderGUI的可以直接使用，而其他自定义的部分我们可以在我们自己的类里面储存起来。

第二个大量出现的是xxxProperties

这个代表的就是这个材质的参数属性。

通常我们会让需要修改的属性和GUI上面板的内容一一对应，所以同样的我们需要用一个类、结构体之类的容器把这一大堆东西储存起来。

一般是长这个样子的：

```csharp
public struct LitProperties{
	public MaterialProperty workflowMode;
	public LitProperties(MaterialProperty[] properties){           
		workflowMode = BaseShaderGUI.FindProperty("_WorkflowMode", properties, false);
	}
}
```

第三个第三个经常出现的是XXGUI。这个东西是我们真正描述如何绘制GUI的逻辑。这个一般和我们的着色模型有关系。如`LitGUI`，`DetialGUI`等。

我们可以把XXShader理解为一个容器，用于管理各个模块的执行顺序和排列的逻辑。而XXGUI则是实际上执行的小模块。

然后`BaseShaderGUI`有一大堆函数需要重载。这里只提及我更改了的部分：

```csharp
public override void OnOpenGUI(Material material, MaterialEditor materialEditor){}
```

```csharp
public override void DrawAdditionalFoldouts(Material material){}
```

```csharp
public override void FindProperties(MaterialProperty[] properties)
```

```csharp
public override void MaterialChanged(Material material)
```

```csharp
public override void DrawSurfaceOptions(Material material)
```

```csharp
public override void DrawSurfaceInputs(Material material)
```

```csharp
public override void DrawAdvancedOptions(Material material)
```

这几个在BaseShaderGUI里面是虚函数，也可以不进行override用它默认的设置。

其中`DrawSurfaceOptions`  `DrawSurfaceInputs`  `DrawAdvancedOptions`  `DrawAdditionalFoldouts` 这四个是比较关键的。分别对应的是图中的这四个区域：

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled.png)

注意这里其实是BaseShaderGUI的本身的写法，实际上我们自定义Shader的编辑器不一定需要这四个分区。可以看这个链接作为参考：

[ShaderGUI](https://docs.unity3d.com/ScriptReference/ShaderGUI.html)

- tips
    
    这里顺便贴一下shaderGUI的一些虚函数，可以根据函数名来猜测它的意思（很好猜）直接重载
    
    ```csharp
    #region 程序集 UnityEditor.CoreModule, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null
    // UnityEditor.CoreModule.dll
    #endregion
    
    using UnityEngine;
    
    namespace UnityEditor
    {
        //
        // 摘要:
        //     Abstract class to derive from for defining custom GUI for shader properties and
        //     for extending the material preview.
        public abstract class ShaderGUI
        {
            protected ShaderGUI();
    
            //
            // 摘要:
            //     Find shader properties.
            //
            // 参数:
            //   propertyName:
            //     Name of the material property.
            //
            //   properties:
            //     The array of available properties.
            //
            //   propertyIsMandatory:
            //     If true then this method will throw an exception if a property with propertyName
            //     was not found.
            //
            // 返回结果:
            //     The material property found, otherwise null.
            protected static MaterialProperty FindProperty(string propertyName, MaterialProperty[] properties);
            //
            // 摘要:
            //     Find shader properties.
            //
            // 参数:
            //   propertyName:
            //     Name of the material property.
            //
            //   properties:
            //     The array of available properties.
            //
            //   propertyIsMandatory:
            //     If true then this method will throw an exception if a property with propertyName
            //     was not found.
            //
            // 返回结果:
            //     The material property found, otherwise null.
            protected static MaterialProperty FindProperty(string propertyName, MaterialProperty[] properties, bool propertyIsMandatory);
            //
            // 摘要:
            //     This method is called when a new shader has been selected for a Material.
            //
            // 参数:
            //   material:
            //     The material the newShader should be assigned to.
            //
            //   oldShader:
            //     Previous shader.
            //
            //   newShader:
            //     New shader to assign to the material.
            public virtual void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader);
            //
            // 摘要:
            //     This method is called when the ShaderGUI is being closed.
            //
            // 参数:
            //   material:
            public virtual void OnClosed(Material material);
            //
            // 摘要:
            //     To define a custom shader GUI use the methods of materialEditor to render controls
            //     for the properties array.
            //
            // 参数:
            //   materialEditor:
            //     The MaterialEditor that are calling this OnGUI (the 'owner').
            //
            //   properties:
            //     Material properties of the current selected shader.
            public virtual void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties);
            public virtual void OnMaterialInteractivePreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background);
            //
            // 摘要:
            //     Override for extending the rendering of the Preview area or completly replace
            //     the preview (by not calling base.OnMaterialPreviewGUI).
            //
            // 参数:
            //   materialEditor:
            //     The MaterialEditor that are calling this method (the 'owner').
            //
            //   r:
            //     Preview rect.
            //
            //   background:
            //     Style for the background.
            public virtual void OnMaterialPreviewGUI(MaterialEditor materialEditor, Rect r, GUIStyle background);
            //
            // 摘要:
            //     Override for extending the functionality of the toolbar of the preview area or
            //     completly replace the toolbar by not calling base.OnMaterialPreviewSettingsGUI.
            //
            // 参数:
            //   materialEditor:
            //     The MaterialEditor that are calling this method (the 'owner').
            public virtual void OnMaterialPreviewSettingsGUI(MaterialEditor materialEditor);
        }
    }
    ```
    

而BaseShaderGUI在绘制这四个区域的位置在OnGUI这个函数下进行绘制，即如果觉得麻烦可以直接把所有的function都写在OnGUI里面就可以了。不过还是建议改BaseShaderGUI，因为里面有很多关键字它已经帮我们做好了。

- tips
    
    BaseShaderGUI（基础材质公用的一些特性，如静态模型）
    
    SomeMaterialGUI1(某种材质，如地形材质)
    
    ShadingModel1(某些光照模型，如PBR)
    
    ShadingModel2(某些光照模型，如Detial)
    
    SomeMaterialGUI1(某种材质，如PBR材质)
    
    ShadingModel3(某些光照模型，如Terrain)
    
    ShadingModel4(某些光照模型，如视差)
    
    SomeMaterialGUI2(某种材质，如不受光材质)
    
    ShadingModel5(某些光照模型，如自定义的一些着色模式)
    
    BaseShaderGUI2（基础材质公用的一些特性，如角色、粒子、VFX）
    
    结构同上
    
    BaseShaderGUI3（基础材质公用的一些特性，如角色、粒子、VFX）
    
    BaseShaderGUI 对应的是 `BaseShaderGUI`
    
    SomeMaterialGUI 对应的是 `LitShader`
    
    ShadingModel对应的是 `LitGUI`
    
    这里看这些文件的文件夹也能看得出来。
    

## 细节

首先看的是`FindProperties` 这个函数。

BaseShaderGUI的写法：

```csharp
public virtual void FindProperties(MaterialProperty[] properties)
        {
            surfaceTypeProp = FindProperty("_Surface", properties);
            blendModeProp = FindProperty("_Blend", properties);
            cullingProp = FindProperty("_Cull", properties);
            alphaClipProp = FindProperty("_AlphaClip", properties);
            alphaCutoffProp = FindProperty("_Cutoff", properties);
            receiveShadowsProp = FindProperty("_ReceiveShadows", properties, false);
            baseMapProp = FindProperty("_BaseMap", properties, false);
            baseColorProp = FindProperty("_BaseColor", properties, false);
            emissionMapProp = FindProperty("_EmissionMap", properties, false);
            emissionColorProp = FindProperty("_EmissionColor", properties, false);
            queueOffsetProp = FindProperty("_QueueOffset", properties, false);
        }
```

基本上这里的参数都是不更改的，因为大部分的材质都具备这些特性。

其中`_BaseMap` `_BaseColor` 这两个参数如果说不需要的话，可以复制上面的其他参数，然后重载掉。

LitShader的写法：

```csharp
public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            litProperties = new LitGUI.LitProperties(properties);
            litDetailProperties = new LitDetailGUI.LitProperties(properties);
        }
```

可以看出来它继承了base的做法，然后对于Litshader本身自带的一些属性（金属度、光滑度、贴图、细节等），它用了两个结构体去储存所有的这些需要用到的参数。

这样就可以把base和这个材质特有的参数区分开，避免出现指向同一个参数或重复绘制GUI的情况。

需要注意的是外部的类如果不是继承BaseShaderGUI可以使用下面这个方法来生成对应的材质属性

```csharp
BaseShaderGUI.FindProperty("_YourParamsName", properties, false);
```

---

然后我们先来看DrawSurfaceOptions这个函数。

BaseShaderGUI的写法：

```csharp
public virtual void DrawSurfaceOptions(Material material)
        {
            DoPopup(Styles.surfaceType, surfaceTypeProp, Enum.GetNames(typeof(SurfaceType)));
            if ((SurfaceType)material.GetFloat("_Surface") == SurfaceType.Transparent)
                DoPopup(Styles.blendingMode, blendModeProp, Enum.GetNames(typeof(BlendMode)));

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = cullingProp.hasMixedValue;
            var culling = (RenderFace)cullingProp.floatValue;
            culling = (RenderFace)EditorGUILayout.EnumPopup(Styles.cullingText, culling);
            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo(Styles.cullingText.text);
                cullingProp.floatValue = (float)culling;
                material.doubleSidedGI = (RenderFace)cullingProp.floatValue != RenderFace.Front;
            }

            EditorGUI.showMixedValue = false;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = alphaClipProp.hasMixedValue;
            var alphaClipEnabled = EditorGUILayout.Toggle(Styles.alphaClipText, alphaClipProp.floatValue == 1);
            if (EditorGUI.EndChangeCheck())
                alphaClipProp.floatValue = alphaClipEnabled ? 1 : 0;
            EditorGUI.showMixedValue = false;

            if (alphaClipProp.floatValue == 1)
                materialEditor.ShaderProperty(alphaCutoffProp, Styles.alphaClipThresholdText, 1);

            if (receiveShadowsProp != null)
            {
                EditorGUI.BeginChangeCheck();
                EditorGUI.showMixedValue = receiveShadowsProp.hasMixedValue;
                var receiveShadows =
                    EditorGUILayout.Toggle(Styles.receiveShadowText, receiveShadowsProp.floatValue == 1.0f);
                if (EditorGUI.EndChangeCheck())
                    receiveShadowsProp.floatValue = receiveShadows ? 1.0f : 0.0f;
                EditorGUI.showMixedValue = false;
            }
        }
```

这里的内容主要是关于SurfaceOption的，比如Opaque还是Transparent，还是AlphaClip。这里不建议去改，在我们自己的重载函数里面把这个继承了就可以了。因为大部分的材质都拥有这些特性。

这里有一种写法是这样的

```csharp
EditorGUI.BeginChangeCheck();
EditorGUI.showMixedValue = cullingProp.hasMixedValue;
var culling = (RenderFace)cullingProp.floatValue; //获取现在材质的参数值
culling = (RenderFace)EditorGUILayout.EnumPopup(Styles.cullingText, culling); //绘制GUI
//此时GUI的更改不会影响到原来材质的参数值
if (EditorGUI.EndChangeCheck()){  //更改完毕后赋值给材质参数
	materialEditor.RegisterPropertyChangeUndo(Styles.cullingText.text); //这个如果要写就照抄
	cullingProp.floatValue = (float)culling; 
	material.doubleSidedGI = (RenderFace)cullingProp.floatValue != RenderFace.Front; //材质的双面GI会根据我们是否渲染双面而受影响 这种属于隐藏参数，根据某些参数而动态变化
}
```

这个`EditorGUI.BeginChangeCheck()`的作用是用于保存和撤销的记录的。一般一头一尾用`EditorGUI.BeginChangeCheck()`和`if (EditorGUI.EndChangeCheck()){}`来包围着。`EditorGUILayout.EnumPopup(string,value)`可以制作类似于枚举的选项标签。然后我们在GUI生成和数值更改完毕后把GUI的数值赋值给材质属性。

LitShader的写法：

```csharp
public override void DrawSurfaceOptions(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            // Detect any changes to the material
            EditorGUI.BeginChangeCheck();
            if (litProperties.workflowMode != null)
            {
                DoPopup(LitGUI.Styles.workflowModeText, litProperties.workflowMode, Enum.GetNames(typeof(LitGUI.WorkflowMode)));
            }
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in blendModeProp.targets)
                    MaterialChanged((Material)obj);
            }
            base.DrawSurfaceOptions(material);
        }
```

可以看出来这里它也是继承了base的方法，然后自己进行拓展。这里主要是加入针对Metalic还是Specular的工作流。其中DoPopup这个方法是base的写法，我们可以直接拿来用。主要是针对不同模式切换生成的枚举。去看看源码就知道是怎么写的了。

同样我们发现它有一个函数叫`MaterialChanged` 这个是我们后面需要去重载的部分。这里简单提及一下，是去做ShaderFeature的生成的。这样我们可以针对某些参数来动态编译Shader，把不需要的部分去掉。

---

然后`DrawSurfaceInputs` 这个函数。

BaseShaderGUI的写法

```csharp
public virtual void DrawSurfaceInputs(Material material)
        {
            DrawBaseProperties(material);
        }
public virtual void DrawBaseProperties(Material material)
        {
            if (baseMapProp != null && baseColorProp != null) // Draw the baseMap, most shader will have at least a baseMap
            {
                materialEditor.TexturePropertySingleLine(Styles.baseMap, baseMapProp, baseColorProp);
                // TODO Temporary fix for lightmapping, to be replaced with attribute tag.
                if (material.HasProperty("_MainTex"))
                {
                    material.SetTexture("_MainTex", baseMapProp.textureValue);
                    var baseMapTiling = baseMapProp.textureScaleAndOffset;
                    material.SetTextureScale("_MainTex", new Vector2(baseMapTiling.x, baseMapTiling.y));
                    material.SetTextureOffset("_MainTex", new Vector2(baseMapTiling.z, baseMapTiling.w));
                }
            }
        }
```

这个函数主要就是用来画贴图”_MainTex”这个贴图的GUI。那么画一个基础贴图的GUI就是

```csharp
materialEditor.TexturePropertySingleLine(YOUR_GUI_CONTENT, TEXTURE, ADVANCED_OPTION);
```

ADVANCED_OPTION可以是颜色、Float、Range等。

而当我们想针对某个贴图增加tillingoffset的GUI的时候，我们只需要调用Base里面的这个函数就可以。

```csharp
protected static void DrawTileOffset(MaterialEditor materialEditor, MaterialProperty textureProp){
	materialEditor.TextureScaleOffsetProperty(textureProp);
}
```

LitShader的写法：

```csharp
public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            LitGUI.Inputs(litProperties, materialEditor, material);
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
        }
```

同样的也是继承。然后最后针对basemap做tillingoffset。因为一般情况下我们对UV进行tillingoffset的时候，针对的是所有的贴图，所以没有必要对所有的贴图都生成一个tillingoffset的GUI。

如果我们需要自发光的话，建议直接继承Base的做法，感兴趣的可以自己去看看里面是怎么写的。需要注意的是一般情况下自发光会带HDR的颜色，所以我们需要用一个叫`TexturePropertyWithHDRColor`的函数而非`TexturePropertySingleLine` 具体这些函数绘制出来的样例可以看官方的文档。这里不多赘述

- tips
    
    ![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%201.png)
    

然后我们来大略看看 `LitGUI.Inputs` 做了些什么。不看也可以，这个部分我们会在实战部分做一次。

首先这个LitGUI并非LitShader，而是把GUI绘制的逻辑部分单独分离出去作为了一个单独的类。与此对应的还有DetailGUI。

```csharp
public static void Inputs(LitProperties properties, MaterialEditor materialEditor, Material material)
        {
            DoMetallicSpecularArea(properties, materialEditor, material);
            BaseShaderGUI.DrawNormalArea(materialEditor, properties.bumpMapProp, properties.bumpScaleProp);

            if (HeightmapAvailable(material))
                DoHeightmapArea(properties, materialEditor);

            if (properties.occlusionMap != null)
            {
                materialEditor.TexturePropertySingleLine(Styles.occlusionText, properties.occlusionMap,
                    properties.occlusionMap.textureValue != null ? properties.occlusionStrength : null);
            }

            // Check that we have all the required properties for clear coat,
            // otherwise we will get null ref exception from MaterialEditor GUI helpers.
            if (ClearCoatAvailable(material))
                DoClearCoat(properties, materialEditor, material);
        }
```

看代码名就看得出来是绘制金属度光滑度、高度图、清漆等各自特性的GUI。其中里面的逻辑基本上和base的`DrawBaseProperties`一个意思。

---

`DrawAdvancedOptions` 

BaseShaderGUI：

```csharp
public virtual void DrawAdvancedOptions(Material material){
	materialEditor.EnableInstancingField();
	DrawQueueOffsetField();
}
```

这里建议直接继承。顾名思义这个是关于GPUINSTANCE和渲染队列的内容。当然如果说如果要对接美术的时候，我们可以把这个部分的GUI隐藏起来（但相关的设置仍然需要在脚本中启用，如某些特殊材质需要特殊的渲染队列的，我们可以把参数写死隐藏在材质里，避免美术误操作。）

LitShader：

```csharp
public override void DrawAdvancedOptions(Material material)
        {
            if (litProperties.reflections != null && litProperties.highlights != null)
            {
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(litProperties.highlights, LitGUI.Styles.highlightsText);
                materialEditor.ShaderProperty(litProperties.reflections, LitGUI.Styles.reflectionsText);
                if(EditorGUI.EndChangeCheck())
                {
                    MaterialChanged(material);
                }
            }

            base.DrawAdvancedOptions(material);
        }
```

LitShader的做法是多加了一些如反射、高光等选项的勾选。一般这个东西和反射探针、GI等有关系，如果说需要继承URP自带的光照模型的话，建议这个部分也保留。

---

`DrawAdditionalFoldouts`

BaseShaderGUI:

```csharp

```

Base是没写的，可以自行选择是否重载。调用的位置同样是在OnGUI。我们来看LitShader的

```csharp
public override void DrawAdditionalFoldouts(Material material)
        {
            m_DetailInputsFoldout.value = EditorGUILayout.BeginFoldoutHeaderGroup(m_DetailInputsFoldout.value, LitDetailGUI.Styles.detailInputs);
            if (m_DetailInputsFoldout.value)
            {
                LitDetailGUI.DoDetailArea(litDetailProperties, materialEditor);
                EditorGUILayout.Space();
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
        }
```

可以看出来它这里把细节的部分给弄进去了，也就是detialnormal之类的内容。

- tips
    
    需要注意的是这个`m_DetailInputsFoldout`，它是一个名叫`SavedBool`的自定义变量类型。但是当我们也引用这个数据类型的时候会因为protected level而报错（如果我们把自定义的editor写在外面的话，就会报错，写在里面就需要复制整个package然后作为自定义package来加载，否则packagecached会把我们添加的文件给删掉）。实际上这个东西只是用来记录GUI里面折叠的开关状态。经过测试用普通的bool也可以
    

---

`MaterialChanged` 这个函数是比较关键的，我们需要配合编辑器的GUI脚本来做变体Shader的操作。

启用关键字的操作有如下的这么些：

<aside>
💡 MultipleProgramVariants

- [Shader.EnableKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Shader.EnableKeyword.html): enable a global keyword
- [Shader.DisableKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Shader.DisableKeyword.html): disable a global keyword
- [CommandBuffer.EnableShaderKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Rendering.CommandBuffer.EnableShaderKeyword.html): use a `CommandBuffer` to enable a global keyword
- [CommandBuffer.DisableShaderKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Rendering.CommandBuffer.DisableShaderKeyword.html): use a `CommandBuffer` to disable a global keyword
- [Material.EnableKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Material.EnableKeyword.html): enable a local keyword for a regular shader
- [Material.DisableKeyword](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/Material.DisableKeyword.html): disable a local keyword for a regular shader
- [ComputeShader.EnableKeyword](https://docs.unity3d.com/2019.3/Documentation/Manual/ComputeShader.EnableKeyword): enable a local keyword for a compute shader
- [ComputeShader.DisableKeyword](https://docs.unity3d.com/2019.3/Documentation/Manual/ComputeShader.DisableKeyword): disable a local keyword for a compute shader
</aside>

- tips
    
    而Shader里面有两种关键字，一个是`multi_compile`，一个是`shader_feature` 而基于这两个变体则会有local和global。这里不过对赘述。异同可以看这里的描述：
    
    [Shader variants and keywords](https://docs.unity3d.com/2019.3/Documentation/Manual/SL-MultipleProgramVariants.html)
    

我们在ShaderGUI里面一般用的是CoreUtils.SetKeyword 或 Material.EnableKeyword

BaseShaderGUI是没有对这段函数进行任何操作的。我们直接看LitShader

```csharp
public override void MaterialChanged(Material material)
        {
            if (material == null)
                throw new ArgumentNullException("material");

            SetMaterialKeywords(material, LitGUI.SetMaterialKeywords, LitDetailGUI.SetMaterialKeywords);
        }
```

可以看到它调用了一个`SetMaterialKeywords`的函数

BaseShaderGUI：

```csharp
public static void SetMaterialKeywords(Material material, Action<Material> shadingModelFunc = null, Action<Material> shaderFunc = null)
        {
            // Clear all keywords for fresh start
            material.shaderKeywords = null;

            // Setup blending - consistent across all Universal RP shaders
            SetupMaterialBlendMode(material);

            // Receive Shadows
            if(material.HasProperty("_ReceiveShadows"))
                CoreUtils.SetKeyword(material, "_RECEIVE_SHADOWS_OFF", material.GetFloat("_ReceiveShadows") == 0.0f);

            // Emission
            if (material.HasProperty("_EmissionColor"))
                MaterialEditor.FixupEmissiveFlag(material);
            bool shouldEmissionBeEnabled =
                (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
            if (material.HasProperty("_EmissionEnabled") && !shouldEmissionBeEnabled)
                shouldEmissionBeEnabled = material.GetFloat("_EmissionEnabled") >= 0.5f;
            CoreUtils.SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);

            // Normal Map
            if (material.HasProperty("_BumpMap"))
                CoreUtils.SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap"));

            // Shader specific keyword functions
            shadingModelFunc?.Invoke(material);
            shaderFunc?.Invoke(material);
        }
```

这里的逻辑就是，如果含有某个参数，我们就判断这个参数是否为空或是否为某个数值，根据这个数值来设置关键字。如根据法线贴图是否为空来设置是否生成_NORMALMAP关键字。这可以使得材质没有法线贴图的时候直接用`float3(0,0,1)`来代替，从而节省性能。

当然也有一些别的特性，如是否启用视差等。然后同时这个函数提供了两个参数可以作为额外的action，也就是当base的关键字设置完毕后，我们可以自行设置我们自己的关键字。

## 实战

实战部分以一个最近复现的视差草论文做例子。具体这个Shader本身的算法另外再开坑。

这里只提及如何把我们需要的属性暴露在GUI和动态的去设置关键字。

先看一下需要用到的属性：

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%202.png)

如果我们不用自定义编辑器的情况下面板是长这样的：

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%203.png)

可以看到每个贴图都有tillingoffset，而且各个输入没有用标签分隔开。同时处于性能优化的原因，当一些贴图为空时我们希望不要进行采样的操作直接使用一个常量值来代替，从而对Shader做变体。

---

下面我们新建一个类，命名为GrassShader.cs。注意需要放在Editor目录下，和Runtime的文件分开。

和LitShader一样，我们使用相同的命名空间和继承BaseGUIShader

```csharp
namespace UnityEditor.Rendering.Universal.ShaderGUI
{
	internal class GrassShader : BaseShaderGUI{
		
	}
}
```

首先我们先重载`OnOpenGUI`这个函数，继承Base的方法

```csharp
public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
{
	base.OnOpenGUI(material, materialEditor);
}
```

然后重载`FindProperties` 由于我们没有BaseMap，但同时我们希望Base的一些其他方法为我们生成GUI，比如渲染队列，材质的透明等特性，所以我们直接复制Base的方法再进行修改，而不直接继承。

```csharp
public override void FindProperties(MaterialProperty[] properties)
{   
            surfaceTypeProp = FindProperty("_Surface", properties);
            blendModeProp = FindProperty("_Blend", properties);
            cullingProp = FindProperty("_Cull", properties);
            alphaClipProp = FindProperty("_AlphaClip", properties);
            alphaCutoffProp = FindProperty("_Cutoff", properties);
            receiveShadowsProp = FindProperty("_ReceiveShadows", properties, false);
            // baseMapProp = FindProperty("_BaseMap", properties, false); //我们没有baseMap 这个方法是在DrawBaseProperties调用的 但是我们没有调用这个方法 
            baseColorProp = FindProperty("_BaseColor", properties, false); 
            emissionMapProp = FindProperty("_EmissionMap", properties, false);
            emissionColorProp = FindProperty("_EmissionColor", properties, false);
            queueOffsetProp = FindProperty("_QueueOffset", properties, false);

}
```

然后我们先重载`DrawSurfaceOptions` 这个功能

```csharp
public override void DrawSurfaceOptions(Material material){
	if (material == null)
		throw new ArgumentNullException("material");
   base.DrawSurfaceOptions(material);
  }
```

然后我们仿造LitShader的做法，在这个函数里面对材质进行关键字刷新。

```csharp
public override void DrawSurfaceOptions(Material material){
            if (material == null)
                throw new ArgumentNullException("material");
            EditorGUIUtility.labelWidth = 0f;
            EditorGUI.BeginChangeCheck();
            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in blendModeProp.targets) //不知道为啥这里选的是blendMode的Object 难道说会有Shader是没有Blend的吗？
                    MaterialChanged((Material)obj);
            }
            base.DrawSurfaceOptions(material);
  }
```

我们只要等下重载关键字刷新的function就可以了。

然后找到`MaterialChanged`这个函数进行重载。

```csharp
public override void MaterialChanged(Material material){
	if (material == null)
      throw new ArgumentNullException("material");

           
}
```

由于上文提及了，写入关键字的操作一般伴随着贴图或者一些选项。我们首先对贴图进行这个操作。大体逻辑是当我们要把某个贴图的属性和关键字捆绑在一起，当贴图存在/不存在的时候，写入关键字。而在我们的自定义Shader中，如果没有分配法线贴图，直接对法线取float3(0,0,1)的操作。（LitShader也是这个操作，但是由于我们有三张法线贴图，所以需要单独分配关键字。）

```glsl
#ifdef _GROUNDNORMAL
        half4 samplegroundNormal = SAMPLE_TEXTURE2D(_GroundBumpMap, sampler_GroundBumpMap, uv);
        #if BUMP_SCALE_NOT_SUPPORTED
            half3 groundNormal = UnpackNormal(samplegroundNormal);
        #else //BUMP_SCALE_NOT_SUPPORTED
            half3 groundNormal = UnpackNormalScale(samplegroundNormal, scale);
        #endif
    #else //_GROUNDNORMAL
        half3 groundNormal = half3(0.0h, 0.0h, 1.0h);
    #endif
```

- tips
    
    同时我们还有BUMP_SCALE_NOT_SUPPORTED这个关键字，这个由BaseShaderGUI已经帮我们做了这件事。
    

刚提到我们有三张法线贴图，加上还没有设置的其他乱七八糟的属性。而我们的shader属性到目前为止这些都是原先LitShader或者基础Shader里面自带的一些属性。在重载`MaterialChanged` 之前，我们需要像LitShader一样，拓展一个名叫XXGUI.cs的脚本，专门来管理我们自定义Shader的属性。

新建或者在同一个命名空间下新建一个类，然后把我们所有的自定义属性的内容都加上去（不用纠结这些属性的内容，到时候关于这个Shader的新坑我会再开）

```csharp
internal class GrassProperty{
#region matpro
        public MaterialProperty bumpScaleProp;
        public MaterialProperty occlusionStrength;
        public MaterialProperty occlusionMap;
        public MaterialProperty highlights;
        public MaterialProperty reflections;
        public MaterialProperty groundMapProp;
        public MaterialProperty sliceMapProp;
        public MaterialProperty lookUpMapProp;
        public MaterialProperty metallicMap;
        public MaterialProperty roughnessMap;
        public MaterialProperty groundNormalMapProp;
        public MaterialProperty sliceNormalMapProp;
        public MaterialProperty LookupNormalMapProp;
        public MaterialProperty baseColorProp;
        public MaterialProperty zlerpProp;
        public MaterialProperty shadowFactorProp;
        public MaterialProperty shadowBlurProp;
        public MaterialProperty shadowColorProp;
        public MaterialProperty windMapProp;
        public MaterialProperty GRASSGRIDProp;
        public MaterialProperty zOffsetFactorProp;
        public MaterialProperty selfShadowProp;
        public MaterialProperty windSpeedProp;
  #endregion
}
```

然后我们需要在我们的GrassShader里面实例化我们新建的这个GrassProperty的类，同时在`FindProperties`中初始化所有GrassProperty的`MaterialProperty`  成员。

```glsl
public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
{
	base.OnOpenGUI(material, materialEditor);
	if(grassProperty==null){
		GrassProperty grassProperty = new GrassProperty ();
  }
}
public override void FindProperties(MaterialProperty[] properties)
{   
		//刚刚写的功能保留
		grassProperty.groundNormalMapProp= FindProperty("_GroundBumpMap", properties, false);
		//其他属性也一并写入

}
```

当然我们也可以把写入属性像LitGUI一样单独分离出来一个function，作为`GrassProperty`  的方法

```glsl
public void GetGrassProperties(MaterialProperty[] properties){
	groundMapProp = BaseShaderGUI.FindProperty("_GroundBumpMap", properties, false)
//其他属性也一并写入
}
public override void FindProperties(MaterialProperty[] properties)
{   
   //刚刚的功能

	  grassProperty.GetLitProperties(properties);//这个是原本lit shader里面的东西
	  grassProperty.GetGrassProperties(properties);//这个是我们自定义的属性
            
}
```

那么当我们维护的时候就单独维护`GrassProperty`  下的方法就可以了。

然后我们尝试重载`MaterialChanged` 这个函数。之前提到过`SetMaterialKeywords`函数Base默认提供了两个参数可以作为额外的Action去拓展。那我们在`GrassProperty`  下拓展一个专门写入关键字的方法，然后作为参数传给Base的`SetMaterialKeywords`

```glsl
public override void MaterialChanged(Material material){
    if (material == null)
      throw new ArgumentNullException("material");
			SetMaterialKeywords(material, grassProperty.SetMaterialKeywords);
}
```

`GrassProperty.SetMaterialKeywords`

```glsl
public void SetMaterialKeywords(Material material){
	if(material.HasProperty("_GroundBumpMap")){
    CoreUtils.SetKeyword(material, "_GROUNDNORMAL", material.GetTexture(_GroundBumpMap));
  }
}

```

此时如果我们如果赋予了材质的法线贴图，我们可以发现材质已经启用了“_GROUNDNORMAL”这个关键字。具体可以在这里看

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%204.png)

同时Shader文件中也必须有`#pragma shader_feature_local _GROUNDNORMAL` ，否则可能会看到有关键字但是实际编译中没有变体的情况。

- tips
    
    如果启用了都没有变化，退出客户端重新进入一下。
    

但是这样一行一行写太麻烦了，如果说只有贴图存在的情况下关键字才生效，那么我们可以用一个字典来管理贴图名称和关键字，当贴图存在时，我们才写入关键字。所以我们继续拓展`GrassProperty`  的方法，为它添加一个mapKeys的成员，在初始化的时候把我们捆绑的键值写入到字典。

```glsl
public Dictionary<string,string> mapKeys{get;set;} //成员

public GrassProperty(Dictionary<string,string> _mapkeys){
            mapKeys = _mapkeys;
            GrassAdvancedOptionFoldOut = true;
        }
public void generateMapKeyWord(string _mapName,string _keyword,Material material){
            if (material.HasProperty(_mapName)){
                CoreUtils.SetKeyword(material, _keyword, material.GetTexture(_mapName));
            }
}
public void setAllmapKeys(Material material){
    foreach (string keyword in mapKeys.Keys)
    {
        generateMapKeyWord(keyword,mapKeys[keyword],material);
      }
}
```

然后为`GrassShader` 添加一个`InitGrassProperty` 的方法

```glsl
public void InitGrassProperty(){
    Dictionary<string,string> mapKeys = new Dictionary<string,string>();
    mapKeys["_GroundBumpMap"] = "_GROUNDNORMAL";
    mapKeys["_SliceBumpMap"] = "_SLICENORMAL";
    mapKeys["_LookupBumpMap"] = "_LOOKUPNORMAL";
    mapKeys["_MetallicMap"] = "_METALLICMAP";
    mapKeys["_RoughnessMap"] = "_ROUGHNESSMAP";
    mapKeys["_EmissionMap"] = "_EMISSIONMAP";
    mapKeys["_OcclusionMap"] = "_OCCLUSIONMAP";
    grassProperty = new GrassProperty(mapKeys);
        
}
```

这个部分可以做成一个GUI控件，然后生成一个Json或者序列化之类的东西，就不用写在代码里面了。这样当我们自定义Shader需要自定义关键字的时候，就可以直接在面板里面输入材质参数名和对应的关键字，这样GUI就可以对应的生成。

最后我们修改一下`SetMaterialKeywords` ，把我们刚刚封装的方法写进去

```glsl
public void SetMaterialKeywords(Material material)
{
            setAllmapKeys(material);
}
```

这样我们就搞定了所有跟贴图相关的关键字写入（比如金属贴图、光滑贴图、自发光贴图等对应的关键字）。

然后我们把这些贴图的属性暴露在GUI面板，回到GrassShader，对`DrawSurfaceInputs` 进行重载

```glsl
public override void DrawSurfaceInputs(Material material)
{
     // base.DrawSurfaceInputs(material); //这个没啥卵用 我们没有basemap了 我们把绘制所有贴图的东西都写在下面就可以了
   
    DrawEmissionProperties(material, true);//MRE
    DrawTileOffset(materialEditor, grassProperty.groundMapProp); 
            
}
```

由于我们的自定义草的tillingoffset只对其中一个贴图生效，所以我们的`DrawTileOffset` 的对象是groundMapProp（对应的就是_MainTex），这样当我们修改tillingoffset的时候，我们的_GroundMap_ST就会对应的受到修改。同时自发光这个部分比较复杂，直接继承Base的做法（就算我们自己写也是同样的方法，所以这里就不重载了）

然后我们写一个 `GrassProperty.Inputs(materialEditor, material)`的方法，专门管理所有的贴图的输入。

```glsl
public void Inputs(MaterialEditor materialEditor, Material material)
{   
    DoAlbedoMap(materialEditor,material);
    DoMREArea(materialEditor, material);
    DoNormalMap(materialEditor,bumpScaleProp);
    DoAO(materialEditor);

}
```

这里我采用JX3的方法，用的MRE工作流，把几个贴图分成几个函数分别来处理。

首先先新建一个`Styles` 统一管理我们所有的GUI的内容。

```glsl
public static class Styles{
            public static readonly GUIContent GrassAdvancedOption = new GUIContent("Grass Advanced Option","Generally Only Do Once");
            public static readonly GUIContent sliceMap = new GUIContent("Slice Map","");
            public static readonly GUIContent GroundMap = new GUIContent("Ground Map","");
            public static readonly GUIContent LookUpMap = new GUIContent("LookUp Map","");
            public static readonly GUIContent windMap = new GUIContent("wind noise Map","R for U,G for V");
            //照搬的LitGui 因为这些参数是我们要保留的
            public static GUIContent highlightsText = new GUIContent("Specular Highlights","When enabled, the Material reflects the shine from direct lighting.");
            public static GUIContent reflectionsText = new GUIContent("Environment Reflections","When enabled, the Material samples reflections from the nearest Reflection Probes or Lighting Probe.");
            //照搬的LitGui 因为这些参数是我们要保留的
            public static GUIContent metallicMapText = new GUIContent("Metalic","R for Ground,G for Slice,B for LookUp");
            public static GUIContent roughnessMapText = new GUIContent("Roughness","R for Ground,G for Slice,B for LookUp");
            public static readonly GUIContent GroundnormalMapText = new GUIContent("Ground Normal Map", "Assigns a tangent-space normal map.");
            public static readonly GUIContent SlicenormalMapText = new GUIContent("Slice Normal Map", "Assigns a tangent-space normal map.");
            public static readonly GUIContent LookupnormalMapText = new GUIContent("Lookup Normal Map", "Assigns a tangent-space normal map.");

            public static readonly GUIContent fixNormalNow = new GUIContent("Fix now", "Converts the assigned texture to be a normal map format.");
            public static readonly GUIContent bumpScaleNotSupported = new GUIContent("Bump scale is not supported on mobile platforms");
            public static readonly GUIContent occlusionText = new GUIContent("Occlusion","R for Ground,G for Slice,B for LookUp");
            public static readonly GUIContent zlerpText = new GUIContent("tilt grid","tilt grid by tangent view z");
            public static readonly GUIContent shadowFactorText = new GUIContent("shadow fix factor","Adjust how dark the Shadow");
            public static readonly GUIContent shadowBlurText = new GUIContent("Shadow Blur","Blur the Shadow");
            public static readonly GUIContent shadowColorText = new GUIContent("Shadow Color Fixed","fixed a bit shadow grey scale");
            public static readonly GUIContent grassgridText = new GUIContent("Grass Slice Amount","Per U and V");
            public static readonly GUIContent zoffsetFactorText = new GUIContent("depth Offset","Adjustt how the depth offset");
            public static readonly GUIContent selfShadowText = new GUIContent("self shadow","when enable, may effect performance");
            public static readonly GUIContent windSpeedText = new GUIContent("Wind Speed","");
        }
```

Albedo：

```glsl
public void DoAlbedoMap(MaterialEditor materialEditor,Material material) //这个baseColorProp是BaseShaderGUI的类 
{
    if (groundMapProp != null) 
        materialEditor.TexturePropertySingleLine(Styles.GroundMap, groundMapProp, baseColorProp);
    }
    if (sliceMapProp != null) 
    {   
        materialEditor.TexturePropertySingleLine(Styles.sliceMap, sliceMapProp, baseColorProp);
    }
    if (lookUpMapProp != null)
    {
        materialEditor.TexturePropertySingleLine(Styles.LookUpMap, lookUpMapProp, baseColorProp);
    }
  }
```

MR（E用的Base的方法，因为参数名都一样的，所以都不用改了）

```glsl
public void DoMREArea( MaterialEditor materialEditor, Material material)
	{
	  materialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap); //我们只有金属度贴图 不能整体调整金属度的属性（草没有金属度 就算有也要用调图来整体调整）
	  materialEditor.TexturePropertySingleLine( Styles.roughnessMapText, roughnessMap);    
   }
```

Normal：

- tips
    
    发现需要注意的是，我们需要对传输的法线贴图进行检测，如果传进去的法线不是法线格式，我们需要提示是否修复。Unity提供了这个功能。需要注意在Shader里面对贴图标注一下`[Normal]`
    
    ```glsl
    [Normal]_GroundBumpMap("Normal Map", 2D) = "bump" {}
    ```
    

```glsl
public void DoNormalMap(MaterialEditor materialEditor, MaterialProperty bumpMapScale = null)
        {
            if (bumpMapScale != null)
            {
                materialEditor.TexturePropertySingleLine(Styles.GroundnormalMapText, groundNormalMapProp, groundNormalMapProp.textureValue != null ? bumpMapScale : null);
                if (bumpMapScale.floatValue != 1 && UnityEditorInternal.InternalEditorUtility.IsMobilePlatform(EditorUserBuildSettings.activeBuildTarget))
                    if (materialEditor.HelpBoxWithButton(Styles.bumpScaleNotSupported, Styles.fixNormalNow))
                        bumpMapScale.floatValue = 1;

                materialEditor.TexturePropertySingleLine(Styles.SlicenormalMapText, sliceNormalMapProp, sliceNormalMapProp.textureValue != null ? bumpMapScale : null);
                if (bumpMapScale.floatValue != 1 && UnityEditorInternal.InternalEditorUtility.IsMobilePlatform(EditorUserBuildSettings.activeBuildTarget))
                    if (materialEditor.HelpBoxWithButton(Styles.bumpScaleNotSupported, Styles.fixNormalNow))
                        bumpMapScale.floatValue = 1;

                materialEditor.TexturePropertySingleLine(Styles.LookupnormalMapText, LookupNormalMapProp, LookupNormalMapProp.textureValue != null ? bumpMapScale : null);
                if (bumpMapScale.floatValue != 1 && UnityEditorInternal.InternalEditorUtility.IsMobilePlatform(EditorUserBuildSettings.activeBuildTarget))
                    if (materialEditor.HelpBoxWithButton(Styles.bumpScaleNotSupported, Styles.fixNormalNow))
                        bumpMapScale.floatValue = 1;
                
            }
            else
            {
                materialEditor.TexturePropertySingleLine(Styles.GroundnormalMapText, groundNormalMapProp);
                materialEditor.TexturePropertySingleLine(Styles.SlicenormalMapText, sliceNormalMapProp);
                materialEditor.TexturePropertySingleLine(Styles.LookupnormalMapText, LookupNormalMapProp);
            }
        }
```

至此我们就有了自定义的SurcaeInput了

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%205.png)

`DrawAdvancedOptions` 

```glsl
public override void DrawAdvancedOptions(Material material)
        {
            if (grassProperty.reflections != null && grassProperty.highlights != null)
            {
                EditorGUI.BeginChangeCheck();
                //materialEditor.ShaderProperty(grassProperty.highlights, GrassProperty.Styles.highlightsText);
                materialEditor.ShaderProperty(grassProperty.reflections, GrassProperty.Styles.reflectionsText);
                if(EditorGUI.EndChangeCheck())
                {
                    MaterialChanged(material);
                }
            }

            base.DrawAdvancedOptions(material)
        }
```

这个部分基本上和Lit的保持一致，直接复制过来就好了。因为我们的shader没有specular的工作流，所以把highlights的部分关掉。

`DrawAdditionalFoldouts`

我们给Grass的其他自定义属性分配在Addition的GUI，这个对应的是Lit的Deail的部分。

```glsl
public override void DrawAdditionalFoldouts(Material material)
{   
    grassProperty.DrawExtraOption(materialEditor);
}
```

和贴图一样，我们调用materialEditor的方法，针对类似于float、ToggleOff之类的GUI，都可以使用

 `materialEditor.ShaderProperty` 方法实现

```glsl
public void DrawExtraOption(MaterialEditor materialEditor){

            GrassAdvancedOptionFoldOut = EditorGUILayout.BeginFoldoutHeaderGroup(GrassAdvancedOptionFoldOut, GrassProperty.Styles.GrassAdvancedOption);
            if (GrassAdvancedOptionFoldOut)
            {   
                materialEditor.ShaderProperty(zlerpProp, Styles.zlerpText);
                materialEditor.ShaderProperty(shadowFactorProp, Styles.shadowFactorText);
                materialEditor.ShaderProperty(shadowBlurProp, Styles.shadowBlurText);
                materialEditor.ColorProperty(shadowColorProp,"Shadow Color Fixed");
                materialEditor.ShaderProperty(GRASSGRIDProp,Styles.grassgridText);
                materialEditor.ShaderProperty(zOffsetFactorProp,Styles.zoffsetFactorText);
                materialEditor.ShaderProperty(selfShadowProp,Styles.selfShadowText);
                materialEditor.ShaderProperty(windSpeedProp,Styles.windSpeedText);
                
                // EditorGUILayout.Space();
                if(windMapProp!=null){
                    materialEditor.TexturePropertySingleLine(Styles.LookUpMap, windMapProp);
                }
            }

            EditorGUILayout.EndFoldoutHeaderGroup();
        }
```

同样的我们为体积草提供了一个自阴影的关键字选项，我们回到`setAllmapKeys`方法 添加一个针对自阴影选项的开关。

```glsl
public void setAllmapKeys(Material material){
		//保留刚刚的方法
    if(material.HasProperty("_SelfShadow")){
        CoreUtils.SetKeyword(material, "_GRASSSELFSHDOW", material.GetFloat("_SelfShadow") == 1.0f);
    }
}
```

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%206.png)

至此我们所有的材质GUI面板就自定义完毕了

![Untitled](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Untitled%207.png)

最后附带几个源文件作为参考。 后续会上传到Github。

[GrassShader.cs](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/GrassShader.cs)

[Grass.shader](Unity%E6%9D%90%E8%B4%A8%E9%AD%94%E6%94%B9%E5%AE%9E%E6%88%98%E6%8C%87%E5%8D%97%20a85e315503bb4b9cba6f7af0af1e62e4/Grass.shader)

这个Shader其他的引用文件并没有上传，留作下一个新坑开的时候再说。这里提供一个外壳供参考用到的参数

# Shader篇（WIP）

下文以这个材质为例进行修改

[-ShaderLab/草地 at main · waihinchan/-ShaderLab](https://github.com/waihinchan/-ShaderLab/tree/main/%E8%8D%89%E5%9C%B0)