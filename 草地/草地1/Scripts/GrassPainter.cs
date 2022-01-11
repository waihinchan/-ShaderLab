using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.EditorTools;
using CustomUtilities;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
[ExecuteInEditMode]
public class GrassPainter : MonoBehaviour
{
    // Start is called before the first frame update
    public int toolbarInt = 0; //切换工具
    public float normalLimit = 1;
    [Range(1, 600000)]
    public int grassLimit = 600000;
    [Range(1.0f,10.0f)]
    public float density = 1.0f; //用于泊松采样的采样点,因为考虑到brushsize的问题，可以用brushsize * density来计算，保证到单位空间的密集程度一致这个问题
    [Range(1.0f,10.0f)]
    public float brushSize = 1.0f;
    //思路来看 修改一下，应该是给出一个brush size，等于半径。 而流量应该是density，也就是给一个forloop，density是count的次数。
    //但是这个会有一个问题是。如何排除那些两两之间过于密的点是一个问题，比如说用泊松盘采样去解决
    public LayerMask hitMask = 1;
    public LayerMask paintMask = 1;
    MeshFilter filter;
    public int grassCount;
    [SerializeField]
    List<Vector3> positions = new List<Vector3>();
    // [SerializeField]
    // List<Color> colors = new List<Color>();
    [SerializeField]
    List<int> indicies = new List<int>();
    [SerializeField]
    List<Vector3> normals = new List<Vector3>();
    [SerializeField]
    List<Vector2> length = new List<Vector2>();
    [SerializeField]
    List<Vector2> length2 = new List<Vector2>();
    
    //这里我们只计算一个平面，如果是三维的话就27个点了
    //这里储存的是栅格，所以我们需要预计算一个栅格的数量，比如说100 * 100的图片，采样100个点，那就是 10 * 10的栅格
    //这三个用于泊松盘采样
    Vector3 mousePos;
    [HideInInspector]
    public Vector3 hitPosGizmo;
    [HideInInspector]
    public Vector3 hitNormal;
    Vector3 hitPos;
    Mesh mesh;
    int[] indi;
#if UNITY_EDITOR
    //copy from https://www.patreon.com/posts/grass-geometry-2-40077798
    void OnFocus()
    {
        // Remove delegate listener if it has previously
        // been assigned.
        SceneView.duringSceneGui -= this.OnScene;
        // Add (or re-add) the delegate.
        SceneView.duringSceneGui += this.OnScene;
    }

    void OnDestroy()
    {
        // When the window is destroyed, remove the delegate
        // so that it will no longer do any drawing.
        SceneView.duringSceneGui -= this.OnScene;
    }

    private void OnEnable()
    {
        filter = GetComponent<MeshFilter>();
        SceneView.duringSceneGui += this.OnScene;
        
    }
    
    public void ClearMesh()
    {
        grassCount = 0; //归零归零
        positions = new List<Vector3>();
        indicies = new List<int>();
        // colors = new List<Color>();
        normals = new List<Vector3>();
        length = new List<Vector2>(); //实际上这个不一定需要使用，要看他的shader中用UV来做什么，实际上我们只是需要一些点然后在Geo里面自己算的
        length2 = new List<Vector2>();
    }

