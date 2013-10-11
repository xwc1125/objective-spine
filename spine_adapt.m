//
//  spine_adapt.c
//  PZTool
//
//  Created by Simon Kim on 13. 10. 9..
//  Copyright (c) 2013 DZPub.com. All rights reserved.
//

#include <stdio.h>
#include <spine/spine.h>
#include <spine/extension.h>
#include "spine_adapt.h"
#import <SpriteKit/SpriteKit.h>

static spine_adapt_createtexture_t _callback_createTexture = 0;
static spine_adapt_disposetexture_t _callback_disposeTexture = 0;

extern void spine_logUVS( float *uvs, int atlas_width, int atlas_height);

int spine_load_test(char *skeletonname, char *atlasname, float scale, char *animationName)
{
    struct spinecontext ctx;
    spine_load(&ctx, skeletonname, atlasname, scale, animationName);
    spine_dump_animation(&ctx, animationName);
    spine_dispose(&ctx);
    return 0;
}

int spine_load(struct spinecontext *ctx, const char *skeletonname, const char *atlasname, float scale, const char *animationName)
{
    spAtlas *atlas = spAtlas_readAtlasFile(atlasname);
    
	printf("First region name: %s, x: %d, y: %d\n", atlas->regions->name, atlas->regions->x, atlas->regions->y);
	printf("First page name: %s, size: %d, %d\n", atlas->pages->name, atlas->pages->width, atlas->pages->height);
    
	spSkeletonJson *json = spSkeletonJson_create(atlas);
    json->scale = scale;
    
	spSkeletonData *skeletonData = spSkeletonJson_readSkeletonDataFile(json, skeletonname);
	if (!skeletonData) {
		printf("Error: %s\n", json->error);
        return -1;
	}
    
	printf("Default skin name: %s\n", skeletonData->defaultSkin->name);
    
	spSkeleton* skeleton = spSkeleton_create(skeletonData);
    if ( animationName == 0 && skeletonData->animationCount > 0) {
        animationName = skeletonData->animations[0]->name;
        printf("spine: Selecting the first animation as a default:%s\n", animationName);
    }
    
    // animation
	spAnimation* animation = spSkeletonData_findAnimation(skeletonData, animationName);
	if (animation) {
        printf("Animation timelineCount: %d\n", animation->timelineCount);
        printf("Animation duration: %2.2f\n", animation->duration);
	} else {
        return -1;
    }
    
    
    spAnimationState *state;
	state = spAnimationState_create(spAnimationStateData_create(skeleton->data));
    
	spAnimationState_setAnimationByName(state, 0, animationName, 0);
    
	ctx->atlas = atlas;
    ctx->json = json;
    ctx->skeletonData = skeletonData;
    ctx->skeleton = skeleton;
    ctx->state = state;
    
	return 0;
}

int spine_dump_animation(struct spinecontext *ctx, const char *animationName)
{
    float time = 0;
    int trackIndex = 0;
    int loop = 0;
    
    spAnimationState *state = ctx->state;
    spSkeleton *skeleton = ctx->skeleton;
    spAtlas *atlas = ctx->atlas;
    
    if ( animationName == 0 && ctx->skeletonData->animationCount > 0) {
        animationName = ctx->skeletonData->animations[0]->name;
        printf("spine: Selecting the first animation as a default:%s\n", animationName);
    }
    
	spAnimation* animation = spSkeletonData_findAnimation(ctx->skeletonData, animationName);
    if ( animation == 0 ) {
        printf("spine: animation '%s' not found\n", animationName);
        return -1;
    }
    
	spSkeleton_update(skeleton, time);
	spAnimationState_setAnimationByName(state, trackIndex, animationName, loop);
    
    // slots
    do {
        printf( "time:%2.2f\n", time);
        
        spAnimationState_update(state, time);
        spAnimationState_apply(state, skeleton);
        spSkeleton_updateWorldTransform(skeleton);
        
        for (int i = 0, n = skeleton->slotCount; i < n; i++) {
            spSlot* slot = skeleton->drawOrder[i];
            if (!slot->attachment || slot->attachment->type != ATTACHMENT_REGION) continue;
            spRegionAttachment* attachment = (spRegionAttachment*)slot->attachment;
            float vertices[8];
            spRegionAttachment_computeWorldVertices(attachment, slot->skeleton->x, slot->skeleton->y, slot->bone, vertices);
            // 	float x, y, scaleX, scaleY, rotation, width, height;
            printf("%s:\n -attachment (%2.2f, %2.2f, %2.2f, %2.2f) scale: (%2.2f, %2.2f) rotation:%2.2f\n",
                   attachment->super.name,
                   attachment->x, attachment->y, attachment->width, attachment->height,
                   attachment->scaleX, attachment->scaleY, attachment->rotation);
            printf("- bone (%2.2f, %2.2f) scale: (%2.2f, %2.2f) rotation:%2.2f\n",
                   slot->bone->worldX, slot->bone->worldY,
                   slot->bone->worldScaleX, slot->bone->worldScaleY,
                   slot->bone->worldRotation);
            
            printf("- vertices: (%2.1f, %2.1f), (%2.1f, %2.1f), (%2.1f, %2.1f), (%2.1f, %2.1f)\n" \
                   "- uvs:(%2.2f, %2.2f), (%2.2f, %2.2f), (%2.2f, %2.2f), (%2.2f, %2.2f)\n" \
                   "- offset:(%2.2f, %2.2f), (%2.2f, %2.2f), (%2.2f, %2.2f), (%2.2f, %2.2f)\n",
                   vertices[VERTEX_X1], vertices[VERTEX_Y1],vertices[VERTEX_X2], vertices[VERTEX_Y2],
                   vertices[VERTEX_X3], vertices[VERTEX_Y3], vertices[VERTEX_X4],vertices[VERTEX_Y4],
                   attachment->uvs[VERTEX_X1], attachment->uvs[VERTEX_Y1], attachment->uvs[VERTEX_X2], attachment->uvs[VERTEX_Y2],
                   attachment->uvs[VERTEX_X3], attachment->uvs[VERTEX_Y3], attachment->uvs[VERTEX_X4],attachment->uvs[VERTEX_Y4],
                   attachment->offset[VERTEX_X1], attachment->offset[VERTEX_Y1],
                   attachment->offset[VERTEX_X2], attachment->offset[VERTEX_Y2],
                   attachment->offset[VERTEX_X3], attachment->offset[VERTEX_Y3],
                   attachment->offset[VERTEX_X4],attachment->offset[VERTEX_Y4]
                   );
            spine_logUVS(attachment->uvs, atlas->pages->width, atlas->pages->height);
            
        }
        time += 1;
    } while(time < animation->duration);
    return 0;
}

