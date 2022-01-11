# 树木草地

# 草地

- 方案1
    
    草基于
    
    [Unity Grass Geometry Shader Tutorial at Roystan](https://roystan.net/articles/grass-shader.html)
    
    编辑器基于：
    
    [](https://www.patreon.com/posts/47447321)
    
    对比于原有的编辑器加入了用于泊松盘采样的方式来放置点，泊松盘采样的脚本附在里面了。仍然有一些小问题比如数组溢出之类的，目前通过简单的限制范围修复了。
    
    没有做顶点颜色和基于距离减少分割面的工作，因为上面的教程都有就不做了。
    
    加入了一个基于贴图采样用于交互对象和草地的交互。目前来看交互并不完美（如模型太小的时候会出现穿模的现象），但是总体来说看着像是那么一回事了。
    
    使用方法：
    
    把InteractWithGrass.cs放在需要交互的对象中（也可以在DrawTextures.cs中加入一个列表，再在面板里面拖进去，自己改一下就可以了），把DrawTextures.cs放在草地上。
    
    如果需要编辑草地，把GrassPainter放在草地上，在面板中编辑即可
    
    预览链接：
    
    [vino_chan on Twitter: "MultiInteraction with GrassBase on: https://t.co/DdhOeTc5jq pic.twitter.com/u39QODJfWm / Twitter"](https://twitter.com/vinochan16/status/1396672533970112519?s=20)
    
    TODO：
    
    把两层贴图或顶点颜色加入到shader中，同时重新做材质的GUI。目前交互的方式仅限于从上往下，即射线的方向为-up，后面可以考虑加入如交互对象在草地的哪一个方向，然后再进行射线的计算。
    
    因为需要多对象进行交互，所以没有办法像原教程那样直接把世界坐标传进去作为参数，这也就导致了需要在脚本中先计算物体是否与对象发生接触，再把位置坐标写入贴图。灵活性没有直接传参数那么高。
    
    ---
    
    [URP_GrassGeometryShader/Grass.hlsl at main · Cyanilux/URP_GrassGeometryShader](https://github.com/Cyanilux/URP_GrassGeometryShader/blob/main/GrassGeometry/Grass.hlsl#L225)
    
    [Unity Grass Geometry Shader Tutorial at Roystan](https://roystan.net/articles/grass-shader.html)
    

---

- 方案2：
    
    低成本为草地增加体积感。方案来自一篇论文：
    
    [DESIGN EXPORT](https://www.cg.tuwien.ac.at/research/publications/2007/Habel_2007_IAG/)
    

复现了一下发现效果还不错，虽然有一定的年份了。

论文的核心思路就是通过使用类似于视差的方法在在mesh表面生成类似于十字草的栅格。文中提及使用十字草的方式铺满地形和使用他们的方法对比，帧率分别是90vs140。可见这个方法存在一定的速度优势，但是实际上我认为手动铺设十字草的方式在美术表现上更自由且自定义属性更强，加之我本身没有对这个算法和十字草的方法进行性能测试对比，故在这里只提及如何复现，并不涉及性能孰强孰弱的讨论。

贴一个论文内的图：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled.png)

其实基本上看到这个图就已经明白它的核心思路是什么了，非常直观易懂。剩下的是一些实现的细节。

首先我们假设mesh是一个平面，如下图：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%201.png)

而我们的目标是生成类似于论文中的图片类似的效果，即：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%202.png)

即把插片垂直插在平面上（实际上它是十字插片，这里方便看图我就不画另外一边了）

然后我们有一个相机，在这个平面的上方：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%203.png)

则我们需要计算相机击中的每一个点是否在这个插片之上。如果在，在水平还是垂直插片，如果不在对应的地面的内容是什么。

这个论文的方法和一般视差不同之处在于，它可以使用固定的步序（我使用的5次）就可以获得比较好的效果。

假设我们的栅格是10 * 10的，那么每个插片在UV各自的方向的间隔就是1/10。（这个栅格的数量是自定义的）那么我们的固定步序就是1/10。这也是为什么这个方法可以使用比较少的步序就可以达到比较好的效果，因为一般的视差效果并不知道临近的像素采样到的高度图是否有遮挡，这使得每次步进的步长需要小心谨慎的控制才能达到比较自然的效果。而我们的栅格是均匀分布的，即每次固定的步序都必定能触碰到下一个栅格。

**公式1**：$hitpoint = uv + viewDirTS.xy * distance$

其中UV是当前栅格的所在的UV位置。而distance则是UV到下一个栅格的距离。这里有个实现的细节是，当第一次步进的时候，UV通常处于某个栅格构成的十字之内，此时distance通常小于我们的步序（即上面提及的1/10）。那么这个distance是如何计算的呢，由于我们的栅格是均匀分布，且我们可以知道根据viewDirTS的方向（正向则为和UV同行，负则相反）可以预先判别到光线触碰到下一个栅格是哪一个，此时我们使用`floor(uv*GRID)/GRID` 则可以计算出下一个栅格所在的UV位置。根据终点=起点 + 方向 * 距离，我们可以得到

$distance = (nextGrid - uv) / direction$

注意这里我们是对U和V方向分别计算的，那么我们在除方向时要除以方向的分量。

此时我们就得到了光线分别沿着U和V方向触碰到对应的栅格的距离。

此时$nextGrid = min(distanceU,distanceV)$

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%204.png)

当触碰到栅格后我们就可以根据公式1得到Hitpint的位置。 此时就要祭出论文使用的贴图：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%205.png)

