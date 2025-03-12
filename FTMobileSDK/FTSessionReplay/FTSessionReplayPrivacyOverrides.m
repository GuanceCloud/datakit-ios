//
//  FTSessionReplayPrivacyOverrides.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayPrivacyOverrides.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"

@implementation FTSessionReplayPrivacyOverrides
-(void)setImagePrivacy:(FTImagePrivacyLevel)imagePrivacy{
    _imagePrivacy = imagePrivacy;
    _nImagePrivacy = @(imagePrivacy);
}
-(void)setTouchPrivacy:(FTTouchPrivacyLevel)touchPrivacy{
    _touchPrivacy = touchPrivacy;
    _nTouchPrivacy = @(touchPrivacy);
}
- (void)setTextAndInputPrivacy:(FTTextAndInputPrivacyLevel)textAndInputPrivacy{
    _textAndInputPrivacy = textAndInputPrivacy;
    _nTextAndInputPrivacy = @(textAndInputPrivacy);
}
+ (PrivacyOverrides *)mergeChild:(PrivacyOverrides *)child parent:(PrivacyOverrides *)parent{
    if (!child) {
        return parent;
    }
    if (!parent) {
        return child;
    }
    child.nTextAndInputPrivacy = child.nTextAndInputPrivacy ?: parent.nTextAndInputPrivacy;
    child.nImagePrivacy = child.nImagePrivacy ?: parent.nImagePrivacy;
    child.nTouchPrivacy = child.nTouchPrivacy ?: parent.nTouchPrivacy;
    if (child.hide == YES || parent.hide == YES) {
        child.hide = YES;
    }
    return child;
}
@end
