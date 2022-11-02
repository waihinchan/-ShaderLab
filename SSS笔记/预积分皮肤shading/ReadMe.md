# 预积分皮肤shading

相关的原理和解释PPT和GPUPRO2都有了。具体的细节会在实现的时候会进行解释。

## diffuseLUT：

本来是参考的这一篇：

[Pre-Integrated Skin Shading 数学模型理解](https://zhuanlan.zhihu.com/p/56052015)

但是后来看了一些修正的文章发现这一篇有一些错误，下面从头解释一下。

![%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled.png](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled.png)

以这个图为例子。大白话来解释这个公式的意思就是，给定一个圆环，求这个圆环的一个点P所受到其他所有点p' （图里面对应的是点Q） 的散射光的影响。 

首先计算的是当光射到表面时候，点p' 所受到的光照度。

这里给了个公式是：

![%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%201.png](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%201.png)

个人感觉就是把OQ当作法线然后套到兰伯特模型里面了。同时dot的结果需要clamp01.

所以伪代码如下：

```csharp
float x = Mathf.Acos(NdotV); 
float theta = 0; 
float Getp'_Light = Mathf.Clamp01( Mathf.Cos(x + theta) );
```

这个theta_x 就是上面公式的x

这个theta指的是Op'与法线N构成的夹角。后面我们可以写一个迭代把theta从 -PI 到 PI之间迭代，就可以求出所有的点。

---

然后第二步，教程指出，由上面得到这个结果 乘上一个 代表某个点p' 对 P的散射函数 q(x)，就可以得到我们最终点P上的亮度是多少。

而q(x) 可以用diffusion profile 来实现。 而q(x)中的 x 的参数为 任意一点p' 到 点P的距离。所以有公式如下：

![%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%202.png](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%202.png)

而其中这里的r指这个半圆的半径。x指的还是那个Op‘和N的夹角。(所以传入的代码里面的1/R是曲率的倒数也就是圆的半径)

伪代码如下：

```csharp
float theta = 0; 
float r = 0;
float d = 2r * sin(theta/2);
```

上面说了theta是可以通过迭代来求得所有的角度的。同理r也是这样。在c#实现里面可以用纹理贴图的高度来进行映射，在shader中也可以用uv来进行映射。

也可以先烘焙好一个曲率贴图来做采样

曲率计算公式：

```glsl
fixed cuv = saturate(_CurveFactor * (length(fwidth(worldNormal)) / length(fwidth(worldPos))))
```

到目前为止我们确定了我们的参数x，然后把它代入到q(x)里面。

---

diffuse profile的代码如下：

```csharp
float Gaussian(float v , float r){
        return 1.0f / Mathf.Sqrt(2.0f * Mathf.PI * v) * Mathf.Exp( -(r * r) / (2 * v) ); //2piv用的是根号还是2不确认    
}
Vector3 Scatter( float r){
        return Gaussian(0.0064f * 1.414f, r) * new Vector3(0.233f, 0.455f, 0.649f) 
          + Gaussian(0.0484f * 1.414f, r) * new Vector3(0.100f, 0.336f, 0.344f)
        + Gaussian(0.1870f * 1.414f, r) * new Vector3(0.118f, 0.198f, 0.000f)
        + Gaussian(0.5670f * 1.414f, r) * new Vector3(0.113f, 0.007f, 0.007f) 
        + Gaussian(1.9900f * 1.414f, r) * new Vector3(0.358f, 0.004f, 0.00001f) 
        + Gaussian(7.4100f * 1.414f, r) * new Vector3(0.078f, 0.00001f, 0.00001f); 
}
```

这里的r就是我们的曲率，就是上面确定好的参数x。

基于以上代码我们就可以求出某一个点p' 对 P的散射光为：

```csharp

float x = Mathf.Acos(NdotV); //光和法线的夹角
float Getp'_Light = Mathf.Clamp01( Mathf.Cos(x + theta) ); //任意一点与法线的夹角
float r = 0; //曲率
float d = 2r * sin(theta/2); //点p' 和 P 的距离
float p'_Scatter = Scatter(d) * Getp'_Light ;
```

---

事情到这里还没有结束。从上面这个方程来看似乎有什么不对。

![%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%203.png](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%203.png)

上面的教程中给出了一个推导的过程。大体来说的意思就是根据能量守恒定律，P在这个半圆上所接收到的总和应该是1， 而当我们简单的用q(x)来代表某一点p’ 对 P的散射光贡献度是错误的，因为还要积分考虑半圆上所有的点的情况。 然后就是一通推导。 得出上面的这么一个公式。 

根据公式来看，分子中的cos（theta + x） 正式代码中求的 ”Getp'_Light“， 而R(2r * sin(x/2)) 则是我们的diffuseprofile的q(x)， 也就是Scatter(d)。 所以公式的分子应为所有点p' 的 ”p'_Scatter“累加。

而分母则为Scatter(d)；

所以我们最终得到的某一个点P所受到的光照度结果应该是

```csharp

float x = Mathf.Acos(NdotV); //反三角函数求光和法线的夹角
float Getp'_Light = Mathf.Clamp01( Mathf.Cos(x + theta) ); //任意一点与法线的夹角
float r = 0; //曲率
float d = 2r * sin(theta/2); //点p' 和 P 的距离
float p'_weight = Scatter(d);
float p'_Scatter = Scatter(d) * Getp'_Light ;
//在半圆内重复以上过程N次并且分别累加p'_weight 和 p'_Scatter。
//得到一个最终结果 p'_weight_total 和 p'_Scatter_total.

float result = p'_Scatter_total /  p'_weight_total;
```

CPU端烘焙如下（Unity）：

```glsl
Vector3 GetDiffuse(float ndotl, float r){
        float theta = Mathf.Acos(ndotl); 
        Vector3 totalWeights = Vector3.zero;
        Vector3 totalLight = Vector3.zero;
        float startAngle = -(Mathf.PI); 
        while (startAngle<=Mathf.PI)
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
```

GPU端烘焙的代码如下：

```glsl
float3 GetDiffuse(float ndotl, float r){
            float theta = acos(ndotl); 
            float3 totalWeights = 0;
            float3 totalLight = 0;
            float startAngle = -PI; 
            while (startAngle<=PI)
            {
                float sampleAngle = theta + startAngle;
                float diffuse = clamp( cos(sampleAngle),0,1 );
                float sampleDist = abs( 2.0f * r * sin(startAngle * 0.5f) );
                float3 weights = Scatter(sampleDist);
                totalWeights += weights;
                totalLight += diffuse * weights;
                startAngle+=_inc;
            }
            float3 result =  float3(totalLight.x/totalWeights.x,totalLight.y/totalWeights.y,totalLight.z/totalWeights.z);
            return result;
        }
```

至此我们就可以烘焙出这么一张图：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%204.png)

