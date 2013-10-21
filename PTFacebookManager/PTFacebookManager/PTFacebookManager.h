//
//  PTFacebookManager.h
//  PTFacebookManager
//
//  Created by Paolo Tagliani on 10/21/13.
//  Copyright (c) 2013 PaoloTagliani. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FacebookSDK/FacebookSDK.h>

typedef void (^PTFacebookUserBlock)(NSDictionary<FBGraphUser> *user,  NSError *error);

typedef NS_ENUM (NSInteger, PTFacebookError)
{
    PTFAcebookLoginFailed,
    PTFacebookOpenSessionFail,
    PTFacebookGraphCallFail
};

typedef NS_ENUM (NSInteger, PTFacebookAuthorizationType)
{
    PTFacebookReadPermission,
    PTFacebookPublishPermission,
    PTFacebookBothPermission    //Special case in which want special read + publish permission
};

@protocol PTFacebookDelegate <NSObject>

// Metodo per il grafico dell'utente
- (void)userGraphInfoRetrieved:(NSDictionary<FBGraphUser> *)userInfo;
- (void)loginSucceed;
- (void)logoutSucceed;
- (void)facebookAPIFailed:(PTFacebookError)errorType;

@end

@interface PTFacebookManager : NSObject

@property (nonatomic, weak) id <PTFacebookDelegate> delegate;

/**
 *  Permission used to open the read session.
 */
@property (nonatomic, copy) NSArray *readPermission;

/**
 *  Permission used to open publish session
 */
@property (nonatomic, copy) NSArray *publishPermission;

/**
 *  Create a shared instance of the PTFacebook manager
 *
 *  @return The only shared instance of PTFacebook manager
 */
+ (PTFacebookManager *)sharedInstance;

/**
 *  Create a session, i.e. make the user log in. It the user is already logged in this method does not anything and notify on successful login.
 */
- (void)logIn:(PTFacebookAuthorizationType)authType;

/**
 *  Check if the user is logged in in Faccebook, i.e. if an access token is present.
 *
 *  @return A bool that indicates if it's logged in
 */
- (BOOL)isLoggedIn;

/**
 *  Logout and clear all information about the user. Notify the delegate with the delegateSuceed method.
 */
- (void)logOut;

/**
 *  Get current session access token
 *
 *  @return Return a string representiation of the current access token or nil if not present.
 */
- (NSString *)getAccessToken;

/**
 *  Current token expiration date
 *
 *  @return current token expiration date
 */
- (NSDate *)getTokenExpirationDate;

/**
 *  Call the Graph API to retrive the data of the user ("/me" endpoint). If the user is not logged in, it automatically create the session and log the user.
 *  It calls the delegate method userGraphInfoReceiver on success or graphError on failure.
 */

- (void)getUserGraphInfo;

/**
 *  Call the Graph API to retrive the data of the user ("/me" endpoint). If the user is not logged in, it automatically create the session and log the user.
 *  It calls the block after the completion of the operation.
 *  @param completion The completion block
 */

- (void)getUserGraphInfoWithCompletionBlock:(PTFacebookUserBlock)completion;

/**
 *  TO BE DONE IN NEXT RELEASE
 *  Call the Graph API using the string passed as a parameter. If the user is not logged in, it automatically create the session and log the user.
 *  It calls the delegate method userGraphInfoReceiver on success or graphError on failure.
 *  @param graphEndPoint The string indicating the endpoint
 */
- (void)genericGraphCall:(NSString *)graphEndPoint;

@end