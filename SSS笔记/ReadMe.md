# SSS

SSS皮肤预积分LUT纹理生成参考这里的数学模型解释有了一个比较好的理解

[Pre-Integrated Skin Shading 数学模型理解](https://zhuanlan.zhihu.com/p/56052015)

网上找了一圈有挺多代码的了，还有一些修正的。写个笔记理解这个公式怎么通过代码来实现的：

![SSS%20282724a6f30943cbad597e33be214786/Untitled.png](SSS%20282724a6f30943cbad597e33be214786/Untitled.png)

上面的教程给了这么一个图，以这个图为例子。大白话来解释这个公式的意思就是，给定一个半球，求这个半球上的一个点P所受到其他所有点p' （图里面对应的是点Q） 的散射光的影响。 简化来看就是简化成一个半圆。

首先计算的是当光射到表面时候，点p' 所受到的光照度。

这里给了个公式是：

![SSS%20282724a6f30943cbad597e33be214786/Untitled%201.png](SSS%20282724a6f30943cbad597e33be214786/Untitled%201.png)

个人感觉就是把OQ当作法线然后套到兰伯特模型里面了。 至于是否要clamp01 的问题后面贴一个教程会有说，但是个人觉得限制或不限制影响也不是很大。（主要考虑到透光的问题似乎有另外一套解决方案，没有测试过不clamp01的情况下能不能模拟出比较好的透光效果）。

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

而q(x) 可以用diffusion profile 来实现。传送门上面教程有。 而q(x)中的 x 的参数为 任意一点p' 到 点P的距离。所以有公式如下：

![SSS%20282724a6f30943cbad597e33be214786/Untitled%202.png](SSS%20282724a6f30943cbad597e33be214786/Untitled%202.png)


伪代码如下：

```csharp
float theta = 0; 
float r = 0;
float d = 2r * sin(theta/2);
```

上面说了theta是可以通过迭代来求得所有的角度的。同理r也是这样。在c#实现里面可以用纹理贴图的高度来进行映射，在shader中也可以用uv来进行映射。这里有个问题是通过这个方法做出来的是查找表，而赋予材质的时候求曲率是需要用如下来获得查找坐标的1/r：

```glsl
fixed cuv = saturate(_CurveFactor * (length(fwidth(worldNormal)) / length(fwidth(worldPos))))
```

也可以先烘焙好一个曲率贴图来做采样。因为我还没有到拿这个模型到unity测试的阶段，这里先做个记录。

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

![SSS%20282724a6f30943cbad597e33be214786/Untitled%203.png](SSS%20282724a6f30943cbad597e33be214786/Untitled%203.png)

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

完整代码如下：

```csharp
//cosTheta 是 NdotV
//skinRadius 可以自行映射，我有看到过映射0-1的，也有0-2的
//inc理论上越小得到的结果越好
Vector3 IntegrateDiffuseScatteringOnRing(float cosTheta, float skinRadius){ 
        float theta = Mathf.Acos(cosTheta);
        Vector3 totalWeights = Vector3.zero; 
        Vector3 totalLight = Vector3.zero; 
        float a = -Mathf.PI; 
	        const float inc = 0.05f;
        while(a <= (Mathf.PI/2.0f)){ 
            float sampleAngle = theta + a;
            float diffuse = Mathf.Clamp01( Mathf.Cos(sampleAngle) ); 
            float sampleDist = Mathf.Abs( 2.0f * skinRadius * Mathf.Sin(a * 0.5f) ); 
            Vector3 weights = Scatter(sampleDist);
            totalWeights += weights; 
            totalLight += diffuse * weights; 
            a+=inc; 
        }
        Vector3 result = new Vector3(totalLight.x / totalWeights.x, totalLight.y / totalWeights.y, totalLight.z / totalWeights.z);
        return result;
    }
```

这里的代码其实是翻一个老帖找来的。以后有机会贴一下。普遍在知乎看到的都是用shader来实现的，但是需要转换到linearspace。如果是直接写个脚本的话应该没有这方面的操作。因为预烘焙所以也无所谓速度的问题了。但是最终的效果还没有对比测试过。留着以后再把能用的脚本放出来再对比效果。

关于是否clamp01 以及 是用球面还是半圆的问题看这里：

[预积分皮肤次表面散射LUT研究实践与遇到的问题（持续更新）](https://zhuanlan.zhihu.com/p/304213775)

而关于diffuseprofile中用到的高斯函数也有一些争议，所以有一些教程会把几个不同的实现都放进去。可以对比一下效果。

还有一个是上面说到是不是用c#就不需要转换空间的这个问题，也有说需要用到Tone Mapping的做法，具体结果也还是要留到后面做效果对比测试。

---

## 4.17更新：

关于取值范围是-pi~pi还是-pi/2~pi/2的这个问题，有说法是因为存在p‘在P点另外一侧的情况，但是其实从结果来看，如果我们对点p’受到的L的diffuseclamp的话，当L和Op‘的夹角大于>90°的时候已经是0了，所以哪怕是在对侧的时候其实p_diffuse也会出现0的情况。所以这里做了一个开关来决定范围问题。（反正GPUPRO2里面的代码是-pi/2 ~ pi/2）

目前来看测试出来的结果和别人用shader实现的有一些不一样，猜测是高斯函数的问题和曲率的取值范围的问题或者是Tone-mapping的问题(但是对比GPUPRO2里面和ppt里面的结果又比较接近)

反正到时候测出来几个贴图拿到模型对比一下效果看看有没有什么不同，看情况来使用就好了。

附结果：

![SSS%20282724a6f30943cbad597e33be214786/SSS_LUTHalf.png](SSS%20282724a6f30943cbad597e33be214786/SSS_LUTHalf.png)

halfPI

![SSS%20282724a6f30943cbad597e33be214786/SSS_LUT.png](SSS%20282724a6f30943cbad597e33be214786/SSS_LUT.png)

fullPI
