using System;
using UnityEngine;
using System.Collections.Generic;//Dictionary 
using UnityEngine.Rendering; //coreutils 
using UnityEditor.Rendering.Universal;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{   

    internal class GrassShader : BaseShaderGUI
    {   
        
        private GrassProperty grassProperty;
        // private SavedBool GrassAdvancedOptionFoldOut;
        public override void OnOpenGUI(Material material, MaterialEditor materialEditor)
        {
            base.OnOpenGUI(material, materialEditor);
            if(grassProperty==null){
                //TODO：
                //后面把这个鬼东西做成一个配置表之类的 搞个GUI来控制
                InitGrassProperty();
            } 

        }
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
        public override void DrawAdditionalFoldouts(Material material)
        {   
            grassProperty.DrawExtraOption(materialEditor);

        }
        
        /// <summary>
        /// 这个类似于我们上面的字典 但是其实是没办法找到属性对应的关键字 我们这里直接复制baseGui的设置
        /// 我们有一些类似的属性是直接给锁死的
        /// OnGUI会自动调用这个函数 所以要保证OnOpenGUI的时候正确初始化了grassProperty（其实如果一股脑把东西写进来这个类里面也可以的）
        /// </summary>
        /// <param name="properties"></param>
        public override void FindProperties(MaterialProperty[] properties)
        {   
           
            surfaceTypeProp = FindProperty("_Surface", properties);
            blendModeProp = FindProperty("_Blend", properties);
            cullingProp = FindProperty("_Cull", properties);
            alphaClipProp = FindProperty("_AlphaClip", properties);
            alphaCutoffProp = FindProperty("_Cutoff", properties);
            receiveShadowsProp = FindProperty("_ReceiveShadows", properties, false);
            // baseMapProp = FindProperty("_BaseMap", properties, false); //我们没有baseMap 这个方法是在DrawBaseProperties调用的 但是我们没有调用这个方法 
            // baseColorProp = FindProperty("_BaseColor", properties, false); //这个在Grass里面了
            emissionMapProp = FindProperty("_EmissionMap", properties, false);
            emissionColorProp = FindProperty("_EmissionColor", properties, false);
            queueOffsetProp = FindProperty("_QueueOffset", properties, false);
           
           
            if(grassProperty==null){
                InitGrassProperty();
                
            }

            grassProperty.GetLitProperties(properties);//这个是原本lit shader里面的东西
            grassProperty.GetGrassProperties(properties);//这个是我们自定义的属性
            
        }

        /// <summary>
        /// 用的是BaseShaderGUI的方法 自己重新写一个或者用他的Action来拓展也可以
        /// 需要注意的是_ReceiveShadows/_EmissionColor/_BumpMap都是内置的属性
        /// 我在这里保留了_ReceiveShadows和_EmissionColor
        /// 而BumpMap的变量名在Shader里面设置为了_GroundBumpMap/_SliceBumpMap/_LookupBumpMap
        /// </summary>
        /// <param name="material">材质就是材质这个不用管直接写就是了</param>
        public override void MaterialChanged(Material material){
            if (material == null)
                throw new ArgumentNullException("material");

            SetMaterialKeywords(material, grassProperty.SetMaterialKeywords);
        }
        /// <summary>
        /// 这里有个do_group的workflow 我们不做这个 我们就是MRE的流程 这个东西没有必要做 因为流程定了就是这样的了 不再需要去搞什么乱七八糟的流程切换
        /// </summary>
        /// <param name="material"></param>
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
        /// <summary>
        /// DrawSurfaceInputs调用的是DrawBaseProperties的方法 因为我们的BaseMap不叫baseMap 所以干脆直接重载 不用他那个傻逼方法了）
        /// </summary>
        /// <param name="material"></param>
        public override void DrawSurfaceInputs(Material material)
        {
            // base.DrawSurfaceInputs(material); //这个没啥卵用 我们没有basemap了 我们把绘制所有贴图的东西都写在下面就可以了
            grassProperty.Inputs(materialEditor, material);
            DrawEmissionProperties(material, true);//MRE
            DrawTileOffset(materialEditor, grassProperty.groundMapProp); //这个我们针对Ground的map来做tilling(Grass的部分比较复杂 WIP)
            // DrawTileOffset(materialEditor, grassProperty.groundMapProp); //这个我们针对Ground的map来做tilling(Grass的部分比较复杂 WIP)
        }
        /// <summary>
        /// 这里基本上是保留的Lit的做法 刨除了不需要的参数 但是类似于reflection之类的东西我们还是需要的 就保留进来这里
        /// </summary>
        /// <param name="material"></param>
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

            base.DrawAdvancedOptions(material); //base的Advanced主要的内容是queue之类的可以直接拿来用。而上面的highlights我们就要继承 直接抄过来好了
        }
        /// <summary>
        /// 这个我们就不写了 因为我们的贴图名字和其他的根本就不同的 没什么意义
        /// 就简单把keyword清空完事
        /// </summary>
        /// <param name="material"></param>
        /// <param name="oldShader"></param>
        /// <param name="newShader"></param>
        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader){
            if (material == null)
                throw new ArgumentNullException("material");
            material.shaderKeywords = null;
            Debug.Log($"please create material from grass shader!");
        } 

    }
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
        public MaterialProperty GrassHeightProp;
        public MaterialProperty BlendGroundProp;
        public MaterialProperty TileMapProp;
        #endregion
        public bool GrassAdvancedOptionFoldOut{get;set;}
        

        /// <summary>
        /// 本来这个东西是不想加进去的 但是里面有一些东西是我们没有改过那个Shader而且还要用到的（GI 反射之类的）
        /// 所以直接用这个东西来存 名字还是叫LitProperties因为这里只包含Lit原有的一些东西
        /// 但是我这里就不用结构体了直接给一个成员变量就完事了 不然真的是套娃套得太多了（这里因为是函数名字多了个Get）
        /// 看注释可以看到我屏蔽了哪些内容
        /// </summary>
        /// <param name="properties">GrassShader的FindProperties传送参数的</param>
        public void GetLitProperties(MaterialProperty[] properties){//
                // Surface Option Props
                // workflowMode = BaseShaderGUI.FindProperty("_WorkflowMode", properties, false);
                // Surface Input Props
                // metallic = BaseShaderGUI.FindProperty("_Metallic", properties);
                // specColor = BaseShaderGUI.FindProperty("_SpecColor", properties, false);
                // metallicGlossMap = BaseShaderGUI.FindProperty("_MetallicGlossMap", properties);
                // specGlossMap = BaseShaderGUI.FindProperty("_SpecGlossMap", properties, false);
                // smoothness = BaseShaderGUI.FindProperty("_Smoothness", properties, false);
                // smoothnessMapChannel = BaseShaderGUI.FindProperty("_SmoothnessTextureChannel", properties, false);
                // bumpMapProp = BaseShaderGUI.FindProperty("_BumpMap", properties, false);
                bumpScaleProp = BaseShaderGUI.FindProperty("_BumpScale", properties, false);
                // parallaxMapProp = BaseShaderGUI.FindProperty("_ParallaxMap", properties, false);
                // parallaxScaleProp = BaseShaderGUI.FindProperty("_Parallax", properties, false);
                occlusionStrength = BaseShaderGUI.FindProperty("_OcclusionStrength", properties, false);
                occlusionMap = BaseShaderGUI.FindProperty("_OcclusionMap", properties, false);
                // Advanced Props
                highlights = BaseShaderGUI.FindProperty("_SpecularHighlights", properties, false);
                reflections = BaseShaderGUI.FindProperty("_EnvironmentReflections", properties, false);
                // clearCoat           = BaseShaderGUI.FindProperty("_ClearCoat", properties, false);
                // clearCoatMap        = BaseShaderGUI.FindProperty("_ClearCoatMap", properties, false);
                // clearCoatMask       = BaseShaderGUI.FindProperty("_ClearCoatMask", properties, false);
                // clearCoatSmoothness = BaseShaderGUI.FindProperty("_ClearCoatSmoothness", properties, false);
                
        }
        public void GetGrassProperties(MaterialProperty[] properties){
            groundMapProp = BaseShaderGUI.FindProperty("_GroundMap", properties, false);
            sliceMapProp = BaseShaderGUI.FindProperty("_GrassBlade", properties, false);
            lookUpMapProp = BaseShaderGUI.FindProperty("_LookUpTex", properties, false);
            metallicMap = BaseShaderGUI.FindProperty("_MetallicMap", properties);
            roughnessMap = BaseShaderGUI.FindProperty("_RoughnessMap", properties);
            ///Emission在上面
            groundNormalMapProp = BaseShaderGUI.FindProperty("_GroundBumpMap", properties, false);
            sliceNormalMapProp = BaseShaderGUI.FindProperty("_SliceBumpMap", properties, false);
            LookupNormalMapProp = BaseShaderGUI.FindProperty("_LookupBumpMap", properties, false);
            baseColorProp = BaseShaderGUI.FindProperty("_BaseColor", properties, false); //这个是BaseShaderGUI的 但是我不想额外传一个参数 所以这里重复获取一下。
            zlerpProp =  BaseShaderGUI.FindProperty("_Zlerp", properties, false);
            shadowFactorProp = BaseShaderGUI.FindProperty("_ShadowFactor", properties, false);
            shadowBlurProp = BaseShaderGUI.FindProperty("_k", properties, false);
            shadowColorProp = BaseShaderGUI.FindProperty("_ShadowColor", properties, false);
            windMapProp = BaseShaderGUI.FindProperty("_Windnoise", properties, false);
            GRASSGRIDProp = BaseShaderGUI.FindProperty("_gridPerUnit",properties,false);
            zOffsetFactorProp = BaseShaderGUI.FindProperty("_ZoffsetFactor",properties,false);
            selfShadowProp = BaseShaderGUI.FindProperty("_SelfShadow",properties,false);
            windSpeedProp = BaseShaderGUI.FindProperty("_WindSpeed",properties,false);
            GrassHeightProp = BaseShaderGUI.FindProperty("_GrassHeight",properties,false);
            BlendGroundProp = BaseShaderGUI.FindProperty("_BlendGoundFactor",properties,false);
            TileMapProp = BaseShaderGUI.FindProperty("_TileMap",properties,false);
        }
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
            public static readonly GUIContent GrassHeightText = new GUIContent("Grass Height","Higher value Lower");
            public static readonly GUIContent BlendGroundText = new GUIContent("Blend Ground Factor","");
            public static readonly GUIContent TileMapText = new GUIContent("tile map","");
            
        }

        #region customExtentsion
        public Dictionary<string,string> mapKeys{get;set;}
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
            if(material.HasProperty("_SelfShadow")){

                CoreUtils.SetKeyword(material, "_GRASSSELFSHDOW", material.GetFloat("_SelfShadow") == 1.0f);
                
            }


            
            // GRASSSELFSHDOW
        }
        public void SetMaterialKeywords(Material material)
        {
            setAllmapKeys(material);
        }
        #endregion

        #region drawGUI STUFF
        public void DoAlbedoMap(MaterialEditor materialEditor,Material material) //这个baseColorProp是BaseShaderGUI的类 
        {
            if (groundMapProp != null) // Draw the baseMap, most shader will have at least a baseMap
            {
                materialEditor.TexturePropertySingleLine(Styles.GroundMap, groundMapProp, baseColorProp);
            }
            if (sliceMapProp != null) // Draw the baseMap, most shader will have at least a baseMap
            {   
                materialEditor.TexturePropertySingleLine(Styles.sliceMap, sliceMapProp, baseColorProp);
            }
            if (lookUpMapProp != null) // Draw the baseMap, most shader will have at least a baseMap
            {
                materialEditor.TexturePropertySingleLine(Styles.LookUpMap, lookUpMapProp, baseColorProp);
            }
        }
        /// <summary>
        /// 这个是绘制MRE贴图的区域 我们有三张MRE（grass ground lookup）
        /// </summary>
        /// <param name="properties"></param>
        /// <param name="materialEditor"></param>
        /// <param name="material"></param>
        public void DoMREArea( MaterialEditor materialEditor, Material material)
        {

            materialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap); //我们只有金属度贴图 不能整体调整金属度的属性（草没有金属度 就算有也要用调图来整体调整）
            // EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine( Styles.roughnessMapText, roughnessMap); //我们只有金属度贴图 不能整体调整金属度的属性（草没有金属度 就算有也要用调图来整体调整）
            // EditorGUI.indentLevel--;
           
            
        }
        /// <summary>
        /// copy from baseGUI DrawNormalArea
        /// </summary>
        /// <param name="materialEditor"></param>
        /// <param name="bumpMap"></param>
        /// <param name="bumpMapScale"></param>
        public void DoNormalMap(MaterialEditor materialEditor, MaterialProperty bumpMapScale = null)
        {
            if (bumpMapScale != null)
            {   
                // materialEditor.TextureCompatibilityWarning(groundNormalMapProp);
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
        public void DoAO(MaterialEditor materialEditor){
            if (occlusionMap != null)
            {
                materialEditor.TexturePropertySingleLine(Styles.occlusionText, occlusionMap,
                    occlusionMap.textureValue != null ? occlusionStrength : null);
            }
        }
        public void DrawExtraOption(MaterialEditor materialEditor){

            //这个是用MaterialEditor自带的ShaderProperty方法 这个好处是如果他原来是Range这里就是Range 如果是toggle这里就是toggle
            //也可以使用EditorGUILayout.IntSlider之类的方法 记得要把数值赋值给材质的属性如matProp.floatValue = sliderValue;
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
                materialEditor.ShaderProperty(GrassHeightProp,Styles.GrassHeightText);
                materialEditor.ShaderProperty(BlendGroundProp,Styles.BlendGroundText);
                materialEditor.TexturePropertySingleLine(Styles.TileMapText, TileMapProp);
                // EditorGUILayout.Space();
                if(windMapProp!=null){
                    materialEditor.TexturePropertySingleLine(Styles.LookUpMap, windMapProp);
                }
            }

            EditorGUILayout.EndFoldoutHeaderGroup();
        }
        public void Inputs(MaterialEditor materialEditor, Material material)
        {   
            DoAlbedoMap(materialEditor,material);
            DoMREArea(materialEditor, material);
            DoNormalMap(materialEditor,bumpScaleProp);
            DoAO(materialEditor);

        }
        #endregion
    }
}
