/*

 File: SceneDelegate.m
 Abstract: UIKit scene lifecycle adapter

 Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.

*/

#import "SceneDelegate.h"

#import "iSDRAppDelegate.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
    options:(UISceneConnectionOptions *)connectionOptions
{
    if(![scene isKindOfClass:[UIWindowScene class]])
    {
        return;
    }

    iSDRAppDelegate *appDelegate = (iSDRAppDelegate *)UIApplication.sharedApplication.delegate;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    appDelegate.window = self.window;
    [appDelegate configureMainWindow];
}

// These adapters preserve the legacy app-wide lifecycle behavior while UIKit
// delivers activation and background events through UIScene on current iOS.
- (void)sceneWillEnterForeground:(UIScene *)scene
{
    [(iSDRAppDelegate *)UIApplication.sharedApplication.delegate
        applicationWillEnterForeground:UIApplication.sharedApplication];
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
    [(iSDRAppDelegate *)UIApplication.sharedApplication.delegate
        applicationDidEnterBackground:UIApplication.sharedApplication];
}

- (void)sceneWillResignActive:(UIScene *)scene
{
    [(iSDRAppDelegate *)UIApplication.sharedApplication.delegate
        applicationWillResignActive:UIApplication.sharedApplication];
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    [(iSDRAppDelegate *)UIApplication.sharedApplication.delegate
        applicationDidBecomeActive:UIApplication.sharedApplication];
}

@end
