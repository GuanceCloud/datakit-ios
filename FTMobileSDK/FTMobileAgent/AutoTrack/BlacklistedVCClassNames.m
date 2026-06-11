//
//  BlacklistedVCClassNames.m
//  FTAutoTrack
//
//  Created by hulilei on 2020/4/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import "BlacklistedVCClassNames.h"
#import "FTInternalConstants.h"

@implementation BlacklistedVCClassNames
+ (NSDictionary *)ft_blacklistedViewControllerClassNames{
    static NSDictionary * blacklistedClasses  = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blacklistedClasses = @{
            FT_BLACK_LIST_VIEW:@{@"public":@[@"UIAlertController",
                                             @"UITabBarController",
                                             @"UINavigationController",
                                             @"SFSafariViewController",
                                             @"AVPlayerViewController",
                                             @"UIReferenceLibraryViewController",
                                             @"UIImagePickerController",
                                             @"UIDocumentMenuViewController",
                                             @"UIActivityViewController",
                                             @"SLComposeViewController",
                                             @"UISplitViewController",
                                             @"UIDocumentPickerViewController",
                                             @"UIDocumentBrowserViewController"],
                                 @"private":@[@"UIApplicationRotationFollowingController",
                                              @"UIApplicationRotationFollowingControllerNoTouches",
                                              @"SFBrowserRemoteViewController",
                                              @"UIInputWindowController",
                                              @"UIKeyboardCandidateGridCollectionViewController",
                                              @"UICompatibilityInputViewController",
                                              @"UIActivityGroupViewController",
                                              @"UIKeyboardCandidateRowViewController",
                                              @"UIKeyboardHiddenViewController",
                                              @"UIKeyboardHiddenViewController_Autofill",
                                              @"UIKeyboardHiddenViewController_Save",
                                              @"_SFAppAutoFillPasswordViewController",
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
                                              @"_UIContextMenuActionsOnlyViewController",
                                              @"UIPredictionViewController",
                                              @"UISystemInputAssistantViewController",
                                              @"UICandidateViewController",
                                              @"UIActivityContentViewController",
                                              @"SFAirDropViewController",
                                              @"_UICursorAccessoryViewController",
                                              @"_UISceneHostingViewController",
                                              @"_UIDatePickerContainerViewController",
                                              @"UITrackingElementWindowController",
                                 ],
            }
        };
    });
    return blacklistedClasses;
}
@end