    //copy from https://www.patreon.com/posts/grass-geometry-2-40077798
    void OnScene(SceneView scene){
        if ((Selection.Contains(gameObject))){ 
            //这里我觉得还是不是很方便，应该给一个挂件之类的，然后直接是unityeditor里面的一些工具来点选是最好的。
            //不过看了一下Terrain也是这么做的。看看后面有没有必要改
            Event e = Event.current; 
            RaycastHit terrainHit;

            //这里是矫正一下鼠标的位置，因为scene的mousePosition的原点在左上角
            mousePos = e.mousePosition;
            float ppp = EditorGUIUtility.pixelsPerPoint;
            mousePos.y = scene.camera.pixelHeight - mousePos.y * ppp;
            mousePos.x *= ppp;

            Ray rayGizmo = scene.camera.ScreenPointToRay(mousePos);//射线
            RaycastHit hitGizmo;
            if (Physics.Raycast(rayGizmo, out hitGizmo, Mathf.Infinity, hitMask.value)) //这两个数值先传递给editor组件把笔刷画出来
            {
                hitPosGizmo = hitGizmo.point;
                hitNormal = hitGizmo.normal;
            }
            if (e.button == 1 && toolbarInt==0){ //add mode
                float r = brushSize / density; //这个brushSize此时应该为半径为brushSize构成的圆的外切矩形的边长
                 //如果density=1 应该是只有1个点。density越大，r越小，此时需要被分割的grid就越多，则点和点之间的距离越大
                PoissonDisk poissiondisk = new PoissonDisk(r,30,brushSize,brushSize,brushSize,2,false);
                
                List<Vector3> sampleresult = poissiondisk.GetResult(false); //因为这里偏移了brushSize/2,所以要偏移回去
                Ray ray = scene.camera.ScreenPointToRay(mousePos);
                for (int i = 0; i < sampleresult.Count; i++)
                {
                    //这个是泊松盘采样后的结果(以origin为原点)
                    Vector3 offsetorigin = sampleresult[i] - new Vector3(brushSize/2,brushSize/2,0);
                    offsetorigin.z = offsetorigin.y;
                    offsetorigin.y = 0;
                    //修正左上角到原点的偏移
                    Ray tempray = ray;
                    tempray.origin += offsetorigin;
                    if(Vector3.Distance(Vector3.zero,offsetorigin)<brushSize/2){
                        if (Physics.Raycast(tempray, out terrainHit, 200f, hitMask.value) && grassCount < grassLimit && terrainHit.normal.y <= (1 + normalLimit)&& terrainHit.normal.y >= (1 - normalLimit)) {
                            if ((paintMask.value & (1 << terrainHit.transform.gameObject.layer)) > 0){
                                hitPos = terrainHit.point;
                                hitNormal = terrainHit.normal;
                                Vector3 grassPosition;
                                Matrix4x4 m = this.transform.worldToLocalMatrix;
                                grassPosition  = m.MultiplyPoint3x4(hitPos);
                                positions.Add((grassPosition));
                                indicies.Add(grassCount);
                                length.Add(terrainHit.textureCoord); //因为我们要用splatmap
                                length2.Add(new Vector2(1f, 1f)); //这个用于给出随机的宽和高的最大值
                                // add random color variations                          
                                // colors.Add(new Color(AdjustedColor.r + (Random.Range(0, 1.0f) * rangeR), AdjustedColor.g + (Random.Range(0, 1.0f) * rangeG), AdjustedColor.b + (Random.Range(0, 1.0f) * rangeB), 1));
                                //colors.Add(temp);
                                normals.Add(terrainHit.normal);
                                grassCount++;
                                
                            }
                            
                        }
                    }
                   
                    

                }
                e.Use();
            }
            if (e.button == 1 && toolbarInt==1){ //remove mode
                Ray ray = scene.camera.ScreenPointToRay(mousePos);

                if (Physics.Raycast(ray, out terrainHit, 200f, hitMask.value))
                {
                    hitPos = terrainHit.point;
                    hitPosGizmo = hitPos;
                    hitNormal = terrainHit.normal;
                    for (int j = 0; j < positions.Count; j++)
                    {
                        Matrix4x4 m = this.transform.localToWorldMatrix; //转移回世界坐标计算距离
                        Vector3 pos = m.MultiplyPoint3x4(positions[j]);
                        float dist = Vector3.Distance(terrainHit.point, pos);

                        // if its within the radius of the brush, remove all info
                        if (dist <= brushSize/2)
                        {
                            positions.RemoveAt(j);
                            // colors.RemoveAt(j);
                            normals.RemoveAt(j);
                            length.RemoveAt(j);
                            length2.RemoveAt(j);
                            indicies.RemoveAt(j);
                            grassCount--;
                            for (int i = 0; i < indicies.Count; i++)
                            {
                                indicies[i] = i;
                            }
                        }
                    }
                }
                e.Use();
            }

            mesh = new Mesh();
            mesh.SetVertices(positions);
            indi = indicies.ToArray();
            mesh.SetIndices(indi, MeshTopology.Points, 0);
            mesh.SetUVs(0, length); 
            mesh.SetUVs(1, length2); 
            // mesh.SetColors(colors); //这个是顶点光
            mesh.SetNormals(normals);
            filter.mesh = mesh;


        }






    }



























#endif
}
