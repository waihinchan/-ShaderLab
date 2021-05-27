# 头发

尝试在URP中使用Kajiya-Kay方法渲染头发。参考了这一篇的做法：

[Hair Rendering and Shading](https://web.engr.oregonstate.edu/~mjb/cs519/Projects/Papers/HairRendering.pdf)

他这里说的是用的Kajiya-Kay + Marschners model来做的。

应用了Kajiya-Kay 的diffuse部分，但是说是太亮了所以微调了一下，用了一个插值。

然后关于高光的部分，说是根据 Marschners model高光分为主要高光和次要高光。

这一篇文章有比较详细的解读，反正最终的实现并不是上面两个模型的某一个，而是把两个项结合起来并且做一些修改

[Hair Rendering and Shading头发渲染和着色[GDC2004]](https://www.cnblogs.com/jaffhan/p/7382106.html)

在URP中直接把光照模型改了，暂时没有测试多层头发的alphatest和渲染顺序等问题。

个人感觉出来的效果高光部分有点硬，远看还可以近看就很明显了。

TODO：

1. 加入对fog的支持
2. 加入对bakeGI的支持
3. 加入参数修正高光范围控制和过硬的问题
4. 自定义材质GUI
5. 结合HDRP中对毛发的实现看看有没有提升的地方（主要是散射和透光的提升）

效果预览：

[vino_chan on Twitter: "HairMaterial Test at URP pic.twitter.com/bckkqpGnMr / Twitter"](https://twitter.com/vinochan16/status/1397471781737295872?s=20)

左侧的是用默认材质直接给maintex贴图的对比

![%E5%A4%B4%E5%8F%91%209d1286b6342f461ca0e9347753ec52bb/Untitled.png](%E5%A4%B4%E5%8F%91%209d1286b6342f461ca0e9347753ec52bb/Untitled.png)

模型和贴图用的这个：

[Male Hairstyle Short01 Low Poly Game Ready Model | CGTrader](https://www.cgtrader.com/items/2823018/download-page)

切线贴图和噪声贴图网上随便找一下就有了，我是给切线贴图加了个模糊效果来做噪声的，经测试如果不做的话那个高光会更硬，所以猜测切线贴图本身也需要加入一些模糊或者噪声的效果。

2021.5.27 更新：

如果要使用SRP batcher的话，把以下属性

float _primaryshift;
float _secnodaryshift;
float _exp1;
float _exp2;
float3 _SpecColor1;
float3 _SpecColor2;


放到Cbuffer即可，Cbuffer在litinput.hlsl.或者复制里面的内容然后自己重新自定义一下。