并且在实时渲染中通过`ndotl` 和 `curve` 作为uv来采样LUT作为diffuseTerm。后面会给出完整的细节。

这里有一些勘误的地方，首先是关于取值范围是-pi~pi还是-pi/2~pi/2的这个问题，根据大佬的说法

[Pre-Integrated Skin Shading 的常见问题解答](https://zhuanlan.zhihu.com/p/384541607)

和我后面也从头看了PPT的注释和GPUPRO里面前后的一些描述：

取值范围应该是 `-PI~PI` 。因为如果我们从一个圆环的角度来理解的话，任意一个点都必须要取到一个全圆，所以是2PI，如果是halfPI的话积分域只有一个半圆。 然后是否需要`saturate`的问题，是需要的，这个在PPT的最后一页的勘误中也有说明。

还有就是sRgb的问题，原文公式是线性的，所以我们使用的贴图应该是线性的。其余的问题看大佬说的就行。

（不过这里有个问题是看这个图可以看得出有一点分层，这个用GPU和CPU烘焙都会有这个问题，不知道是我烘焙的方法不对还是本来就会有这个问题。不过在实际使用中并不影响）

## 法线

简单翻译一下GPU PRO2原文中的意思就是，皮肤表面的皱纹、毛孔等因素也会影响到光的散射和折射。而一般这些细节都是来自于法线纹理。光照射上去就像是照射在没有散射的表面一样（呈现出更宽或模糊的皱纹）

配合PPT中的解释应该是，上面的散射效果是基于非常光滑或者平整的表面而设计的。当表面有一些微小凹凸表面时，曲率就失效了。而实际上光在这些微小的凹凸表面应该会呈现出一些散射的效果。

他们提出了一个简单的方法，就是对法线贴图进行模糊，就可以模拟出在这些凸起出光散射带来的模糊效果。然后最重要的一点是这个法线同样也适用于diffusion profiles。也就是说在不同波长的光（不同颜色的光）下会呈现出不同的效果。

他们举了一个例子来比喻，就是在不同光下扫描出来的法线图（针对皮肤）会呈现出不同的结果。其实这里原文说的有点绕，简单解释一下就是因为次表面散射的效应，皮肤对红色的光吸收得更多（然后依次是绿色、蓝色），所以当光被吸收了以后，那些微表面就因为没有反弹到光线呈现出一种模糊（丢失细节）的感觉。原文中说的是**bent toward the dominant-surface normal.** 也就是细节法线往结构法线的过渡（只呈现出结构法线，但是细节的部分丢失了）。

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%205.png)

