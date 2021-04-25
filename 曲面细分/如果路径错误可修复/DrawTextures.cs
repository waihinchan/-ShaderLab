using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawTextures : MonoBehaviour
{
    // Start is called before the first frame update
    public Camera _camera;
    public Shader drawShader;
    RenderTexture _splatmap;
    Material _snowMaterial,_drawMaterial;
    RaycastHit _hit;
    [Range(1,20)]
    public int _BrushWidth = 1;
    void Start()
    {
        _drawMaterial = new Material(drawShader);
        _drawMaterial.SetVector("_Color",Color.red);
        _snowMaterial = GetComponent<MeshRenderer>().material;
        _splatmap = new RenderTexture(1024,1024,0,RenderTextureFormat.ARGBFloat);
        _snowMaterial.SetTexture("_Splat",_splatmap);
    }

    // Update is called once per frame
    void Update()
    {   
        _drawMaterial.SetFloat("_BrushWidth",(float)_BrushWidth);
        if(Input.GetKey(KeyCode.Mouse0)){
            if(Physics.Raycast(_camera.ScreenPointToRay(Input.mousePosition),out _hit)){
                _drawMaterial.SetVector("_Coord",new Vector4(_hit.textureCoord.x,_hit.textureCoord.y,0,0));
                // Debug.Log(new Vector4(_hit.textureCoord.x,_hit.textureCoord.y,0,0));
                //获得这一个瞬间，鼠标点击的位置，然后把这个向量设置给_drawMaterial。
                //此时drawmaterial会在某一个点，画上一个红色的点。
                RenderTexture temp = RenderTexture.GetTemporary(_splatmap.width,_splatmap.height,0,RenderTextureFormat.ARGBFloat); 
                //生成一张临时的图
                Graphics.Blit(_splatmap,temp); //将当前我们记录的splatmap复制到temp里面，也就是包含了所有的记录。
                Graphics.Blit(temp,_splatmap,_drawMaterial);//这个意思是把temp，拿到drawmaterial里面，然后再复制到splatmap。
                //需要注意一个是需要留一个叫maintex的东西,这个是如果我们要bilt的，也就是temp - drawmaterial_maintex - shader - splatmap.
                //所以我们最后得到的splatmap是经过maintex + cord共同处理的结果，那么再下一次绘制的时候就需要保留maintex的信息，否则就会被清空了。
                RenderTexture.ReleaseTemporary(temp);
            
            }
        }
    }
    void OnGUI(){
        GUI.DrawTexture(new Rect(0,0,256,256),_splatmap,ScaleMode.ScaleToFit,false,1); 

    }
}
