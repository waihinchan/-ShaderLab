# 树木草地

草地：

草基于

[Unity Grass Geometry Shader Tutorial at Roystan](https://roystan.net/articles/grass-shader.html)

编辑器基于：

[Grass Geometry Shader with Interactivity (Part 2, the editor tool)](https://www.patreon.com/posts/grass-geometry-2-40077798)

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
