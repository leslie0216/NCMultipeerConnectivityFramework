//
//  NCMCPeripheralService+Core.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCPeripheralService.h"
#import "NCMCSession.h"

@interface NCMCPeripheralService()

@property (strong, nonatomic)NCMCSession* session;

-(void)notifyDidReceiveInvitationFromPeer:(NCMCPeerID *)peerID
                        invitationHandler:(void (^)(BOOL accept, NCMCSession *session, NCMCPeerID *peerID))invitationHandler;

-(void)notifyDidNotStartAdvertising:(NSError*)error;

@end
