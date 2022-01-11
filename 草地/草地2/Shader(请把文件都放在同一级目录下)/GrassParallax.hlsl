#ifndef GRASS_PARALLAX_INCLUDE
#define GRASS_PARALLAX_INCLUDE

struct GrassParllaxResult{
    float4 outAlbedo;
    #ifdef _GRASSSELFSHDOW
        float outShadow;
    #endif
    float2 outUV;
    float hitGround; //这个是为了避免在视差中要采样好多次 直接给给一个加权的因子就完事了。当然最好的方法是用贴图数组 这样直接给UV和Index就可以了
    float hitSlice; //这两者是互斥的
    float outDepth;

};
//这个部分其实是可以直接用Varyings的但是由于不想破坏引用文件的结构，这里多搞一个结构体
struct GrassRawData{
    float3 viewDirWS;
    float2 uv;
    float4 tangentWS;
    float3 normalWS;
    float2 winduv;
    float3 posWS;
    
};
GrassParllaxResult getGrass(GrassRawData input){
    GrassParllaxResult result = (GrassParllaxResult)0;
    result.hitGround = 0;
    result.hitSlice = 0;
    float4 color = float4(0.0,0.0,0.0,0.0);
    float3 realViewWS = -input.viewDirWS; //这个等下用来做深度偏移的修正
    float3 viewDirTS = normalize(GetViewDirectionTangentSpace(input.tangentWS,input.normalWS,input.viewDirWS));//先插值再归一化
    float3 viewDirTSreal = normalize(GetViewDirectionTangentSpace(input.tangentWS,input.normalWS,realViewWS));
    
    float3 rayEntry = float3(input.uv.xy,0.0); //指物体表面的射线入口。
    float4 GroundUVST = _GroundMap_ST;//reference:#define TRANSFORM_TEX(tex, name) ((tex.xy) * name##_ST.xy + name##_ST.zw)
    float2 grid_offset = float2(0.0,0.0);//步进的记录，初始为0。
    float2 sign_ = float2( sign(viewDirTS.x),sign(viewDirTS.y) );
    float2 slice_correct = float2( (sign_.x+1)*GRASS_TYPE_INV_DIV2, (sign_.y+1)*GRASS_TYPE_INV_DIV2 );
    float2 planemod = float2( floor(rayEntry.x*GRASSGRID)/GRASSGRID, floor(rayEntry.y*GRASSGRID)/GRASSGRID ); //把uv分成N*N的栅格
    float2 grid_correct = float2((sign_.x+1)*PLANE_NUM_INV_DIV2, (sign_.y+1)*PLANE_NUM_INV_DIV2 ); 
    int hitcount = 0;
    float zOffset = 0.0;
    bool zFlag = 1;
    float3 finalHitRecord = float3(0,0,0);
    float3 branchRecordPos = float3(0,0,0);
    float2 ddxUV = ddx(input.uv);
    float2 ddyUV = ddy(input.uv);

    float zBendFactor  = SAMPLE_TEXTURE2D(_TileMap, sampler_TileMap, float2(0,-viewDirTS.z)) ;
    float rotateradius =  _Zlerp* zBendFactor;

     
    float3x3 ZFactorMatrixX = AngleAxis3x3( rotateradius , float3(0,0,planemod.x));
    float3x3 ZFactorMatrixY = AngleAxis3x3( rotateradius, float3(0,planemod.y,0));
    
    for(hitcount = 0; hitcount < MAX_RAYDEPTH && zFlag>0; hitcount++){
        float2 direction = float2(sign_.x*grid_offset.x+grid_correct.x,sign_.y*grid_offset.y+grid_correct.y);	
        float2 startAt = float2(planemod.x + direction.x - rayEntry.x,planemod.y + direction.y - rayEntry.y);
        // ZFactorMatrixX = ZFactorMatrixY;
        startAt.x = mul(ZFactorMatrixX,startAt.x);
        startAt.y = mul(ZFactorMatrixY,startAt.y);
        float2 distance_ = float2(startAt.x/viewDirTS.x,startAt.y/viewDirTS.y);
        float3 rayHitpointX = rayEntry + viewDirTS *distance_.x;   
        float3 rayHitpointY = rayEntry + viewDirTS *distance_.y;

        if (rayHitpointX.z <= -GRASSDEPTH && rayHitpointY.z <= -GRASSDEPTH){
            float distanceZ = -GRASSDEPTH/viewDirTS.z;
            float3 rayHitpointZ = rayEntry + viewDirTS *distanceZ;
            float2 orthoLookupZ = float2(rayHitpointZ.x,rayHitpointZ.y) * GroundUVST.xy + GroundUVST.zw; 
            rayHitpointZ = float3(rayHitpointZ.x,rayHitpointZ.y,-GRASSDEPTH);
            finalHitRecord += (1.0-color.w) * rayHitpointZ;
            color = color+ (1.0-color.w) *  SAMPLE_TEXTURE2D_GRAD(_GroundMap, sampler_GroundMap, orthoLookupZ,ddxUV,ddyUV);
            if(zFlag ==1) {
                result.hitGround = 1;
                result.outUV = orthoLookupZ;
                zOffset = distanceZ; 
            }
            zFlag = 0; 
        }
        else{
            //没有击中地面说明击中了grid
            float2 orthoLookup; 
            //对比那个距离短，就说明先击中了哪一个grid
            float v_offset;
            float gridToSlice;
            if(distance_.x <= distance_.y){
                
                float4 wind = SAMPLE_TEXTURE2D_GRAD(_Windnoise, sampler_Windnoise, input.winduv+rayHitpointX.xy/8,ddxUV,ddyUV)-0.5/2;
                v_offset = rayHitpointX.z;//z分量映射到slice的v的偏移
                v_offset = remap(v_offset,float2(-GRASSDEPTH,0),float2(-GRASS_TYPE_INV,0));
                gridToSlice = (planemod.x+sign_.x*grid_offset.x)*PREMULT;//planemod是这个rayentery原本的位置，+号的部分是步进后的grid_i+N或者grid_i-N *premult后就是grid对应的slice
                float lookupX = -(gridToSlice + v_offset) - slice_correct.x;
                
                //因为射线是从上往下打的，这个z是从每一个slice的上方到下方的距离，那就是说我们找到步进后对应的slice后，要减去z得到实际的对应位置
                // +slice correct是假设当前是正方向且击中的是下一个栅格，那么用plandemod取到的就是当前的栅格，那么还需要偏移一个栅格。
                // 如果是步进了一个单位后，那起点就从grid_i+1开始计算，那么仍然需要再偏移一个栅格
                orthoLookup=float2(rayHitpointX.y + wind.x*(GRASSDEPTH+rayHitpointX.z),-lookupX); //如果是和U平行，就用U，如果是V平行，就用V 来做uv的u。
                grid_offset.x += 1/GRASSGRID; //步进到下一个栅格
                if(zFlag==1) zOffset = distance_.x;
                branchRecordPos = rayHitpointX;
            }
            else{
                float4 wind = SAMPLE_TEXTURE2D_GRAD(_Windnoise, sampler_Windnoise, input.winduv+rayHitpointY.xy/8,ddxUV,ddyUV)-0.5/2;
                v_offset = rayHitpointY.z;
                v_offset = remap(v_offset,float2(-GRASSDEPTH,0),float2(-GRASS_TYPE_INV,0));
                gridToSlice = (planemod.y+sign_.y*grid_offset.y)*PREMULT;
                float lookupY = -(gridToSlice + v_offset) - slice_correct.y;
                
        
                orthoLookup = float2( rayHitpointY.x + wind.y*(GRASSDEPTH+rayHitpointY.z),-lookupY);
                grid_offset.y += 1/GRASSGRID;  
                if(zFlag==1) zOffset = distance_.y;
                branchRecordPos = rayHitpointY;
            }
            orthoLookup.x *= _GrassHeight;
            color += (1.0-color.w)*SAMPLE_TEXTURE2D_GRAD(_GrassBlade, sampler_GrassBlade, orthoLookup,ddxUV,ddyUV);
            finalHitRecord += (1.0-color.w) * branchRecordPos;
            
            if(color.w >= 0.49){
                zFlag = 0;
                result.hitSlice = 1;
                result.outUV = orthoLookup;
                
            }	
        }
    }
    color += (1.0-color.w)*SAMPLE_TEXTURE2D_GRAD(_LookUpTex, sampler_LookUpTex, rayEntry.xy,ddxUV,ddyUV); //万一有一些没计算到的就用这个来补一个色
    //这里还要优化一下这个深度写入的问题。
    float3x3 transposeTangent = (float3x3(input.tangentWS.xyz,input.tangentWS.w * cross(input.normalWS,input.tangentWS.xyz),input.normalWS));
    float3 offset = TransformTangentToWorldDir(viewDirTSreal,transposeTangent,true);
    float4 fix =    TransformWorldToHClip(input.posWS - offset.xyz * _ZoffsetFactor * zOffset  );
    result.outDepth = (fix.z/fix.w); //先记录Depth 这个是不会变的
    result.outAlbedo = color;
    result.outAlbedo =  lerp(result.outAlbedo,SAMPLE_TEXTURE2D_GRAD(_GroundMap, sampler_GroundMap, input.uv * GroundUVST.xy + GroundUVST.zw,ddxUV,ddyUV), zBendFactor*_BlendGoundFactor);
    #ifdef _GRASSSELFSHDOW
        Light mainlight = GetMainLight();
        float3 lightdirection =  mainlight.direction.xyz; 
        //Use CommandBuffer.SetGlobalVector to send the light data to the GPU. 
        //while the direction is the light transformation's forward vector negated.
        //buffer.SetGlobalVector(dirLightDirectionId, -light.transform.forward);
        // lightdirection *= float3(-1,1,-1); 
        //如果是这个就等于我们在场景编辑器里面看到的和UV方向（切线）同向，但实际上我们是从底部往上打，所以不要做这个修正的结果是正确的。
        // 之前看NDOTL看的太爽了其实实际上自己没有对方向注意过这个问题

        float3 tangentLightVector = GetViewDirectionTangentSpace(input.tangentWS,input.normalWS,lightdirection );
        float2 shadow_grid_offset = float2(1/GRASSGRID,1/GRASSGRID);
        float2 sign_Light = float2(sign(tangentLightVector.x),sign(tangentLightVector.y)); 
        float shadow = 1; //初始阴影为1，即为不衰减。
        float moveDistance = 0;//距离衰减系数 初始为0
        float2 shadowMod = float2(floor(finalHitRecord.x*GRASSGRID)/GRASSGRID,floor(finalHitRecord.y*GRASSGRID)/GRASSGRID);
        float recordZ;
        float2 shadow_grid_correct = float2((sign_Light.x+1)*PLANE_NUM_INV_DIV2,(sign_Light.y+1)*PLANE_NUM_INV_DIV2);
        float2 shadow_slice_correct = float2((sign_Light.x+1)*GRASS_TYPE_INV_DIV2,(sign_Light.y+1)*GRASS_TYPE_INV_DIV2);
        float2 preCalPoint = float2(sign_Light.x*shadow_grid_offset.x+shadow_grid_correct.x,sign_Light.y*shadow_grid_offset.y+shadow_grid_correct.y);
        float2 startAt = float2(preCalPoint.x + shadowMod.x - finalHitRecord.x,preCalPoint.y + shadowMod.y - finalHitRecord.y);
        float2 distance_shadow = float2(startAt.x/tangentLightVector.x,startAt.y/tangentLightVector.y);
        float3 rayHitpointX = finalHitRecord + tangentLightVector *distance_shadow.x;
        float3 rayHitpointY = finalHitRecord + tangentLightVector *distance_shadow.y;
        float shadowhitcount;
        float checkOutMaxHeight;
        for(shadowhitcount=0;shadowhitcount<MAX_RAYDEPTH;shadowhitcount++ ){ 
            float2 preCalPoint = float2(sign_Light.x*shadow_grid_offset.x+shadow_grid_correct.x,sign_Light.y*shadow_grid_offset.y+shadow_grid_correct.y);	
            float2 startAt = float2(preCalPoint.x + shadowMod.x - finalHitRecord.x,preCalPoint.y + shadowMod.y - finalHitRecord.y);
            float2 distance_shadow = float2(startAt.x/tangentLightVector.x,startAt.y/tangentLightVector.y);
            float2 orthoLookup_Shadow; 
            //计算出距离后 从原来的finalHitRecord中往上射点，注意他的Z是负的 但光的方向是正的 就是看它从底部能往上射出去有多高
            float3 rayHitpointX = finalHitRecord + tangentLightVector *distance_shadow.x;   
            float3 rayHitpointY = finalHitRecord + tangentLightVector *distance_shadow.y;
            float v_offset; //voffset仍然是负的，因为最初是从0往下找 现在是往上找 如果超出0那就是飞出去了
            float gridToSlice;
            if(distance_shadow.x <= distance_shadow.y){
                float4 wind = SAMPLE_TEXTURE2D_GRAD(_Windnoise, sampler_Windnoise, input.winduv+rayHitpointX.xy/4,ddxUV,ddyUV)-0.5/2;
                v_offset = rayHitpointX.z;
                v_offset = remap(v_offset,float2(-GRASSDEPTH,0),float2(-GRASS_TYPE_INV,0));
                gridToSlice = (shadowMod.x+sign_Light.x*shadow_grid_offset.x)*PREMULT;
                float lookupX = -(gridToSlice + v_offset) - shadow_slice_correct.x;
                orthoLookup_Shadow=float2(rayHitpointX.y + wind.x * (GRASSDEPTH - rayHitpointX.z),-lookupX);
                shadow_grid_offset.x += 1/GRASSGRID;
                recordZ = -rayHitpointX.z;
                moveDistance += distance_shadow.x; 
            }
            else{
                float4 wind = SAMPLE_TEXTURE2D_GRAD(_Windnoise, sampler_Windnoise, input.winduv+rayHitpointY.xy/4,ddxUV,ddyUV)-0.5/2;
                v_offset = rayHitpointY.z;
                v_offset = remap(v_offset,float2(-GRASSDEPTH,0),float2(-GRASS_TYPE_INV,0));
                gridToSlice = (shadowMod.y+sign_Light.y*shadow_grid_offset.y)*PREMULT;
                float lookupY = -(gridToSlice + v_offset) - shadow_slice_correct.y; 
                orthoLookup_Shadow=float2(rayHitpointY.x + wind.y * (GRASSDEPTH - rayHitpointY.z),-lookupY); 
                shadow_grid_offset.y += 1/GRASSGRID; 
                recordZ = -rayHitpointY.z;
                moveDistance += distance_shadow.y; 
            }
            checkOutMaxHeight = step(0,-recordZ) ;   
            if(finalHitRecord.z > -GRASSDEPTH){
                recordZ = -recordZ;  //这个正负方向也还是有点问题 暂时的方案是这个
            }
            orthoLookup_Shadow.x *= _GrassHeight;
            float checkAlpha = SAMPLE_TEXTURE2D_GRAD(_GrassBlade, sampler_GrassBlade, orthoLookup_Shadow,ddxUV,ddyUV).w;
            checkOutMaxHeight = step(0,recordZ) ;   
            shadow -= checkOutMaxHeight * checkAlpha  * _k  / (moveDistance*_ShadowFactor);
        }
        result.outShadow = shadow; //其实不要这个东西也可以 又或者说可以拿出去外面做计算。
        result.outAlbedo *= min(1,_ShadowColor + max(0,shadow)) ;
    #endif
    return result;
}

#endif