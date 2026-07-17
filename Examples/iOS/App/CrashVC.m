//
//  CrashVC.m
//  SampleApp
//
//  Created by hulilei on 2021/2/18.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import "CrashVC.h"
#import "Crasher.h"
#import "TableViewCellItem.h"
@interface CrashVC ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong) UITableView *mtableView;
@property (nonatomic,strong) NSMutableArray<TableViewCellItem *> *dataSource;
@end

@implementation CrashVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Crash";
    [self createUI];
}
- (void)createUI{
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    Crasher *crasher = [[Crasher alloc]init];
    [self.dataSource addObjectsFromArray:@[[[TableViewCellItem alloc]initWithTitle:@"throwUncaughtNSException" handler:^{
        [crasher throwUncaughtNSException];
    }],[[TableViewCellItem alloc]initWithTitle:@"dereferenceBadPointer" handler:^{
        [crasher dereferenceBadPointer];
    }],[[TableViewCellItem alloc]initWithTitle:@"dereferenceNullPointer" handler:^{
        [crasher dereferenceNullPointer];
    }],[[TableViewCellItem alloc]initWithTitle:@"useCorruptObject" handler:^{
        [crasher useCorruptObject];
    }],[[TableViewCellItem alloc]initWithTitle:@"spinRunloop" handler:^{
        [crasher spinRunloop];
    }],[[TableViewCellItem alloc]initWithTitle:@"causeStackOverflow" handler:^{
        [crasher causeStackOverflow];
    }],[[TableViewCellItem alloc]initWithTitle:@"doAbort" handler:^{
        [crasher doAbort];
    }],[[TableViewCellItem alloc]initWithTitle:@"doDiv0" handler:^{
        [crasher doDiv0];
    }],[[TableViewCellItem alloc]initWithTitle:@"accessDeallocatedObject" handler:^{
        [crasher accessDeallocatedObject];
    }],[[TableViewCellItem alloc]initWithTitle:@"accessDeallocatedPtrProxy" handler:^{
        [crasher accessDeallocatedPtrProxy];
    }],[[TableViewCellItem alloc]initWithTitle:@"zombieNSException" handler:^{
        [crasher zombieNSException];
    }],[[TableViewCellItem alloc]initWithTitle:@"corruptMemory" handler:^{
        [crasher corruptMemory];
    }],[[TableViewCellItem alloc]initWithTitle:@"anr" handler:^{
        [crasher anr];
    }],[[TableViewCellItem alloc]initWithTitle:@"deadlock" handler:^{
        [crasher deadlock];
    }],[[TableViewCellItem alloc]initWithTitle:@"pthreadAPICrash" handler:^{
        [crasher pthreadAPICrash];
    }],[[TableViewCellItem alloc]initWithTitle:@"throwUncaughtCPPException" handler:^{
        [crasher throwUncaughtCPPException];
    }],[[TableViewCellItem alloc]initWithTitle:@"userException" handler:^{
        [crasher userException];
    }]
                                         ]];
}
-(NSMutableArray<TableViewCellItem *> *)dataSource{
    if (!_dataSource) {
        _dataSource = [[NSMutableArray alloc]init];
    }
    return _dataSource;
}
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.row].title;
    cell.accessibilityLabel = self.dataSource[indexPath.row].title;
    cell.textLabel.text = self.dataSource[indexPath.row].title;
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TableViewCellItem *item = self.dataSource[indexPath.row];
    if (item.handler) {
        item.handler();
    }
}
@end
