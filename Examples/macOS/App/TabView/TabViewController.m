//
//  TabViewController.m
//  Example
//
//  Created by hulilei on 2021/9/10.
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

#import "TabViewController.h"
#import "FirstViewController.h"
#import "SecondViewController.h"
#import "PresentVC.h"
#import "PresentCustomAnimator.h"
#import "CollectionVC.h"

@interface TabViewController ()<NSTabViewDelegate>
@property (weak) IBOutlet NSTabView *tabView;

@end

@implementation TabViewController
-(void)viewWillAppear{
    [super viewWillAppear];
    
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.view.wantsLayer = YES;

    NSArray *tabItems = self.tabView.tabViewItems;
    self.tabView.delegate = self;
    FirstViewController *vc1 = [[FirstViewController alloc]init];
    SecondViewController *vc2 = [[SecondViewController alloc]init];
    CollectionVC *vc3 = [[CollectionVC alloc]init];
    [self addChildViewController:vc1];
    [self addChildViewController:vc2];
    [self addChildViewController:vc3];
    NSArray *vcs = @[vc1,vc2,vc3];
    int index = 0;
    for (NSTabViewItem *item in tabItems) {
        NSViewController *vc = vcs[index];
        [item.view addSubview:vc.view];
        vc.view.frame = item.view.bounds;
        index = index+1;
    }
    NSImageView *view = [[NSImageView alloc] initWithFrame:CGRectMake(5, 5, 30, 30)];
//    [view prepareForReuse];
    // Background color
    view.wantsLayer = YES;
    view.layer.backgroundColor = NSColor.redColor.CGColor;
    // Corner radius
    view.layer.cornerRadius = 15;
    // Border
    view.layer.borderColor = NSColor.greenColor.CGColor;
    view.layer.borderWidth = 2;
    NSClickGestureRecognizer *gesture = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(viewClick:)];
    [view addGestureRecognizer:gesture];
    [self.view addSubview:view];
}
- (void)viewClick:(NSGestureRecognizer *)gesture {
    NSLog(@"touch view");
}

-(void)tabView:(NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem* )tabViewItem{
    NSInteger index = [tabView indexOfTabViewItem:tabViewItem];
     id view = tabViewItem.view.nextResponder;
    while (view !=nil) {
        if ([view isKindOfClass:NSViewController.class]) {
            break;
            
        }else if ([view isKindOfClass:NSView.class]){
            NSView *nView = view;
            view = nView.nextResponder;
        }
    }
    NSLog(@"index = %ld tabViewItem.lable = %@ controller = %@",(long)index,tabViewItem.label,view);
    NSApplication *app = [NSApplication sharedApplication];
    NSLog(@"windows = %@",app.windows);
}
- (IBAction)modalClick:(id)sender {
    
    CollectionVC *vc = [[CollectionVC alloc]init];
    [self presentViewControllerAsModalWindow:vc];
}
- (IBAction)sheetClick:(id)sender {
    
    PresentVC *vc = [[PresentVC alloc]init];
    [self presentViewControllerAsSheet:vc];
}
- (IBAction)popoverClick:(id)sender {
    NSButton *btn = sender;
    PresentVC *vc = [[PresentVC alloc]init];
    [self presentViewController:vc asPopoverRelativeToRect:btn.frame ofView:self.view preferredEdge:NSRectEdgeMinY behavior:NSPopoverBehaviorTransient];
}
- (IBAction)animatorClick:(id)sender {
    PresentVC *vc = [[PresentVC alloc]init];

    PresentCustomAnimator *animator = [[PresentCustomAnimator alloc]init];
    
    [self presentViewController:vc animator:animator];
}
- (IBAction)showClick:(id)sender {
    PresentVC *presentVC = [[PresentVC alloc]init];

//    let toVC = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "ToVC")) as? NSViewController
//    //Add 2 child view controllers
    presentVC.view.wantsLayer = YES;
//    presentVC?.view.layer?.backgroundColor = NSColor.white.cgColor
//    self.addChildViewController(presentVC!)
//    self.view.addSubview((presentVC?.view)!)
//
    [self addChildViewController:presentVC];
//    self.addChildViewController(toVC!)
    //Show presentVC view
    // Switch from presentVC view to another toVC view
//        self.transition(from: presentVC!, to: toVC!, options: NSViewController.TransitionOptions.crossfade , completionHandler: nil)
//    NSColorPanel *color = [[NSColorPanel alloc]init];
//    [self.view.window beginSheet:color completionHandler:^(NSModalResponse returnCode) {
//
//    }];
    NSOpenPanel *open = [NSOpenPanel openPanel];
    open.canChooseFiles = YES;
    [open beginWithCompletionHandler:^(NSModalResponse result) {
        if(result == NSModalResponseOK){
            NSArray *filesUrl = open.URLs;
            for (NSURL *url in filesUrl) {
                NSError *error;
                NSString *string = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
                NSLog(@"fileUrl = %@",string);
            }
        }
    }];
}

- (IBAction)segmentClick:(id)sender {

}
-(void)viewDidDisappear{
    [super viewDidDisappear];
    
}
@end