它是类似于把插片分割成若干个部分，同时和十字草一样保留Alpha通道。那么此时我们就可以找到插片对应的贴图中的UV。

$V = (hitpoint.z + grid_i.x(grid_i.y)) * PREMULT$

其中我们可以把`hitpoint.z` 看作采样时垂直方向V的偏移，而PREMULT则是使用的贴图切片种类（上图中为8个）与插片数量的比值（如10*10，则为10）。 此外对应的U则是击中对应栅格的垂直分量（如击中的是和U方向水平的栅格，则使用U.y，反之使用V.x）

那么当我们有了UV以后，我们就可以对贴图进行采样，此时就和传统的视差算法一致，不过此时我们采样的并非高度，而是贴图的A通道。我们可以想象如果光线触碰到地方“有草”的话，那么此时的alpha通道则为1，反之如果触碰不到草，那么光就从这一个栅格穿过去，到达下一个栅格，进行下一次步进。那么此时采样到的alpha通道则为0。通过使用这种方法我们可以提早结束循环。通常总步数5次就可以采样对应的内容（或超出最大高度飞出去）。

此外我们还需要规定一个插片的最大深度，如果光线直接“直直地”插入到地面，而非插片的话，我们则使用一张传统的草地贴图GroundMap，比如这种：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%206.png)

而判别的方法只需要人为地规定一个最大深度GRASSDEPTH，当我们在上面求得的distance的Z分量大于这个数值，就说明光线触碰到了地面而非插片。需要注意的是，Z分量总是负数，我们需要取反后再进行对比。

此时我们仍然可以根据distance来推算出hitpoint的位置，并直接使用hitpoint的xy分量作为UV对GroundMap进行采样。

另外为了避免步进时有些光线的确比较刁钻（比如近乎水平的观察平面），导致既没有采样到地面也没有采样到栅格，我们可以使用一张额外的lookuptex对没有采样到的部分（即经历了5次循环后a通道仍然为0的像素点）进行“填色”，这里也可以直接给一个纯色代替。

代码实现的细节见文件，这里就不过多赘述了。此时我们有了如下的效果：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%207.png)

我们发现如果把物体置于上面，物体好像是漂浮在上面的一般。

论文提及了一个修改深度的方法使得草插片像真实的草一样对物体进行遮挡。由于我们计算出了uv在触碰到栅格前所移动的距离distance，我们可以把这个distance作为深度的偏移量（即在原有的基础上，加上沿着viewDirTS的方向进行的偏移，并重新计算出深度值进行修改）

这里我在Unity里面复现的时候有个小问题是，如果直接修改ClipSpace下的数值写入深度似乎和得出的方向是相反的，所以我转置了世界空间到切线空间的矩阵并修改了世界空间坐标，然后重新计算clipspace并得出深度：

```glsl
float3x3 transposeTangent = (float3x3(input.tangentWS.xyz,input.tangentWS.w * cross(input.normalWS,input.tangentWS.xyz),input.normalWS));
float3 offset = TransformTangentToWorldDir(viewDirTSreal,transposeTangent,true);
float4 fix =    TransformWorldToHClip(input.posWS - offset.xyz * _ZoffsetFactor * zOffset  );
result.outDepth = (fix.z/fix.w);
```

同时由于我们计算视差的时候是对viewDir进行取反的，但是在转置的时候还是需要使用原本的ViewDirTS。（这里也有可能是我有一些符号没有计算正确，反正测试过好多次是用原本的ViewDirTS在正确）

另外，论文中的实现是没有对这个深度偏移值进行缩放的，但实际上这个深度偏移值是基于UV之间的distance计算出来的，实际上非常小，所以这里加入了一个自定义项用于缩放深度值。

论文中的实现：

```glsl
//推测这个是裁剪（投影）空间，所以zOffset出来的数值可能是会比较小的。
positionViewProj += mul(worldViewProj,eyeDirTan.xzy*zOffset); 

//可以看到这里也是有做齐次除法的，所以上面那个应该是世界-观测-裁剪空间的转换。
depth = positionView.z/positionView.w; 

```

至此我们就有了物体插入草地中的效果了：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%208.png)

论文中还提及到加入风的影响，由于这个做法比较常规，这里就不展开来说了，具体看实现即可。

---

下面是我对于这个算法做出一些额外的修改。

首先是现在很多的视差效果都会有自阴影的效果，由于我们的步序最多也就是5次，所以把自阴影的部分加进去也就仅仅是多了几次而已。这里使用了UE POM的算法，思路和上面的步进思路非常相似，但于此不同的是我们这次使用的是光的方向而非视线的方向，并且我们使用的是我们在前面步进获取到的UV作为起点，沿着光线的方向反推，检测光在照射到之前是否被其他更高的栅格所遮挡了，如果被遮挡我们就为其添加上阴影。

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%209.png)

