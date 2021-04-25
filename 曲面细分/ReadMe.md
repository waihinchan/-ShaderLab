# 曲面细分

曲面细分的流程图

![%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86%20970f3853a0fe442d9bdcb3a8b8f5b7eb/Untitled.png](%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86%20970f3853a0fe442d9bdcb3a8b8f5b7eb/Untitled.png)

做了一个URP的光照版本的曲面细分，支持displacement。 目前还需要修复GPUINSTANCE和文件目录的一些重复问题（合并shadow和forwardpass的文件，写一个宏去定义就可以了，省点位置）

参考的是这个教程：[https://www.patreon.com/posts/45320078](https://www.patreon.com/posts/45320078)

但是教程中实现的是ulit版本，因为之前有移植过几何着色器到HDRP的经验，所以这个难度目前来看也不是很大。。

但是参考了HDRP的曲面细分的一些细节可能和直接这样魔改有一些不同。 同时它还提供了一个分层的曲面细分应该是用于地形的，以后把这个也加上去。

[https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/](https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/)

这里有对于曲面细分怎么实现有很好的解释（虽然还是没有解释算法问题，但是基本上够用了）

附效果图：

![https://github.com/waihinchan/Materialpractice/blob/main/%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86/%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86%20970f3853a0fe442d9bdcb3a8b8f5b7eb/%E6%95%88%E6%9E%9C%E5%9B%BE.png](https://github.com/waihinchan/Materialpractice/blob/main/%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86/%E6%9B%B2%E9%9D%A2%E7%BB%86%E5%88%86%20970f3853a0fe442d9bdcb3a8b8f5b7eb/%E6%95%88%E6%9E%9C%E5%9B%BE.png)


4.25 更新：

更新了一个可以用spltmap控制细分位置的版本，并且把部分重复的部分合并到一个文件中。displacement函数暂时没有合并，可以在shadowcaster和litforward单独控制（主要是把一些定义合并的话定义会更乱了。。暂时没有找到比较简洁的方法把这几个路径的定义合并在一起。。）

TODO： 
1.添加两层的法线、金属度、光泽度等（主要是贴图很难找就没动力去做了。。）
2.更新细分曲面专用的shaderGUI，关键字的定义等
3.添加对笔刷大小、形状、贴图和强度的支持
4.再继续简化一些定义的问题
5.看看有没有办法基于这些顶点或贴图生成mesh collider
