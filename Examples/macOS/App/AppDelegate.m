//
//  AppDelegate.m
//  Example
//
//  Created by hulilei on 2021/8/31.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AppDelegate.h"
#import "LoginWindowController.h"
@interface AppDelegate ()

@property (nonatomic, strong) LoginWindowController *loginWindowC;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation AppDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)notification{
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    NSStatusItem *item = [bar statusItemWithLength:NSSquareStatusItemLength];
    [item.button setTarget:self];
    [item.button setAction:@selector(itemClick:)];
    item.button.image = [NSImage imageNamed:@"blue"];
    self.statusItem = item;
}
- (void)itemClick:(id)sender{
    
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
   
//    [[FTMobileAgent sharedInstance] logging:@"applicationDidFinishLaunching" status:FTStatusInfo];
//    [self.loginWindowC showWindow:self];
    
}

-(LoginWindowController *)loginWindowC{
    if (!_loginWindowC) {
        _loginWindowC = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"LoginWindowController"];
    }
    return _loginWindowC;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    [bar removeStatusItem:self.statusItem];
}


@end
