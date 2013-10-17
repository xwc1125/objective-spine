//
//  DZSpineSceneDescription.m
//  PZTool
//
//  Created by Simon Kim on 13. 10. 14..
//  Copyright (c) 2013년 DZPub.com. All rights reserved.
//

#import "DZSpineSceneDescription.h"
#import "DZSpineSceneBuilder.h"
#import "DZSpineSceneTrack.h"

@interface DZSpineSceneDescription()
@property (nonatomic, readonly) NSMutableArray *tracks;
@property (nonatomic, readonly) NSMutableArray *textures;
@end

@implementation DZSpineSceneDescription
@synthesize tracks = _tracks;
@synthesize textures = _textures;


- (NSMutableArray *) tracks
{
    if ( _tracks == nil) {
        _tracks = [NSMutableArray array];
    }
    return _tracks;
}


- (NSMutableArray *) textures
{
    if ( _textures == nil) {
        _textures = [NSMutableArray array];
    }
    return _textures;
}

- (void) addTrackRaw:(NSDictionary *) raw
{
    /*
    @{ @"skeleton" : @"butterfly",
       @"scale" : @(0.3),
       @"position" : NSStringFromCGPoint(CGPointMake(200, -200)),
       @"animations" : @[ @{@"name" : @"animation"}, @{@"delay" : @(0.3)}, @{@"name" : @"butterfly2"}, @{@"delay" : @(0.3)}, @{@"name" : @"butterfly3"} ],
       @"loop" : @(YES),
       @"wait" : @(YES) },
     */
    [self.tracks addObject:raw];
}

- (void) addCustomTextureRaw:(NSDictionary *) raw
{
/*
 @{ @"skeleton" : @"lion",
 @"textureName" : @"lion_custom_head1",
 @"rect" : NSStringFromCGRect(CGRectMake(0, 0, 1, 1)),
 @"slot" : @"Lion_Sqnc1_head"},
 
 */
    [self.textures addObject:raw];
}

+ (id) buildNodeWithSkeleton:(SpineSkeleton *) skeleton animations:(NSArray *) animations loop:(BOOL) loop
                    position:(CGPoint) position textures:(NSArray *) textures
{
    SKNode *node = nil;
    DZSpineSceneBuilder *builder = [DZSpineSceneBuilder builder];
    
    // Textures
    [textures enumerateObjectsUsingBlock:^(NSDictionary *texture, NSUInteger idx, BOOL *stop) {
        CGRect rect = CGRectMake(0, 0, 1, 1);
        if (texture[@"rect"]) {
            rect = CGRectFromString(texture[@"rect"]);
        }
        [builder setTextureName:texture[@"textureName"] rect:rect toSlot:texture[@"slot"]];
    }];

    node = [builder nodeWithSkeleton:skeleton animations:animations loop:loop];
    
    SKNode *placement = [SKNode node];
    placement.position = position;
    [placement addChild:node];
    node = placement;

    return node;
}

+ (NSArray *) extractAnimationsFromDescs:(NSArray *) animDescs skeleton:(SpineSkeleton *) skeleton duration:(CGFloat *) pduration
{
    // Animations
    NSMutableArray *animations = [NSMutableArray array];
    CGFloat duration = 0;
    for (NSDictionary *animDesc in animDescs) {
        NSString *name = animDesc[@"name"];
        SpineAnimation *animation = nil;
        if ( name ) {
            animation = [skeleton animationWithName:name];
        } else if (animDesc[@"delay"]) {
            animation = [SpineAnimation animationWithName:@"delay" duration:[animDesc[@"delay"] floatValue]];
        } else if ( animDesc[@"delayUntil"]) {
            CGFloat delay = [animDesc[@"delayUntil"] floatValue];
            if ( delay > duration ) {
                animation = [SpineAnimation animationWithName:@"delay" duration:delay - duration];
                NSLog(@"delayUntil:%2.3f duration:%2.3f delay:%2.3f", delay, duration, delay - duration);
            }
        }
        if ( animation ) {
            [animations addObject:animation];
            duration += animation.duration;
            NSLog(@" - %@:%2.3f", animation.name, animation.duration);
        }
    }
    *pduration = duration;
    return [animations copy];
}

- (NSArray *) buildScene
{
    NSMutableArray *nodes = [NSMutableArray array];
    NSMutableArray *trackObjs = [NSMutableArray array];
    
    CGFloat maxDuration = 0;
    for (NSDictionary *trackRaw in self.tracks ) {
        DZSpineSceneTrack *track = [[DZSpineSceneTrack alloc] init];
        track.loop = [trackRaw[@"loop"] boolValue];
        track.wait = [trackRaw[@"wait"] boolValue];
        track.skeletonName = trackRaw[@"skeleton"];
        track.position = CGPointMake(0, 0);
        CGFloat scale = 1;
        
        if ( trackRaw[@"scale"]) {
            scale = [trackRaw[@"scale"] floatValue];
        }
        
        if ( trackRaw[@"position"]) {
            track.position = CGPointFromString(trackRaw[@"position"]);
        }
        NSArray *animationDescs = trackRaw[@"animations"];
        
        track.skeleton = [DZSpineSceneBuilder loadSkeletonName:track.skeletonName scale:scale];
        CGFloat duration = 0;
        NSLog(@"Track Skeleton:%@", track.skeletonName);
        track.animations = [[self class] extractAnimationsFromDescs:animationDescs skeleton:track.skeleton duration:&duration];
        maxDuration = MAX(maxDuration, duration);
        track.duration = duration;
        [trackObjs addObject:track];
    }

    for (DZSpineSceneTrack *track in trackObjs) {
        if (track.wait && track.duration < maxDuration ) {
            NSMutableArray *anims = [NSMutableArray arrayWithArray:track.animations];
            [anims addObject:[SpineAnimation animationWithName:@"delay" duration:maxDuration - track.duration]];
            track.animations = [anims copy];
        }
        NSMutableArray *textures = [NSMutableArray array];
        [self.textures enumerateObjectsUsingBlock:^(NSDictionary *texture, NSUInteger idx, BOOL *stop) {
            if ([texture[@"skeleton"] isEqualToString:track.skeletonName]) {
                [textures addObject:texture];
            }
        }];
        [nodes addObject:[[self class] buildNodeWithSkeleton:track.skeleton animations:track.animations loop:track.loop position:track.position textures:textures]];
        
    }
    return [nodes copy];
}

+ (id) description
{
    return [[[self class] alloc] init];
}
@end
