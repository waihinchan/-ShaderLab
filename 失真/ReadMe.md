# 失真

[Opaque Active Camouflage Part 1](http://vfxmike.blogspot.com/2018/06/opaque-adaptive-camouflage.html)

参考了这一个。但是没有使用贴图，除了失真贴图和主贴图基本上都使用内置的噪声来实现。视频见：

[Opaque Active Camouflage Part 1](http://vfxmike.blogspot.com/2018/06/opaque-adaptive-camouflage.html)

目前是通过grabpass来实现的屏幕空间颜色，和上述教程略有不同。这么做有个缺点是深度排序会有些问题，另外一个是没有pbr或者其他光照的效果。上述的教程是通过对同一个对象叠加两个材质来实现的。即底部的材质是原来的PBR材质，然后屏幕grabpass是上一帧（而非渲染完所有geometry后的那一帧，这样做可以使光学迷彩的效果也会叠加一部分到上一帧之中），然后再叠加一个材质在各个材质上再渲染一次。两者使用透明度来叠加。这样做有个好处是不用单独对每个材质再额外配置主贴图，而且可以获得光照效果，而且深度测试不会有问题。这个部分以后我再加上去。

文件夹附带了一个shadergraph。组织的比较乱，以后有机会再整理一下。目前对于噪声和过渡的部分处理的不是很好，感觉离自己想象的效果还有很大的提升空间。

主要的做法就是通过对UV进行分块，大块状制作数字故障的效果，小块状控制噪声和过渡的细节。