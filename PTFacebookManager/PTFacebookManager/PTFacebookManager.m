//
//  PTFacebookManager.m
//  PTFacebookManager
//
//  Created by Paolo Tagliani on 10/21/13.
//  Copyright (c) 2013 PaoloTagliani. All rights reserved.
//

#import "PTFacebookManager.h"

// Define this block to pass a generic action to FB session opener completion block
typedef void (^PTFacebookSessionCompletionBlock)(FBSession *session, FBSessionState status, NSError *error);

@implementation PTFacebookManager

#pragma mark - Singleton

+ (PTFacebookManager *)sharedInstance
{
    static PTFacebookManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PTFacebookManager alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Login

- (void)logIn:(PTFacebookAuthorizationType)authType
{
    FBSession *session = [FBSession activeSession];
    __weak PTFacebookManager *weakSelf = self;
    
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
             
             [weakSelf.delegate facebookAPIFailed:PTFAcebookLoginFailed];
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

- (void)getUserGraphInfoWithCompletionBlock:(PTFacebookUserBlock)completion
{
    FBSession *session;
    
    session  = [FBSession activeSession];
    
    if (session.isOpen)
        [self requestUserWithCompletionBlock:completion];
    else
    {
        // If session is not open open with read permission (user only need read permission)
        __weak PTFacebookManager *weakSelf = self;
        [self openSessionWithAuth:PTFacebookReadPermission completionBlock:^(FBSession *session, FBSessionState status, NSError *error)
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
        __weak PTFacebookManager *weakSelf = self;
        [self openSessionWithAuth:PTFacebookReadPermission completionBlock:^(FBSession *session, FBSessionState status, NSError *error)
         {
             if (error)
             {
                 NSLog(@"%@", [error localizedDescription]);
                 if (status == FBSessionStateClosedLoginFailed)
                 {
                     [FBSession.activeSession closeAndClearTokenInformation];
                     [weakSelf.delegate
                      facebookAPIFailed:PTFacebookOpenSessionFail];
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

- (void)requestUserWithCompletionBlock:(PTFacebookUserBlock)completion
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
    __weak PTFacebookManager *weakSelf = self;
    
    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error)
     {
         if (error)
         {
             NSLog(@"%@", [error localizedDescription]);
             [weakSelf.delegate
              facebookAPIFailed:PTFacebookGraphCallFail];
         }
         
         [weakSelf.delegate
          userGraphInfoRetrieved:user];
     }];
}

#pragma mark - Session management

- (void)openSessionWithAuth:(PTFacebookAuthorizationType)authType completionBlock:(PTFacebookSessionCompletionBlock)completion
{
    FBSession *session;
    
    session  = [FBSession activeSession];
    
    if ([session isOpen])
        if ([self verifyActualPermission:session.permissions forAuthorizationType:authType])
            return;
    
    switch (authType)
    {
        case PTFacebookReadPermission:
        {
            [FBSession openActiveSessionWithReadPermissions:self.readPermission
                                               allowLoginUI:YES
                                          completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                              // Call the completion handler passed as parameter
                                              completion(session, status, error);
                                          }];
        }
            break;
        case PTFacebookPublishPermission:
        {
            [FBSession openActiveSessionWithPublishPermissions:self.publishPermission
                                               defaultAudience:FBSessionDefaultAudienceEveryone
                                                  allowLoginUI:YES
                                             completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                                 completion(session, status, error);
                                             }];
        }
            break;
        case PTFacebookBothPermission:
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

- (NSDate *)gePTokenExpirationDate
{
    return [FBSession activeSession].accessTokenData.expirationDate;
}

#pragma mark - Utilities

- (BOOL)verifyActualPermission:(NSArray *)sessionPermissionArray forAuthorizationType:(PTFacebookAuthorizationType)authType
{
    NSArray *actualPermissionArray;
    
    switch (authType)
    {
        case PTFacebookReadPermission:
            actualPermissionArray = self.readPermission;
            break;
        case PTFacebookPublishPermission:
            actualPermissionArray = self.publishPermission;
            break;
        case PTFacebookBothPermission:
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
