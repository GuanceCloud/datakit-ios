//
//  ViewController.m
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

#import "LoginViewController.h"
#import "GuanceSDKExampleImports.h"
@interface LoginViewController()
@property (nonatomic, strong) NSWindowController *mainAppWVC;
@property (weak) IBOutlet NSButton *loginBtn;
@property (weak) IBOutlet NSSearchField *userNameTF;
@property (weak) IBOutlet NSTextField *passwordTF;

@end
@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSApplication *app = [NSApplication sharedApplication];
    NSLog(@"windows = %@",app.windows);
    self.userNameTF.allowsEditingTextAttributes = YES;
    self.userNameTF.tag = 50;
    self.loginBtn.tag = 100;
    // Do any additional setup after loading the view.
}
- (IBAction)closeClick:(id)sender {
    [self.view.window close];
}

- (IBAction)loginClick:(id)sender {
    if (self.userNameTF.stringValue.length==0) {
        NSAlert *alert = [[NSAlert alloc]init];
        [alert addButtonWithTitle:@"ok"];
        [alert setMessageText:@"Alert"];
        [alert setInformativeText:@"user name can't be null"];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
            
        }];
        return;
    }
    [[FTMobileAgent sharedInstance] bindUserWithUserID:[[NSUUID UUID] UUIDString] userName:self.userNameTF.stringValue userEmail:nil];
    [self.view.window close];
    
    self.mainAppWVC = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"MainAppWVC"];
    
    [self.mainAppWVC showWindow:self];
}
- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