int spine_dispose( struct spinecontext *ctx)
{
    spAnimationState_dispose(ctx->state);
	spSkeleton_dispose(ctx->skeleton);
	spSkeletonData_dispose(ctx->skeletonData);
	spSkeletonJson_dispose(ctx->json);
	spAtlas_dispose(ctx->atlas);
    
    return 0;
}


#pragma mark - Spine Adaptation
void _spAtlasPage_createTexture (spAtlasPage* self, const char* path) {
    printf("%s[%d]: path='%s'\n", __FUNCTION__, __LINE__, path);
    if ( _callback_createTexture != 0 )
        self->rendererObject = _callback_createTexture(path, &self->width, &self->height);
}

void _spAtlasPage_disposeTexture (spAtlasPage* self) {
    if ( _callback_disposeTexture != 0) {
        _callback_disposeTexture(self->rendererObject);
    }
}

char* _spUtil_readFile (const char* path, int* length) {
	return _readFile([[[NSBundle mainBundle] pathForResource:@(path) ofType:nil] UTF8String], length);
}

void spine_set_handler_createtexture(spine_adapt_createtexture_t handler)
{
    _callback_createTexture = handler;
}
void spine_set_handler_disposetexture(spine_adapt_disposetexture_t handler)
{
    _callback_disposeTexture = handler;
}

#pragma mark - Spine Resource Loading Test

void spine_logUVS( float *uvs, int atlas_width, int atlas_height)
{
    // bl, tl, tr, br
    // or br, bl, tl, tr if rotated
    //    CGPoint tl = CGPointMake(uvs[VERTEX_X2], uvs[VERTEX_Y2]);
    //    CGPoint bl = CGPointMake(uvs[VERTEX_X1], uvs[VERTEX_Y1]);
    //    CGPoint tr = CGPointMake(uvs[VERTEX_X3], uvs[VERTEX_Y3]);
    //    CGPoint br = CGPointMake(uvs[VERTEX_X4], uvs[VERTEX_Y4]);
    CGRect rect;
    if ( uvs[VERTEX_X3] - uvs[VERTEX_X2] == 0) {
        // rotated
        rect.origin = CGPointMake(uvs[VERTEX_X3] * atlas_width, uvs[VERTEX_Y3] * atlas_height);
        rect.size = CGSizeMake((uvs[VERTEX_X1] - uvs[VERTEX_X2]) * atlas_width, (uvs[VERTEX_Y2] - uvs[VERTEX_Y3]) * atlas_height);
    } else {
        rect.origin = CGPointMake(uvs[VERTEX_X2] * atlas_width, uvs[VERTEX_Y2] * atlas_height);
        rect.size = CGSizeMake((uvs[VERTEX_X3] - uvs[VERTEX_X2]) * atlas_width, (uvs[VERTEX_Y1] - uvs[VERTEX_Y2]) * atlas_height);
    }
    NSLog(@"%@", NSStringFromCGRect(rect));
}