所以理论上用当下的光颜色来确定对应的法线是最吻合真实结果的。但是实际上出于内存的考虑不可能使用一个光对应一个法线图的方式。由于上面提到了简单的模糊法线就可以达到散射的效果。而针对不同波长的光（R,G,B），使用不同程度的模糊就可以拟合出法线对应不同波长下的模糊的感觉。也就是吸收的光越多越模糊。

这个算法还提出了一个关于nonNormalize的法线的问题。大概是说当凹凸全部处于阴影或全部不处于阴影的情况下，非归一化的法线能获取更好的结果。但是这个讨论是另外几篇论文谈论到的内容了。原文也没有过多的展开，只是提出他们并不需要刻意的对插值后的法线再次进行归一化，也能取得很好的结果。

代码的实现上可以看原书的附录，这里贴出一个关键的部分：

```glsl
float4 normMapHigh = tex2D ( NormalSamplerHigh , Uv) ∗ 2. 0 − 1 . 0 ;
float4 normMapLow = tex2D ( NormalSamplerLow , Uv) ∗ 2. 0 − 1 . 0 ;
float3  rN = lerp ( Nhigh , Nlow , tuneNormalBlur. r ) ;
float3  gN = lerp ( Nhigh , Nlow , tuneNormalBlur. g ) ;
float3  bN = lerp ( Nhigh , Nlow , tuneNormalBlur. b ) ;
```

这里的tuneNormalBlur是一个参数，感觉实际上可以通过配置的方式去修改，并不一定要按照皮肤的diffuse profile来设置。而且由于这里是Lerp，其实也和本身Nlow的LOD采样级别有很大的关系，具体的结果可以再手动算一下或者肉眼判断一下得出一个比较吻合的参数值。

---

## 阴影

阴影的部分简单来说就是因为皮肤有吸收一部分的光，所以阴影的部分具有散射特性的材质会比一般的材质更亮一点点，尤其是在半影的区域。文中也提及到了全光或全黑不在讨论的范围内。然后文中把阴影看作一个线性的（针对半影区域）衰减函数。

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%206.png)

这里等于把这个半影的区域重新根据diffuse profile来映射一个新的半影区域：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%207.png)

具体怎么实现呢，首先是需要预先知道场景中使用半影的PCF的kernel，然后对原来的阴影数值做逆运算。也就是把采样到的shadowMap的shadow逆运算出原来的数值（应用PCF之前的数值），类似于得到了阴影处于全黑和全白之间的某一个位置。然后根据diffuse profile烘焙出半影的LUT。而这个LUT会在在渲染的时候根据采样到的阴影数值作为UV。

GPUPRO2的代码如下：

