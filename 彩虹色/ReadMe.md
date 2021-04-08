# 彩虹色

记录一下前段时间tx笔试跪掉的两条材质题。

参考的是这个教程做的题

[Improving the Rainbow - Part 1 - Alan Zucconi](https://www.alanzucconi.com/2017/07/15/improving-the-rainbow/)

大概的做法原理是:

自然界中有很多重复排列的表面,因为这些表面加强了某一个波长的光,使得光在进入人眼的时候某一种或者几种颜色特别明显.而不同的波长对应的颜色不一样.然后教程中给出了一个模拟这个波长对应的颜色的一个函数.

而如何计算某一个波长的方法是计算光是否同相(具体的物理学意义可以看上面的教程)

![%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled.png](%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled.png)

假设光射到物体表面时,以第一束光n1接触到表面的时间开始计算. 计算n2到达表面时行走的距离x⬇️

![%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%201.png](%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%201.png)

同时计算n1反弹的距离y⬇️

![%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%202.png](%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%202.png)

如果x 和 y 相等或者互为整数倍,则两束光为同相.

所以给出的公式为:

![%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%203.png](%E5%BD%A9%E8%99%B9%E8%89%B2%20396813d5f3d64826b01d88e7bcbdb4e1/Untitled%203.png)

其中w是我们要求的波长,至于d和n是我们自定义给的变量.

教程中给出了一个计算sin_thetaL 和 sin_thetaV的方法. 我起初以为是这个是一个确定的方法(使用TdotV和TdotL)的,但是根据这一篇教程

[https://gen-graphics.blogspot.com/2018/02/fancy-shaders-oil-interference.html](https://gen-graphics.blogspot.com/2018/02/fancy-shaders-oil-interference.html)

给出的说法,其实不一定需要用上述的公式来求波长.因为我们已经有了一个很好的生成彩虹的函数,我们可以根据自己的需求来传递wavelength作为输入.比如说在上述教程中引入了油的折射率,再从一个贴图中采样出一个数值作为d.具体可以参考上述教程里的做法. 而根据:

[https://80.lv/articles/building-an-iridescence-shader-in-ue4/](https://80.lv/articles/building-an-iridescence-shader-in-ue4/)

的做法直接使用的是NdotH和NdotV的混合来作为输入(因为有一些节点没有看清楚,似乎后面还结合了uv还是什么内容.但是他应该没有使用到Tangent).

同时参考一下HDRP中对于iridescence材质的做法,unity使用的方法应该是参考了这一篇:

[https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html](https://belcour.github.io/blog/research/publication/2017/05/01/brdf-thin-film.html)

也可以去看HDRP中的BSDF.hlsl里面的EvalIridescence是怎么实现珠光色的.

这个做法的实现细节以后有机会再补一下..看了个大概没有深入研究~~(毕竟已经写好了).~~

另外一种做法是使用彩虹色贴图或梯度去做采样,通过使用噪声偏移uv的方法达到油污的效果.可以看这一个链接已经有比较好的实现:

[https://github.com/smkplus/Iridescence](https://github.com/smkplus/Iridescence)

个人觉得这种做法是比较可控(毕竟颜色可以自己控制).

之前还有一种做法是Hueshift,输入同样是NdotH作为输入,通过Hueshift来实现彩虹色.

参考ue4那个车漆的做法就可以了. 

上面可能会有一些是遗漏或者错误的(因为看不清他的图的连接方式,我自己按照这个做法效果和他的不太一样.猜测可能是输入里面加入了一些uv的修正或者是别的一些混合参数进行控制).

后面有机会补几个不同做法出来的效果对比.