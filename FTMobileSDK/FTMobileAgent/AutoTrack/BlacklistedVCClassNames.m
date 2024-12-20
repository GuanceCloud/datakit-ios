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
      @"SFSafariViewController",
      @"UITabBarController",
      @"SFBrowserRemoteViewController",
      @"UIAlertController",
      @"UIInputWindowController",
      @"UINavigationController",
      @"UIKeyboardCandidateGridCollectionViewController",
      @"UICompatibilityInputViewController",
      @"UIApplicationRotationFollowingController",
      @"UIApplicationRotationFollowingControllerNoTouches",
      @"AVPlayerViewController",
      @"UIActivityGroupViewController",
      @"UIReferenceLibraryViewController",
      @"UIKeyboardCandidateRowViewController",
      @"UIKeyboardHiddenViewController",
      @"_UIAlertControllerTextFieldViewController",
      @"_UILongDefinitionViewController",
      @"_UIResilientRemoteViewContainerViewController",
      @"_UIShareExtensionRemoteViewController",
      @"_UIRemoteDictionaryViewController",
      @"UISystemKeyboardDockController",
      @"_UINoDefinitionViewController",
      @"UIImagePickerController",
      @"_UIActivityGroupListViewController",
      @"_UIRemoteViewController",
      @"_UIFallbackPresentationViewController",
      @"_UIDocumentPickerRemoteViewController",
      @"_UIAlertShimPresentingViewController",
      @"_UIWaitingForRemoteViewContainerViewController",
      @"UIDocumentMenuViewController",
      @"UIActivityViewController",
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
      @"SLComposeViewController",
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
      @"_UIDatePickerContainerViewController",
      @"_UICursorAccessoryViewController",
      @"_UIContextMenuActionsOnlyViewController",
     ];
     return blackList;
}
@end