```glsl
float3 integrateShadowScattering(float penumbraLocation ,
float  penumbraWidth )
{
	float3  totalWeights = 0 ;
	float3  totalLight = 0 ;
	float a= −PROFILEWIDTH;
	while ( a<=PROFILEWIDTH )
	{
	float light = newPenumbra ( penumbraLocation + a/
	penumbraWidth ) ;
	float  sampleDist = abs ( a ) ;
	float3 weights = Scatter(sampleDist) ;
	totalWeights += weights ;
	totalLight += light ∗ weights ;
	a+=inc ;
	}
return totalLight / totalWeights ;
}
```

这里其实还提到了一个penumbraWidth 半影宽度的问题。当时看书和PPT并没有看明白这个东西是做什么的。然后又请教了**[Jeffrey Zhuang](https://www.zhihu.com/people/jeffrey-zhuang)** 大佬，大佬给出这么一个图进行解释：

![Screenshot 2022-05-12 001929.png](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Screenshot_2022-05-12_001929.png)

大佬说的一句话启发了我：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%208.png)

如果我们对比diffuseLUT的公式：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%209.png)

我们会发现，分子其实是由两个项目组成的。左边的部分是一个Normalize的NdotL的项目，右边是由diffuseProfile对光谱吸收的系数。而对于阴影的区域也是这样的。所以我们可以看出左边的部分对应的是一个归一化的项目，而右侧是一个基于距离d的项。（其实3S的本质就是材质对光的波长在不同长度下的吸收系数的研究和还原）。所以对于阴影的项目，我们的左侧其实是指光的强度，右侧则是指一个距离，这也就是为什么我们使用的penumbraWidth 宽度是在世界空间坐标下的原因了。

```glsl
Vector3 GetShadow(float penumbraLocation,float penumbraWidth){
        /// <summary>
        /// penumbraLocation 是一个归一化的量
        /// penumbraWidth 是世界空间坐标下的量(penumbraWidth推测是总长度)
        /// lambda / penumbraWidth = extraPenumbraLocation
        /// 散射积分的是世界空间坐标下的量//其他半影的世界空间下的长度
        /// 光照积分的是阴影函数的量//半影的其他量累积
        /// </summary>
        Vector3 totalWeights = Vector3.zero;
        Vector3 totalLight = Vector3.zero;
        float start = -2; 
        while (start<=2)//对应正无穷到负无穷的积分区间
        {   
            float param = Mathf.Clamp01(Mathf.Pow(penumbraLocation + start * penumbraWidth,3));
            float light;
						//这个部分是newP
            if(param > 0.9){
                 light = 1.0f;
            }
            else if(param < 0.5){
                 light = 0.0f;
            }
            else{
                 light = Mathf.Lerp(0,1,param);
            }
            light = Mathf.Lerp(0,1,param);
						//这个部分是newP

            //这里传入的是penumbraWidth 是 1/w
            //从下往上的1/w是逐渐变大 对应的penumbraWidth是从大到小，即对应了靠近原点的地方更黑（被吸收的红光更多）
            // x / w = normalize shadow location.
            float sampleDist = Mathf.Abs(start);
            Vector3 weights = Scatter(sampleDist/penumbraWidth);
            totalWeights += weights;
            totalLight += light * weights;
            start+=shadowInc;
        }
        Vector3 result = new Vector3(totalLight.x / totalWeights.x, totalLight.y / totalWeights.y, totalLight.z / totalWeights.z);
        return result;
    }
```

(这里有个实现细节是我们要传入1/penumbraWidth)来烘焙才好使得在渲染的时候进行采样（因为penumbraWidth在世界空间下的尺度肯定是大于1的，如果要作为UV的话要取倒数，如果是特别特别近的情况我们可以取1）

但其实在实现起来还是有一定的困难，首先我们如何计算$P^{-1}$ 。因为原文提出的是需要找到阴影的原始值。但是以Unity为例，如果使用的是shadowMap的话，其实原始的shadow值只有0或1，这样其实是很难对$newP$ 进行映射的。（另外PCF的还原也比较困难）。另外一点是penumbraWidth 在世界坐标下的计算，大佬给出的提示是：

> 以方向光为例，给定了 shadow map 相机的正交 size 和 纹理的 resolution，此时 shadow map 上一个 texel 对应的世界空间尺寸就定下来了。
> 

