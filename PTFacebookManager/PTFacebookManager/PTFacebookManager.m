//
//  PTFacebookManager.m
//  PTFacebookManager
//
//  Created by Paolo Tagliani on 10/21/13.
//  Copyright (c) 2013 PaoloTagliani. All rights reserved.
//

#import "PTFacebookManager.h"

// Define this block to pass a generic action to FB session opener completion block
typedef void (^TTFacebookSessionCompletionBlock)(FBSession *session, FBSessionState status, NSError *error);

@implementation PTFacebookManager

pragma mark - Singleton

+ (TTFacebook *)sharedInstance
{
    static TTFacebook *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TTFacebook alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Login

- (void)logIn:(TTFacebookAuthorizationType)authType
{
    FBSession *session = [FBSession activeSession];
    __weak TTFacebook *weakSelf = self;
    
    // Check if the session is open or if there's a valid token (the user has already login)
    if (session.state == FBSessionStateCreatedTokenLoaded || session.state == FBSessionStateOpen)
    {
        // Verify permission for current session
        if ([self verifyActualPermission:session.permissions forAuthorizationType:authType])
        {
            [self.delegate loginSucceed];
            return;
        }
    }
    [self openSessionWithAuth:authType completionBlock:^(FBSession *session, FBSessionState status, NSError *error)
     {
         if (error)
         {
             NSLog(@"%@", [error localizedDescription]);
             if (status == FBSessionStateClosedLoginFailed)
                 [FBSession.activeSession closeAndClearTokenInformation];
             
             [weakSelf.delegate facebookAPIFailed:TTFAcebookLoginFailed];
         }
         if (session.state == FBSessionStateOpen) // If correctly open session, notify delegate
             [weakSelf.delegate loginSucceed];
         
     }];
    
}

- (BOOL)isLoggedIn
{
    FBSession *activeSession = [FBSession activeSession];
    
    return activeSession.state == FBSessionStateCreatedTokenLoaded || activeSession.state == FBSessionStateOpen;
}

#pragma mark - Logout

- (void)logOut
{
    FBSession *session = [FBSession activeSession];
    
    [session closeAndClearTokenInformation];
    [self.delegate logoutSucceed];
}

#pragma mark - Graph API and login

- (void)getUserGraphInfoWithCompletionBlock:(TTFacebookUserBlock)completion
{
    FBSession *session;
    
    session  = [FBSession activeSession];
    
    if (session.isOpen)
        [self requestUserWithCompletionBlock:completion];
    else
    {
        // If session is not open open with read permission (user only need read permission)
        __weak TTFacebook *weakSelf = self;
        [self openSessionWithAuth:TTFacebookReadPermission completionBlock:^(FBSession *session, FBSessionState status, NSError *error)
         {
             if (error)
             {
                 NSLog(@"%@", [error localizedDescription]);
                 completion(nil, error);
             }
             if (status == FBSessionStateOpen)
                 [weakSelf requestUserWithCompletionBlock:completion];
         }];
    }
}

- (void)getUserGraphInfo
{
    FBSession *session;
    
    session  = [FBSession activeSession];
    
    if (session.isOpen)
        // Call the Graph with API and notify delegates
        [self requestUser];
    else
    {
        __weak TTFacebook *weakSelf = self;
        [self openSessionWithAuth:TTFacebookReadPermission completionBlock:^(FBSession *session, FBSessionState status, NSError *error)
         {
             if (error)
             {
                 NSLog(@"%@", [error localizedDescription]);
                 if (status == FBSessionStateClosedLoginFailed)
                 {
                     [FBSession.activeSession closeAndClearTokenInformation];
                     [weakSelf.delegate
                      facebookAPIFailed:TTFacebookOpenSessionFail];
                 }
             }
             if (status == FBSessionStateOpen)
                 [weakSelf requestUser];
             
         }];
    }
}

- (void)genericGraphCall:(NSString *)graphEndPoint
{
    // TODO
}

#pragma mark - Request user graph

- (void)requestUserWithCompletionBlock:(TTFacebookUserBlock)completion
{
    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error)
     {
         if (error)
             NSLog(@"%@", [error localizedDescription]);
         
         completion(user, error);
     }];
}


- (void)requestUser
{
    __weak TTFacebook *weakSelf = self;
    
    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error)
     {
         if (error)
         {
             NSLog(@"%@", [error localizedDescription]);
             [weakSelf.delegate
              facebookAPIFailed:TTFacebookGraphCallFail];
         }
         
         [weakSelf.delegate
          userGraphInfoRetrieved:user];
     }];
}

#pragma mark - Session management

- (void)openSessionWithAuth:(TTFacebookAuthorizationType)authType completionBlock:(TTFacebookSessionCompletionBlock)completion
{
    FBSession *session;
    
    session  = [FBSession activeSession];
    
    if ([session isOpen])
        if ([self verifyActualPermission:session.permissions forAuthorizationType:authType])
            return;
    
    switch (authType)
    {
        case TTFacebookReadPermission:
        {
            [FBSession openActiveSessionWithReadPermissions:self.readPermission
                                               allowLoginUI:YES
                                          completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                              // Call the completion handler passed as parameter
                                              completion(session, status, error);
                                          }];
        }
            break;
        case TTFacebookPublishPermission:
        {
            [FBSession openActiveSessionWithPublishPermissions:self.publishPermission
                                               defaultAudience:FBSessionDefaultAudienceEveryone
                                                  allowLoginUI:YES
                                             completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                                 completion(session, status, error);
                                             }];
        }
            break;
        case TTFacebookBothPermission:
        {
            NSArray *totalPermission = [self.readPermission arrayByAddingObjectsFromArray:self.publishPermission];
            [FBSession openActiveSessionWithPublishPermissions:totalPermission
                                               defaultAudience:FBSessionDefaultAudienceEveryone
                                                  allowLoginUI:YES
                                             completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                                 completion(session, status, error);
                                             }];
        }
            break;
        default:
            break;
    }
    
    
}

#pragma mark - Access token info

- (NSString *)getAccessToken
{
    return [FBSession activeSession].accessTokenData.accessToken;
}

- (NSDate *)getTokenExpirationDate
{
    return [FBSession activeSession].accessTokenData.expirationDate;
}

#pragma mark - Utilities

- (BOOL)verifyActualPermission:(NSArray *)sessionPermissionArray forAuthorizationType:(TTFacebookAuthorizationType)authType
{
    NSArray *actualPermissionArray;
    
    switch (authType)
    {
        case TTFacebookReadPermission:
            actualPermissionArray = self.readPermission;
            break;
        case TTFacebookPublishPermission:
            actualPermissionArray = self.publishPermission;
            break;
        case TTFacebookBothPermission:
            actualPermissionArray = [self.readPermission arrayByAddingObjectsFromArray:self.publishPermission];
            break;
        default:
            break;
    }
    
    NSSet *actualPermissionSet = [NSSet setWithArray:actualPermissionArray];
    NSSet *sessionPermissionSet = [NSSet setWithArray:sessionPermissionArray];
    
    return [actualPermissionSet isEqualToSet:sessionPermissionSet];
}

@end
