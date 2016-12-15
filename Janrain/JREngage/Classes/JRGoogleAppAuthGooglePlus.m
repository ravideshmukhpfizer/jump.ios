/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 Copyright (c) 2016, Janrain, Inc.
 All rights reserved.
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 * Neither the name of the Janrain, Inc. nor the names of its
 contributors may be used to endorse or promote products derived from this
 software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#import "JRGoogleAppAuthGooglePlus.h"
#import "debug_log.h"
#import "AppAuth.h"
#import "AppDelegate.h"
#import "RootViewController.h"

/*! @brief The OIDC issuer from which the configuration will be discovered.
 */
static NSString *const kIssuer = @"https://accounts.google.com";

/*! @brief NSCoding key for the authState property.
 */
static NSString *const kAppAuthExampleAuthStateKey = @"authState";

@interface JRGoogleAppAuthGooglePlus () <OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate>
@end

@implementation JRGoogleAppAuthGooglePlus

- (NSString *)provider {
    return @"googleplus";
}

- (void)startAuthenticationWithCompletion:(GoogleAppAuthCompletionBlock)completion {
    [super startAuthenticationWithCompletion:completion];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSURL *issuer = [NSURL URLWithString:kIssuer];
    NSURL *redirectURI = [NSURL URLWithString:appDelegate.googlePlusRedirectUri];
    
    DLog(@"Fetching configuration for issuer: %@", issuer);
    
    // discovers endpoints
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
        completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {
            
            AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
            
            if (!configuration) {
                DLog(@"Error retrieving discovery document: %@", [error localizedDescription]);
                [self setAuthState:nil];
                return;
            }
            
            DLog(@"Got configuration: %@", configuration);
            
            // builds authentication request
            OIDAuthorizationRequest *request =
            [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                          clientId:appDelegate.googlePlusClientId
                                                            scopes:@[OIDScopeOpenID, OIDScopeProfile]
                                                       redirectURL:redirectURI
                                                      responseType:OIDResponseTypeCode
                                              additionalParameters:nil];
            // performs authentication request
            DLog(@"Initiating authorization request with scope: %@", request.scope);
            
            UIViewController *current = [UIApplication sharedApplication].keyWindow.rootViewController;
            
            while (current.presentedViewController) {
                current = current.presentedViewController;
            }
            appDelegate.googleAppAuthAuthorizationFlow =
            [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                           presentingViewController:current
                                                           callback:^(OIDAuthState *_Nullable authState,
                                                                      NSError *_Nullable error) {
                                                               if (authState) {
                                                                   [self setAuthState:authState];
                                                                   DLog(@"Got authorization tokens. Access token: %@",
                                                                        authState.lastTokenResponse.accessToken);
                                                                   [self getAuthInfoTokenForAccessToken:(NSString *)authState.lastTokenResponse.accessToken];
                                                                   
                                                               } else {
                                                                   DLog(@"Google+ Authorization error: %@", [error localizedDescription]);
                                                                   [self setAuthState:nil];
                                                                   self.completion(error);
                                                               }
                                                           }];
        }];
}




+ (BOOL)handleURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(NSString *)annotation {
    return YES;
}


//Google AppAuth

/*! @brief Saves the @c OIDAuthState to @c NSUSerDefaults.
 */
- (void)saveState {
    // for production usage consider using the OS Keychain instead
    NSData *archivedAuthState = [ NSKeyedArchiver archivedDataWithRootObject:_authState];
    [[NSUserDefaults standardUserDefaults] setObject:archivedAuthState
                                              forKey:kAppAuthExampleAuthStateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/*! @brief Loads the @c OIDAuthState from @c NSUSerDefaults.
 */
- (void)loadState {
    // loads OIDAuthState from NSUSerDefaults
    NSData *archivedAuthState =
    [[NSUserDefaults standardUserDefaults] objectForKey:kAppAuthExampleAuthStateKey];
    OIDAuthState *authState = [NSKeyedUnarchiver unarchiveObjectWithData:archivedAuthState];
    [self setAuthState:authState];
}

- (void)setAuthState:(nullable OIDAuthState *)authState {
    if (_authState == authState) {
        return;
    }
    _authState = authState;
    _authState.stateChangeDelegate = self;
    [self stateChanged];
}

- (void)stateChanged {
    [self saveState];
}

- (void)didChangeState:(OIDAuthState *)state {
    [self stateChanged];
}

- (void)authState:(OIDAuthState *)state didEncounterAuthorizationError:(nonnull NSError *)error {
    DLog(@"Google AppAuth Google+ Received authorization error: %@", error);
}


@end