这里给出一个在U3D中根据cullingSphere.w和级联贴图来计算出对应的纹素尺寸的代码：

```glsl
half getTexelSizeInWorldSpace(half3 worldPos){
    float4 sphereSize = GetSphereRadii(worldPos);
    return 2 * max(max(max(sphereSize.x,sphereSize.y),sphereSize.z),sphereSize.w) /  _AdditionalShadowmapSize.w ; 
}
```

具体这个部分的计算需要根据不同的阴影算法来实现。

但是我觉得这个还是有一点疑惑的部分，首先是如果使用的是shadowmap的话，半影宽度在世界空间下的尺寸其实是一个很大的数值，那么在烘焙的时候我们的penumbraWidth应该要取一个恰当的范围（因为太远的就没有意义了，主要是针对近距离看的时候，半影位置所在的纹素尺寸产生的细节）。另外一个是烘焙的时候，我们看到`float light = newPenumbra ( penumbraLocation + a/penumbraWidth );`这个部分，会发现原文的计算是基于半影宽度来生成阴影的衰减值的，但是其实在UnityPCF的算法里面可以看出，半影的衰减值其实和所谓的penumbraLocation没有什么关系（因为从a/penumbraWidth中推出这个penumbraWidth是一个总长度，等于是0到1之间的某个位置）。

UnityPCF：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2010.png)

目前我根据自己的理解烘了这么一个图：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2011.png)

可以看到比diffuse的还要红一点。。所以我觉得这个结果还是有问题的，但由于没有一个标准的生成的图作为参考，这个部分还需要进一步的实验和研究（主要是还要从头开始看阴影的算法，工程量比较大）

## 高光

高光的部分GPUPRO2并没有提及，我们可以参考GPUGEM3第十四章的做法：

[Chapter 14. Advanced Techniques for Realistic Real-Time Skin Rendering](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-14-advanced-techniques-realistic-real-time-skin)

这里给出具体代码如下：

```glsl
float fresnelReflectance( float3 H, float3 V, float F0 ) {   
float base = 1.0 - dot( V, H );   
float exponential = pow( base, 5.0 );   
return exponential + F0 * ( 1.0 - exponential ); 
}
float KS_Skin_Specular( float3 N, // Bumped surface normal
    float3 L, // Points to light
    float3 V, // Points to eye
    float m,  // Roughness
    float rho_s, // Specular brightness
    uniform texobj2D beckmannTex ) {   
float result = 0.0;   
float ndotl = dot( N, L ); 
if( ndotl > 0.0 ) {    
float3 h = L + V; // Unnormalized half-way vector    
float3 H = normalize( h );    
float ndoth = dot( N, H );    
float PH = pow( 2.0*f1tex2D(beckmannTex,float2(ndoth,m)), 10.0 );    
float F = fresnelReflectance( H, V, 0.028 );    
float frSpec = max( PH * F / dot( h, h ), 0 );    
result = ndotl * rho_s * frSpec; // BRDF * dot(N,L) * rho_s  
}  
return result; 
}
```

这里是把beckman distribution烘焙成一个贴图了，参数是roughness和ndothalf。 但是其实这个部分可以实时计算（如果考虑到带宽的话）。

这里产生的高光根据论文的对比如下

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2012.png)

就是对比一般的模型，面部会产生一些更高频的高光细节（但是我们的画风可能还是用平一点的高光会好点）

而且根据GPUGEM3的说法，其实这里的代码参考的并不是这个算法的出处论文，而是：

> **Varying Specular Parameters over the Face**
> 
> 
> A survey of human faces presented by Weyrich et al. 2006 provides measured parameters for the Torrance/Sparrow specular BRDF model with the Beckmann microfacet distribution function. They assume such a model is valid for skin surface reflectance and measure roughness m and intensity rho_s for ten regions of the face across 149 faces. The results, available in their SIGGRAPH 2006 paper, provide a great starting point for tuning a specular BRDF for rendering faces. The Torrance/Sparrow model is approximated closely by the Kelemen/Szirmay-Kalos model, and the measured parameters work well for either. Their data can be easily painted onto a face using a low-resolution two-channel map that specifies m and rho_s for each facial region. Figure 14-8 compares rendering with the measured values of Weyrich et al. versus constant values for m and rho_s over the entire face. The difference is subtle but apparent, adding some nice variation (for example, by making the lips and nose shinier).
> 

