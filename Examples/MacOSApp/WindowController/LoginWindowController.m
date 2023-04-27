//
//  LoginWindowController.m
//  Example
//
//  Created by 胡蕾蕾 on 2021/9/9.
//

#import "LoginWindowController.h"
#import "ViewController.h"
@interface LoginWindowController ()<NSWindowDelegate>

@end

@implementation LoginWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    self.window.delegate = self;
    [self.window center];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(void)windowWillClose:(NSNotification *)notification{
    self.contentViewController = nil;
    self.window = nil;
}
-(void)windowWillBeginSheet:(NSNotification *)notification{
    
}
@end
