using UnityEditor;
using UnityEngine;
using System.IO; 

public class GenerateLUTforSSS : ScriptableWizard
{
    public int width = 512; 
    public int height = 512;
    public float inc = 0.05f;
    public string filename = "SSS_LUT";
    public bool halfPI = false;
    [MenuItem ("Texture/SSS_LUT")]
    static void CreateWizard () {
        ScriptableWizard.DisplayWizard("Create the SSS lut texture",typeof(GenerateLUTforSSS),"Create");
    }
    Vector3 GetDiffuse(float ndotl, float r){
        float theta = Mathf.Acos(ndotl); 
        Vector3 totalWeights = Vector3.zero;
        Vector3 totalLight = Vector3.zero;
        float half;
        if(halfPI){
             half = 2.0f;
        }
        else{
             half = 1.0f;
        }
        float startAngle = -(Mathf.PI/half); 
        while (startAngle<=Mathf.PI/half)
        {
            float sampleAngle = theta + startAngle;
            float diffuse = Mathf.Clamp01( Mathf.Cos(sampleAngle) );
            float sampleDist = Mathf.Abs( 2.0f * r * Mathf.Sin(startAngle * 0.5f) );
            Vector3 weights = Scatter(sampleDist);
            totalWeights += weights;
            totalLight += diffuse * weights;
            startAngle+=inc;
        }
        Vector3 result = new Vector3(totalLight.x / totalWeights.x, totalLight.y / totalWeights.y, totalLight.z / totalWeights.z);
        return result;
    }
    
    float Gaussian(float v , float r){
        return 1.0f / Mathf.Sqrt(2.0f * Mathf.PI * v) * Mathf.Exp( -(r * r) / (2 * v) ); 
    }
    Vector3 Scatter( float r){
            return Gaussian(0.0064f * 1.414f, r) * new Vector3(0.233f, 0.455f, 0.649f) 
            + Gaussian(0.0484f * 1.414f, r) * new Vector3(0.100f, 0.336f, 0.344f)
            + Gaussian(0.1870f * 1.414f, r) * new Vector3(0.118f, 0.198f, 0.000f)
            + Gaussian(0.5670f * 1.414f, r) * new Vector3(0.113f, 0.007f, 0.007f) 
            + Gaussian(1.9900f * 1.414f, r) * new Vector3(0.358f, 0.004f, 0.00001f) 
            + Gaussian(7.4100f * 1.414f, r) * new Vector3(0.078f, 0.00001f, 0.00001f); 
    }
    void OnWizardCreate () { //create stuff here
        
        Texture2D SSS_LUT = new Texture2D(width, height, TextureFormat.ARGB32, false); 
        for (int i = 0; i < width; i++) //ndotl
        {
            for (int j = 0; j < height; j++) //r
            {
                float x = Mathf.Lerp(-1, 1, i/(float) width); 
                float y =   height/(j+0.0001f)  ; //这里曲率的取值范围问题还是有些疑惑，但是按照0-1的取值范围是对的。同事可以考虑一下是否用remap来映射0-1.

                Vector3 result  = GetDiffuse(x,y);
                SSS_LUT.SetPixel(i, j, new Color(result.x,result.y,result.z,1f));
            }
        }
        SSS_LUT.Apply();
        byte[] bytes = SSS_LUT.EncodeToPNG(); 
        File.WriteAllBytes(Application.dataPath + "/Editor/" + filename + ".png", bytes); 
        DestroyImmediate(SSS_LUT); 
        Debug.Log("succeed!");
        
    }
}