出处论文：

[Analysis of human faces using a measurement-based skin reflectance model | ACM SIGGRAPH 2006 Papers](https://dl.acm.org/doi/10.1145/1179352.1141987)

其实这个论文大部分都是一些我看不懂的地方，包括测量的方法和设备都比较繁琐。反正论文中给出的有几个我认为有参考意义的结论。

- 皮肤的一部分油脂层会直接反射高光，而且由于是导电材料（类似于金属），所以是会直接反射光照颜色，而不发生散射现象。(所以specular可以使用灰度，原文中也提及这样可以提高结果的稳定性)
- 另外一个是根据粗糙度和rho_s可以对面部各个区域的高光细节进行控制。

效果如下：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2013.png)

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2014.png)

## IBL项

参考：

[虚幻4渲染编程(材质编辑器篇)【第十六卷：移动端的Pre-Integrated Rendering】](https://zhuanlan.zhihu.com/p/90939122)

## 实现细节

先看效果的对比，以UnityURP为例：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2015.png)

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2016.png)

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2017.png)

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2018.png)

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2019.png)

使用的光照模型如下：

```glsl
float Gaussian(float v , float r){
    return 1.0f / sqrt(2.0f * PI * v) * exp( -(r * r) / (2 * v) ); 
}
float3 Scatter( float r){
        return Gaussian(0.0064f * 1.414f, r) * float3(0.233f, 0.455f, 0.649f) 
        + Gaussian(0.0484f * 1.414f, r) *  float3(0.100f, 0.336f, 0.344f)
        + Gaussian(0.1870f * 1.414f, r) *  float3(0.118f, 0.198f, 0.000f)
        + Gaussian(0.5670f * 1.414f, r) *  float3(0.113f, 0.007f, 0.007f) 
        + Gaussian(1.9900f * 1.414f, r) *  float3(0.358f, 0.004f, 0.00001f) 
        + Gaussian(7.4100f * 1.414f, r) *  float3(0.078f, 0.00001f, 0.00001f); 
}
float getDistanceFromShadowMap(float3 pos,float3 N){
    float3 shrinkedpos = float4(pos - 0.001 * N,1); //缩小一部分世界坐标
    float4 newShadowCoord = TransformWorldToShadowCoord(shrinkedpos);
    // newShadowCoord.xyz /= newShadowCoord.w; //screen UV //main light has no projections
    float d2 = newShadowCoord.z;
    float d1 = SAMPLE_TEXTURE2D(shaodwMap,newShadowCoord.xy);//采样到的深度值
    return abs(d1-d2);
}
half PBRPreintegrateSkinTranslucency(float3 positionWS,float3 N,float translucencyFactor){
    float distanceFromShadowMap = getDistanceFromShadowMap(positionWS,N);
    float3 color = Scatter(distanceFromShadowMap * 1); //if we can get a real world distance?
    color *= translucencyFactor; 
    return color;
}
half3 UniversalFragmentPBRPreintegrateSkinDiffuse(float3 normalWS,float3 normalWSLow,float3 L,float curve,TEXTURE2D(DiffuseLUT),float3 tuneNormalBlur){
    float3 rN = normalize(lerp(normalWS,normalWSLow,tuneNormalBlur.r));
    float3 gN = normalize(lerp(normalWS,normalWSLow,tuneNormalBlur.g));
    float3 bN = normalize(lerp(normalWS,normalWSLow,tuneNormalBlur.b));
    float3 NdotL = 0.5 * (float3(dot(rN,L),dot(gN,L),dot(bN,L))) + 0.5 ;
    float3 diffuse;
    diffuse.r = SAMPLE_TEXTURE2D(DiffuseLUT,float2(NdotL.r,curve)).r;
    diffuse.g = SAMPLE_TEXTURE2D(DiffuseLUT,float2(NdotL.g,curve)).g;
    diffuse.b = SAMPLE_TEXTURE2D(DiffuseLUT,float2(NdotL.b,curve)).b;
    return  2 * diffuse; //1 is too weak.. 
}
float fresnelReflectance( float3 H, float3 V, float F0 ) {   
    float base = 1.0 - dot( V, H );   
    float exponential = pow( base, 5.0 );   
    return exponential + F0 * ( 1.0 - exponential ); 
}
half PBRPreintegrateSkinSpecular(float3 N, float3 L, float V, float m, float rho_s,TEXTURE2D(DiffuseLUT)){
    float result = 0.0;
    float ndotl = saturate(dot(N,L));
    float3 h = L + V; 
    float3 H = normalize(h);
    float ndoth = dot(N,H);
    float PH = pow(2.0*SAMPLE_TEXTURE2D(DiffuseLUT,float2(ndoth,m)).a, 10.0 ); //1-m or m-1? rouhgness or smoothness
    //Beckmann 可以实时计算的
    float F = fresnelReflectance( H, V, 0.028 ); 
    float frSpec = max( PH * F / dot( h, h ), 0 );
    result = ndotl * rho_s * frSpec ;
    return result;  
}
half4 PBRPreintegrateSkin(){
    float3 diffuseTerm = shadowAttenuation * mainLightColor* albedo * UniversalFragmentPBRPreintegrateSkinDiffuse(normalWS,normalWSLow,mainLightDirection,curve,TEXTURE(DiffuseLUT),_tuneNormalBlur);
    float3 specularTerm = shadowAttenuation * mainLightColor * PBRPreintegrateSkinSpecular(normalWS,mainLightDirection,viewDirectionWS,roughness,skinSurfaceData.rho_s * specular * specular,TEXTURE(DiffuseLUT));
    float3 TranslucencyColor = albedo * mainLightColor * PBRPreintegrateSkinTranslucency(positionWS,normalWSLow,thickness * shadowAttenuation * saturate(0.3 + dot(-normalWSLow,mainLightDirection)));
    return float4(GIColor +  (diffuseTerm + specularTerm + TranslucencyColor),1);                          
}
```

