//
//  CollectionVC.m
//  Example
//
//  Created by hulilei on 2021/9/14.
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

#import "CollectionVC.h"
#import "CollectionViewItem.h"

@interface CollectionVC ()<NSCollectionViewDelegate,NSCollectionViewDataSource>
@property (weak) IBOutlet NSScrollView *scrollview;
@property (nonatomic, strong) NSCollectionView *collectionView;
@property (nonatomic, strong) NSCollectionViewFlowLayout *flowLayout;
@property (nonatomic, strong) NSMutableArray *datas;

@end

@implementation CollectionVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
    // Do view setup here.
    [self updateDatas];
}
- (void)createUI{
    self.collectionView = [[NSCollectionView alloc]init];
    self.collectionView.selectable = YES;
    self.collectionView.allowsEmptySelection = YES;
    self.collectionView.delegate     = self;
    self.collectionView.dataSource   = self;
    self.collectionView.collectionViewLayout = self.flowLayout;
    [self.collectionView registerClass:CollectionViewItem.class forItemWithIdentifier:@"CollectionViewItem"];

    self.scrollview.documentView = self.collectionView;
}
-(NSCollectionViewFlowLayout *)flowLayout{
    if (!_flowLayout) {
        NSCollectionViewFlowLayout *layout = [[NSCollectionViewFlowLayout alloc]init];
        layout.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
        layout.itemSize = CGSizeMake(100, 100);
        layout.sectionInset = NSEdgeInsetsMake(10, 10, 10, 10);
        layout.minimumInteritemSpacing = 10;
        layout.minimumLineSpacing = 10;
        _flowLayout = layout;
    }
    return _flowLayout;
}
- (void)updateDatas{
    self.datas = [NSMutableArray new];
    NSDictionary *item1 = @{@"title" : @"computer",
                            @"image" : NSImageNameComputer,
                            @"tag"   : @(305),
    };
    NSDictionary *item2 = @{@"title" : @"folder",
                            @"image" : NSImageNameFolder,
                            @"tag"   : @(306),
    };
    NSDictionary *item3 = @{@"title" : @"home",
                            @"image" : NSImageNameHomeTemplate,
                            @"tag"   : @(307),
    };
    NSDictionary *item4 = @{@"title" : @"list",
                            @"image" : NSImageNameListViewTemplate,
                            @"tag"   : @(308)
    };
    NSDictionary *item5 = @{@"title" : @"network",
                            @"image" : NSImageNameNetwork,
                            @"tag"   : @(309)
    };
    NSDictionary *item6 = @{@"title" : @"share",
                            @"image" : NSImageNameShareTemplate,
                            @"tag"   : @(310)
    };

    [self.datas addObjectsFromArray:@[item1,item2,item3,item4,item5,item6]];
    [self.collectionView reloadData];
}
-(NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.datas.count;
}
-(NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView{
    return 1;
}

- (nonnull NSCollectionViewItem *)collectionView:(nonnull NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(nonnull NSIndexPath *)indexPath {
    NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"CollectionViewItem" forIndexPath:indexPath];
    
    
    NSInteger itemIndex = indexPath.item;
    item.representedObject = self.datas[itemIndex];
    return item;
}


-(void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths{
    NSLog(@"indexPaths = %@",indexPaths);
    CollectionViewItem *item = (CollectionViewItem*)[collectionView itemAtIndexPath:[indexPaths anyObject]];
    [item updateStatus];
}
-(void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths{
    CollectionViewItem *item = (CollectionViewItem*)[collectionView itemAtIndexPath:[indexPaths anyObject]];
    [item updateStatus];
}

@end
