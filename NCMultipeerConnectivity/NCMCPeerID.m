//
//  NCMCPeerID.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//
#import "Core/NCMCPeerID+Core.h"

@implementation NCMCPeerID

@synthesize displayName, identifier, uniqueID;

-(instancetype)initWithDisplayName:(NSString *)name
{
    self = [super init];
    
    if (self) {
        self.displayName = name;
        self.identifier = [[[NSUUID alloc]init] UUIDString];
        self.uniqueID = -1;
    }
    
    return self;
}

-(instancetype)initWithDisplayName:(NSString *)_name andIdentifier:(NSString *)_identifier andUniqueID:(char)_uniqueID
{
    self = [super init];
    
    if (self) {
        self.displayName = _name;
        self.identifier = _identifier;
        self.uniqueID = _uniqueID;
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
        [copy setUniqueID:self.uniqueID];
    }
    
    return copy;
}

@end