其中光照模型中还涉及到一个TranslucencyColor，主要是加强一些透光的效果。这个效果参考的是

[](http://www.iryoku.com/translucency/downloads/Real-Time-Realistic-Skin-Translucency.pdf)

这里有一个是通过采样shadowMap获得来自于光线方向的穿过物体表面后进入的深度，代码见`getDistanceFromShadowMap`。透光的效果如下：

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2020.png)

同时这里也使用diffuseProfile对光线穿过的厚度进行计算。注意这里要采用世界空间下的尺度，而非深度值。但是我直接*了一个scale手动调节到可以接受的结果就算了。可以看到这里眼睛也有一部分的透光，但是实际上以光穿透过去的厚度眼睛是透不了光的，原因就是在diffuseProfile的计算部分传入的参数并没有严格按照世界空间坐标的尺度，导致产生的结果偏亮。

至此预积分皮肤的shadingmodel就复现完毕了。其中比较关键的部分是diffuseProfile。而高光的部分可以根据想要的效果任意替换。而透光的部分也可以采取`dot(-N,L)`来进行。而阴影的部分我觉得效果不是很明显（GPU PRO2的对照如下），可以根据需求定制一个，并不一定要严格按照引擎使用的阴影算法来还原。IBL的部分因为我没有进行过进一步的计算，就不展开了。

![Untitled](%E9%A2%84%E7%A7%AF%E5%88%86%E7%9A%AE%E8%82%A4shading%205a83da97261c4e0787c83f9a6d5240ca/Untitled%2021.png)

视频参考如下：

https://vimeo.com/711506556

---

## TODO：

后续还是会想办法解决阴影贴图下LUT的问题。有这个想法主要是前段时间在做SSSS之类的研究的时候发现预积分的方案的确挺不错的，如果各方面适配好在移动端还是能打很长一段时间。