如果太黑的话，这里可以加入一个修正项

每次的步进：

```glsl
shadow -= checkOutMaxHeight * checkAlpha  * _k  / (moveDistance*_ShadowFactor);
```

这样就可以让草坪整体有那么一点自阴影不至于太亮。

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2010.png)

不过在片元阶段输出MRT的做法有个缺点是，如果我们想要草的栅格影响到其他物件上的时候，就无能为力了，本质上我们这些插片最终都是要被填满的，所以深度输出出来是是一层一层的插片，而非一层一层的草。

错误的阴影：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2011.png)

如果说在片元阶段就做这个事情的话，我们还需要修改步进的逻辑，使得当步进的时候如果没有触碰到草就跳出循环并写入深度，这样可以制作出类似于草一根一根的阴影效果（不一定有我说的那么简单，总觉得没有那么顺利）

第二个修改项是修改了人为指定的这个草的最大深度GRASSDEPTH，论文中直接使用插片草贴图的数量的倒数作为GRASSDEPTH，这么做的好处是在采样UV的时候不会有不自然的拉伸。但是当我们把这个东西放到场景中的时候我们会发现草的大小居然是和插片贴图的数量有关系的，理论上如果我们给16种草和32种草它的插片高度会不同。这使得大小比例很难控制。而如果我们要自定义GRASSDEPTH就需要解决拉伸的问题，这里用一个remap方法把distance.z 从自定义的草深度重新映射到贴图里面单个草的高度。

```glsl
v_offset = remap(v_offset,float2(-GRASSDEPTH,0),float2(-GRASS_TYPE_INV,0));
```

同时我们直接缩放U分量，就可以自由控制草的高度了：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2012.png)

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2013.png)

最后一个问题是，虽然这个做法我们在侧面看草地的时候可以获得比较好的效果。但是我们从上方垂直往下看的时候，还是会“穿帮”：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2014.png)

可以看出很明显的栅格感。虽然我们可以增加栅格的数量来缓解这种情况，但是加的太多就会太密集，加的太少状况就没有办法缓解。

这里可以通过稍微偏移插片的方向,使得插片略微与视线方向垂直来略微修复这个问题. 这个灵感来自于一个论坛,但是那个视频已经找不到了.视频中针对的billboard的优化,但是我认为同样可以应用在这里.

只需要在预计算出终点后,让终点绕u或v方向旋转若干角度,旋转的角度由viewDirTS.z来控制即可.

这里拿了K神的代码来直接用

```c
float3x3 AngleAxis3x3(float angle, float3 axis) { //https://github.com/search?q=user%3Akeijiro+AngleAxis3x3&type=code
	float c, s;
	sincos(angle, s, c); //https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-sincos

	float t = 1 - c;
	float x = axis.x;
	float y = axis.y;
	float z = axis.z;

	return float3x3(
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c
	);
}
```

然后把viewDirTs.z的因素放进去:

```c

float zBendFactor =  zBendFactor = SAMPLE_TEXTURE2D(_TileMap, sampler_TileMap, float2(0,-viewDirTS.z)) ;
float rotateradius =  _Zlerp* zBendFactor;
float3x3 ZFactorMatrixX = AngleAxis3x3( rotateradius , float3(0,0,planemod.x));
float3x3 ZFactorMatrixY = AngleAxis3x3( rotateradius, float3(0,planemod.y,0));
//下面的部分是在for loop里面做的
destination.x = mul(ZFactorMatrixX,startAt.x); //计算完终点后绕对应的轴旋转
destination.y = mul(ZFactorMatrixY,startAt.y);
```

这个`_TileMap` 是一个简单的梯度图，因为自定义的倾斜曲线比较难用公式拟合出来，这个是参考Unity官方的WaterShader案例得出的灵感。（如果想纯用类似于remap和smoothstep的方法去做倾斜出来的效果很难控制，可以自己试一下，或者有更好的方法欢迎提出）

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2015.png)

倾斜前：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2016.png)

倾斜后：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2017.png)

这个方法同样也可以用来做局部的交互。这里就不过多赘述了。

另外一个优化方法是也是根据viewDIrTS.z,和groundMap进行最终颜色的插值。测试过其实总体视觉上看起来略微能消除grid的感觉.

Blend前：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2018.png)

Blend后：

![Untitled](%E6%A0%91%E6%9C%A8%E8%8D%89%E5%9C%B0%20fc873aa390d44367bdbdf93174482c94/Untitled%2019.png)

最后把材质移到地形上看看效果：

[https://vimeo.com/664660063](https://vimeo.com/664660063)

总体上而言，这个做法对于平面的效果很好，或者对于曲率不是很大的几何体也有一定的效果。不过针对于那种巨型的mesh，必须要把栅格的数量增加到成百上千才能铺满，有时候在远方看就会显得很密集。但是如果针对一些独立的小花坛、小范围的草地，这个效果能增加草地的体积感，在性能上多少比放满十字插片的效果也来的好一点。