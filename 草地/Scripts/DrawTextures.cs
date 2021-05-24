using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawTextures : MonoBehaviour
{
    // Start is called before the first frame update
    public Camera _camera;
    public Shader drawShader;
    RenderTexture _splatmap;
    RenderTexture _splatmaptemp;
    Material _GrassMaterial,_drawMaterial;
    RaycastHit _hit;
    [Range(1,20)]
    public int _BrushWidth = 1;
    public Vector4 targetposition;
    public Transform target;
    static public List<GameObject> interactList = new List<GameObject>();
    
    void Start()
    {
        _drawMaterial = new Material(drawShader);
        _drawMaterial.SetVector("_DrawColor",Color.red);
        _GrassMaterial = GetComponent<MeshRenderer>().material;
        _splatmap = new RenderTexture(1024,1024,0,RenderTextureFormat.ARGBFloat);
        _splatmaptemp = new RenderTexture(1024,1024,0,RenderTextureFormat.ARGBFloat);
        
        
        
    }
    //这里有一个问题是，如果这个物体是不着地的情况下，其实也可以发生和草的碰撞，这个时候检测就失效了
    //但是如果每一个对象都绑定一个脚本发送过来也挺麻烦的。所以这里预留一个接口吧
    // void OnCollisionEnter(Collision collision){interactList.Add(collision.gameObject);}
    // void OnCollisionExit(Collision collision){interactList.Remove(collision.gameObject);}
    // void OnCollisionStay(Collision collisionInfo){}
    void drawTextureOneByOne(){
        //清空背景

        
        RenderTexture clearbackground = RenderTexture.GetTemporary(_splatmap.width,_splatmap.height,0,RenderTextureFormat.ARGBFloat);
        Graphics.Blit(clearbackground,_splatmaptemp);
        foreach (GameObject interactObject in interactList) //迭代所有对象
        {   
            if(DetectOnFace(interactObject.transform.position,1.0f)){ 
                //检测是否发生交互，射线的距离在测试里面用的常量，实际上可以用distance(Objectposition,plane) - Objectsize/2 来决定。
                //即如果物体的体积的一半在中心点和平面的范围内时，即可判定为有接触。这个不完全准确因为草本身有高度，实际上可能碰到一点点都会发生交互
                //但是没办法计算草本身的高度（如果用生成器生成的草的长度可以通过获取数组获得，但是没有必要做的这么精确了。。增加运算量）
                _drawMaterial.SetMatrix("_WorldMatrix", transform.worldToLocalMatrix); //pass the world to local matrix
                _drawMaterial.SetVector("_Coord",new Vector4(_hit.textureCoord.x,_hit.textureCoord.y,0,0));
                _drawMaterial.SetVector("_TargetPosition",interactObject.transform.position);
                float size = interactObject.GetComponent<Renderer>().bounds.size.x * interactObject.GetComponent<Renderer>().bounds.size.y;
                _drawMaterial.SetFloat("_BrushWidth",(float)size*_BrushWidth); //depend on some brush with or something
                //传递参数

                RenderTexture temp = RenderTexture.GetTemporary(_splatmap.width,_splatmap.height,0,RenderTextureFormat.ARGBFloat);//新建一个临时贴图
                Graphics.Blit(_splatmap,temp);//把当前splatmap的记录绑定到temp
                Graphics.Blit(temp,_splatmap,_drawMaterial); //用之前的记录作为贴图，画新的点
                RenderTexture.ReleaseTemporary(temp);
            }
        }
        Graphics.Blit(_splatmap,_splatmaptemp);
        _GrassMaterial.SetTexture("_InteractMap",_splatmaptemp);
        Graphics.Blit(clearbackground,_splatmap);
        RenderTexture.ReleaseTemporary(clearbackground);

    }
    bool DetectOnFace(Vector3 _position,float _maxDistance){
        if(Physics.Raycast(_position, -Vector3.up,out _hit,_maxDistance)){
            return true;
        }
        else{
            return false;
        }
    }
    // Update is called once per frame
    void Update()
    {      
        drawTextureOneByOne();
    }
    void OnGUI(){
        GUI.DrawTexture(new Rect(0,0,256,256),_splatmaptemp,ScaleMode.ScaleToFit,false,1); 
    }
}
