//
//  BlacklistedVCClassNames.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/4/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import "BlacklistedVCClassNames.h"

@implementation BlacklistedVCClassNames
+ (NSArray *)ft_blacklistedViewControllerClassNames{
   NSArray *blackList =
    @[@"UIDocumentBrowserViewController",
      @"UIDocumentPickerViewController",
      @"UISplitViewController",
      @"SLComposeViewController",
      @"UIActivityViewController",
      @"UIDocumentMenuViewController",
      @"UIImagePickerController",
      @"UIReferenceLibraryViewController",
      @"AVPlayerViewController",
      @"SFSafariViewController",
      @"UINavigationController",
      @"UITabBarController",
      @"UIAlertController",//
      @"SFBrowserRemoteViewController",
      @"UIInputWindowController",
      @"UIKeyboardCandidateGridCollectionViewController",
      @"UICompatibilityInputViewController",
      @"UIApplicationRotationFollowingController",
      @"UIApplicationRotationFollowingControllerNoTouches",
      @"UIActivityGroupViewController",
      @"UIKeyboardCandidateRowViewController",
      @"UIKeyboardHiddenViewController",
      @"_UIAlertControllerTextFieldViewController",
      @"_UILongDefinitionViewController",
      @"_UIResilientRemoteViewContainerViewController",
      @"_UIShareExtensionRemoteViewController",
      @"_UIRemoteDictionaryViewController",
      @"UISystemKeyboardDockController",
      @"_UINoDefinitionViewController",
      @"_UIActivityGroupListViewController",
      @"_UIRemoteViewController",
      @"_UIFallbackPresentationViewController",
      @"_UIDocumentPickerRemoteViewController",
      @"_UIAlertShimPresentingViewController",
      @"_UIWaitingForRemoteViewContainerViewController",
      @"_UIActivityUserDefaultsViewController",
      @"_UIActivityViewControllerContentController",
      @"_UIRemoteInputViewController",
      @"_UIUserDefaultsActivityNavigationController",
      @"_SFAppPasswordSavingViewController",
      @"UISnapshotModalViewController",
      @"WKActionSheet",
      @"DDSafariViewController",
      @"SFAirDropActivityViewController",
      @"CKSMSComposeController",
      @"DDParsecLoadingViewController",
      @"PLUIPrivacyViewController",
      @"PLUICameraViewController",
      @"SLRemoteComposeViewController",
      @"CAMViewfinderViewController",
      @"DDParsecNoDataViewController",
      @"CAMPreviewViewController",
      @"DDParsecCollectionViewController",
      @"DDParsecRemoteCollectionViewController",
      @"AVFullScreenPlaybackControlsViewController",
      @"PLPhotoTileViewController",
      @"AVFullScreenViewController",
      @"CAMImagePickerCameraViewController",
      @"CKSMSComposeRemoteViewController",
      @"PUPhotoPickerHostViewController",
      @"PUUIAlbumListViewController",
      @"PUUIPhotosAlbumViewController",
      @"SFAppAutoFillPasswordViewController",
      @"PUUIMomentsGridViewController",
      @"SFPasswordRemoteViewController",
      @"UIWebRotatingAlertController",
      @"UIEditUserWordController",
      @"UISystemInputAssistantViewController",
      @"UISystemKeyboardDockController",
      @"UIPredictionViewController",
      @"UIActivityContentViewController",
      @"SFAirDropViewController",
      @"UICandidateViewController",//键盘
//      @"_UIDatePickerContainerViewController",
      @"_UICursorAccessoryViewController",
      @"_UIContextMenuActionsOnlyViewController",
    ];
     return blackList;
}
@end
