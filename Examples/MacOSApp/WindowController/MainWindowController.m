//
//  MainWindowController.m
//  Example
//
//  Created by 胡蕾蕾 on 2021/9/10.
//

#import "MainWindowController.h"

@interface MainWindowController ()

@end

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window center];
    NSApplication *app = [NSApplication sharedApplication];
    NSLog(@"windows = %@",app.windows);
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
