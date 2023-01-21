//
//  _CLImageEditorViewController.h
//
//  Created by sho yakushiji on 2013/11/05.
//  Copyright (c) 2013年 CALACULU. All rights reserved.
//

#import "../CLImageEditor.h"

@interface _CLImageEditorViewController : CLImageEditor
<UIScrollViewDelegate, UIBarPositioningDelegate, UITextFieldDelegate>
{
    IBOutlet __weak UINavigationBar *_navigationBar;
    IBOutlet __weak UIScrollView *_scrollView;
}
@property (nonatomic, strong) UIImageView  *imageView;
@property (nonatomic, weak) IBOutlet UIScrollView *menuView;
@property (nonatomic, readonly) UIScrollView *scrollView;

@property (nonatomic, strong) UIView *captionView;
@property (nonatomic, strong) UITextField *captionTextField;
@property (nonatomic, strong) UIButton *sendBtn;
@property (nonatomic, strong) UILabel *toLabel;
@property (nonatomic, strong) UITextField *activeTextfield;

@property (nonatomic, strong) UIButton *backBtn;
@property (nonatomic, strong) UIButton *doneBtn;

- (IBAction)pushedCloseBtn:(id)sender;
- (IBAction)pushedFinishBtn:(id)sender;


- (id)initWithImage:(UIImage*)image;


- (void)fixZoomScaleWithAnimated:(BOOL)animated;
- (void)resetZoomScaleWithAnimated:(BOOL)animated;

@end
