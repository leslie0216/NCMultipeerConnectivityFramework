//
//  NCMCPeerID.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//
#import "Core/NCMCPeerID+Core.h"

@implementation NCMCPeerID

@synthesize displayName, identifier;

-(instancetype)initWithDisplayName:(NSString *)name
{
    self = [super init];
    
    if (self) {
        self.displayName = name;
        self.identifier = [[[NSUUID alloc]init] UUIDString];
    }
    
    return self;
}

-(instancetype)initWithDisplayName:(NSString *)n andIdentifier:(NSString *)i
{
    self = [super init];
    
    if (self) {
        self.displayName = n;
        self.identifier = i;
    }
    
    return self;
}

-(NSString*)getDisplayName
{
    return self.displayName;
}

- (id)copyWithZone:(NSZone *)zone {
    
    id copy = [[[self class] alloc] init];
    
    if (copy) {
        // Copy NSObject subclasses
        [copy setIdentifier:self.identifier];
        [copy setDisplayName:self.displayName];
    }
    
    return copy;
}

@end
