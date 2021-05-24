using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace CustomUtilities
{
    public class SpaceCaculate{

    static Matrix4x4 GetRotateMartixFromVector(Vector3 _dir1,Vector3 _dir2){
            Vector3 normalizeDir1 =  Vector3.Normalize(_dir1); //归一化之后变成1
            Vector3 normalizeDir2 =  Vector3.Normalize(_dir2); //归一化之后变成1
            Vector3 rotateionAxis =  Vector3.Cross(normalizeDir1,normalizeDir2); //叉乘获得旋转轴
            float sinTheta = rotateionAxis.magnitude; //模长 = dir1 * dir2 * sin, dir1、2 都是1,直接取即可
            float cosTheta = Vector3.Dot(normalizeDir1,normalizeDir2); //点乘直接获得cos
            float u = rotateionAxis.x;
            float v = rotateionAxis.y;
            float w = rotateionAxis.z;
            Matrix4x4 m = new Matrix4x4();

            m[0,0] =      cosTheta + u*u*(1-cosTheta);
            m[1,0] =  w * sinTheta + v*u*(1-cosTheta); 
            m[2,0] = -v * sinTheta + w*u*(1-cosTheta); 
            m[3,0] = 0;

            m[0,1] = -w * sinTheta + u*v*(1-cosTheta);
            m[1,1] =     cosTheta + v*v*(1-cosTheta);
            m[2,1] =  u * sinTheta + w*v*(1-cosTheta);
            m[3,1] = 0;

            m[0,2] =  v * sinTheta + u*w*(1-cosTheta);
            m[1,2] = -u * sinTheta + v*w*(1-cosTheta);
            m[2,2] =      cosTheta + w*w*(1-cosTheta);
            m[3,2] = 0;

            m[0,3] = 0;
            m[1,3] = 0;
            m[2,3] = 0;
            m[3,3] = 1;

            return m;

        }

    }
    public class PoissonDisk 
    {
        float r; //这个代表两个点之间的最小距离
        int dimension = 2; //维度目前只支持2
        // float w;
        int k;
        float orginalWidth;
        float orginalHeight;
        float orginalLength;
        float grid_width;
        int cols;
        int rows;
        List<Vector3> samples;
        List<Vector3> active;
        List<Vector3> grid; 
        bool DebugMode;

        public PoissonDisk( float _r, 
                            int _k,
                            float _orginalWidth,
                            float _orginalHeight,
                            float _orginalLength,
                            int _dimension = 2,
                            bool _DebugMode = false){
            k = _k;
            r = _r;
            orginalWidth = _orginalWidth;
            orginalHeight = _orginalHeight;
            orginalLength = _orginalLength;
            dimension = _dimension;
            active = new List<Vector3>();
            samples = new List<Vector3>();
            grid = new List<Vector3>(); 
            DebugMode = _DebugMode;
        }
        void Sampling(){ 
            while(active.Count!=0){
                int random_active_index = Mathf.FloorToInt(Random.Range(0f,active.Count)); //随机选一个
                Vector3 sampling_pos = active[random_active_index];
                bool found = false;
                for (int search = 0; search < k; search++) 
                {
                    Vector3 next_candicate_sample = search_candicate(sampling_pos);
                    
                    if(caculate_distance(next_candicate_sample)){

                        active.Add(next_candicate_sample); 

                        int x = Mathf.FloorToInt(next_candicate_sample.x/grid_width); 
                        int y = Mathf.FloorToInt(next_candicate_sample.y/grid_width);
                        
                        grid[y*rows+x] = next_candicate_sample; //把这个点替换掉
                        found = true; 
                        
                        //只要有一次成功就判定为found
                        //运行30次后如果最后一次found是false但是实际上这个点可能还能够找到点的话，其实这个点还是有价值的，所以这里只要有一次找到就算成功
                        //如果说要更快速的话可以尝试把只有一次找不到就算notfound，这个留在以后测试。
                    }

                }
                if(!found){ 
                    active.RemoveAt(random_active_index); //当找了30次都找不到，就把移出这个点

                }
            }

        }
        Vector3 search_candicate(Vector3 _sampling_pos){
            Vector3 _next_candicate_sample = Vector3.zero;
            float random_R = Random.Range(r, 2*r); 
            float random_direction = Random.Range(0f,  2f * Mathf.PI);
            _next_candicate_sample.x = random_R * Mathf.Cos(random_direction);
            _next_candicate_sample.y = random_R * Mathf.Sin(random_direction);
            return _next_candicate_sample + _sampling_pos;
        }
        public List<Vector3> GetResult(bool _StartAtZero){
            initParams(_StartAtZero);
            Sampling();
            samples.Clear();
            for (int i = 0; i < grid.Count; i++)
            {   
                if(grid[i].x!=Mathf.NegativeInfinity && grid[i].y!=Mathf.NegativeInfinity){
                    samples.Add(grid[i]);
                }
                
            }
            if(DebugMode){
                Debug.Log("Sample result with " + samples.Count + " points");
            }
            return samples;


        }
        private Vector3 initPos(bool _StartAtZero){
            Vector3 _initRandomPos;
            if(dimension ==2){
                if(_StartAtZero){ //startAtzero其实是指以中心点
                    _initRandomPos = new Vector3(orginalWidth/2,orginalHeight/2,0);
                }
                else{
                    _initRandomPos = new Vector3(Random.Range(0,orginalWidth),Random.Range(0,orginalHeight),0);
                }
                
            }
            else{
                if(_StartAtZero){

                    _initRandomPos = new Vector3(orginalWidth/2,orginalHeight/2,orginalHeight/2);
                }
                else{

                    _initRandomPos = new Vector3(Random.Range(0,orginalWidth),Random.Range(0,orginalLength),Random.Range(0,orginalHeight));
                }
            }
            return _initRandomPos;

        }
        private void initParams(bool _StartAtZero){
            //这里重新做的时候想到一个困惑点，画了个图计算了一下，重新梳理一下思路。
            //就是以最小距离为r作圆，这个圆和栅格的关系是内切还是外切。
            //演算了一番之后为了保证栅格内只有一个点应该圆为外切圆，此时一个栅格内的最大距离即为r，不满足>r的条件，所以一个栅格内不允许有多个点。
            //设r=1
            //同时当栅格最大距离为1（对角线）时，边长约为0.7，此时两个相邻的栅格所构成的边长为1.4，
            //即可同时满足一个栅格内只有一个点同时两个栅格之间的存在两个点可以使得距离大于r
            //如果是内切圆的话，矩形的对角线就是1.4了，此时肯定可以存在两个点在一个栅格内的距离大于r的(在对角线一端到另外一段长度为1的距离取一个点即可)
            //此时虽然彼此两个栅格之间可以找到两个点的距离大于1，但是一个栅格内肯定可以取两个点
            //虽然可以用代码去规避这个情况，除了造成这个栅格不够密集以外，两者的区别应该不大（猜测实际上也看不出来这样做的区别）
            grid_width = Mathf.Sqrt(Mathf.Pow(r,2)/2);
            rows = Mathf.FloorToInt(orginalWidth/grid_width);
            cols = Mathf.FloorToInt(orginalHeight/grid_width);

            for (int count = 0; count < rows*cols; count++)  //这里如果是三维还需要*多一层，暂时没实现
            {
                grid.Add(new Vector3(Mathf.NegativeInfinity,Mathf.NegativeInfinity,Mathf.NegativeInfinity));
            } //预填充。因为这里要按照行列来展开找空间关系的，索引才是我们需要的东西
            //找回这个随机采样点应该落在的栅格索引
            Vector3 initRandomPos = Vector3.zero;
            int i,j,k,index = -100; //what ever
            while(index < 0 || index >= rows * cols){
                initRandomPos = initPos(_StartAtZero);
                i = Mathf.FloorToInt(initRandomPos.x / grid_width);
                j = Mathf.FloorToInt(initRandomPos.y / grid_width);
                k = Mathf.FloorToInt(initRandomPos.z / grid_width);
                index = j * rows + i;
            }

            grid[index] = initRandomPos;//把grid所在索引的那个负无穷的点给替换成我们第一次找到的随机点。
            active.Add(initRandomPos); //添加第一个候选点

            if(DebugMode){
                Debug.Log("this sampler's cols = " + cols.ToString());
                Debug.Log("this sampler's rows = " + rows.ToString());
                Debug.Log("grid amount = " + (rows*cols).ToString());
                Debug.Log("grid interal = " + grid_width.ToString());
                Debug.Log("minum distance " + r.ToString());
                Debug.Log("first init point is " + initRandomPos);
            }

        }
        bool caculate_distance(Vector3 _next_candicate_sample){
            bool match = false;
            int x = Mathf.FloorToInt(_next_candicate_sample.x/grid_width);
            int y = Mathf.FloorToInt(_next_candicate_sample.y/grid_width);
            
            if( _next_candicate_sample.x > 0 && 
                _next_candicate_sample.x < orginalWidth &&  
                _next_candicate_sample.y > 0 && 
                _next_candicate_sample.y < orginalHeight && y*rows + x >=0 && y*rows + x < rows * cols){ //检测是否越界
                
                if(grid[y*rows + x].x==Mathf.NegativeInfinity && grid[y*rows + x].y==Mathf.NegativeInfinity){ //检测这个点所处的栅格是否是空的
                    match = true;

                    for (int i = -1; i < 1; i++) 
                    {
                        for (int j = -1; j < 1; j++) 
                        {
                            int index = (j+y)*rows+i+x;//迭代上下左右四个grid
                            
                            if(index >= 0 && index < rows * cols){ 
                                //这里还需要判断如果取到了边缘的位置，它的左侧是没有自动补0的
                                if(grid[index].x!=Mathf.NegativeInfinity&&grid[index].y!=Mathf.NegativeInfinity){ //如果这个点的周围没有点就不用判断了

                                    if( Vector3.Distance(grid[index], _next_candicate_sample) <= r){ //如果周围的点与这个点的距离小于等于r，则为不符合
                                        
                                            match = false;
                                            break;
                                            
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return match; //如果超过边界，则返回false，如果没有超过边界同时所在栅格没有，返回true，如果返回栅格没有但是周围的距离过近，返回false
        }
    }

}