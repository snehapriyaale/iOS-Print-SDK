//
//  Modified MIT License
//
//  Copyright (c) 2010-2016 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "NSArray+QueryingExtras.h"
#import "NSObject+Utils.h"
#import "OLSingleImageProductReviewViewController.h"
#import "OLPrintPhoto.h"
#import "OLAnalytics.h"
#import "OLAsset+Private.h"
#import "OLProductPrintJob.h"
#import "OLAsset+Private.h"
#import "OLCustomPhotoProvider.h"
#import "OLImageCachingManager.h"
#import "OLKiteABTesting.h"
#import "OLKitePrintSDK.h"
#import "OLKiteUtils.h"
#import "OLUserSession.h"
#import "OLNavigationController.h"
#ifdef COCOAPODS
#import <CTAssetsPickerController/CTAssetsPickerController.h>
#else
#import "CTAssetsPickerController.h"
#endif
#import "NSArray+QueryingExtras.h"
#import "OLKiteViewController.h"
#import "OLPaymentViewController.h"
#import "OLPrintPhoto.h"
#import "OLProductPrintJob.h"
#import "OLProductTemplateOption.h"
#import "OLRemoteImageView.h"
#import "OLRemoteImageCropper.h"
#import "OLAsset+Private.h"
#import "OLProductTemplateOption.h"
#import "OLPaymentViewController.h"
#import "UIViewController+OLMethods.h"
#import "OLSingleImageProductReviewViewController.h"
#import "OLQRCodeUploadViewController.h"
#import "OLURLDataSource.h"
#import "UIViewController+TraitCollectionCompatibility.h"
#import "OLUpsellViewController.h"

#import "OLCustomPhotoProvider.h"
#ifdef COCOAPODS
#import <KITAssetsPickerController/KITAssetsPickerController.h>
#else
#import "KITAssetsPickerController.h"
#endif

#ifdef OL_KITE_OFFER_INSTAGRAM
#import <InstagramImagePicker/OLInstagramImagePickerController.h>
#import <InstagramImagePicker/OLInstagramImage.h>
#endif

#ifdef OL_KITE_OFFER_FACEBOOK
#import <FacebookImagePicker/OLFacebookImagePickerController.h>
#import <FacebookImagePicker/OLFacebookImage.h>
#endif

#import "OLImagePreviewViewController.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface OLPaymentViewController (Private)
-(void)saveAndDismissReviewController;
@end

@interface OLPrintOrder (Private)
- (BOOL)hasOfferIdBeenUsed:(NSUInteger)identifier;
- (void)saveOrder;
@end

@interface OLKiteViewController ()

@property (strong, nonatomic) OLPrintOrder *printOrder;
@property (strong, nonatomic) NSMutableArray <OLCustomPhotoProvider *> *customImageProviders;
- (void)dismiss;

@end

@interface OLKitePrintSDK (InternalUtils)
#ifdef OL_KITE_OFFER_INSTAGRAM
+ (NSString *) instagramRedirectURI;
+ (NSString *) instagramSecret;
+ (NSString *) instagramClientID;
#endif
@end

@interface OLSingleImageProductReviewViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, OLQRCodeUploadViewControllerDelegate, UIGestureRecognizerDelegate, OLUpsellViewControllerDelegate,
#ifdef OL_KITE_OFFER_INSTAGRAM
OLInstagramImagePickerControllerDelegate,
#endif
#ifdef OL_KITE_OFFER_FACEBOOK
OLFacebookImagePickerControllerDelegate,
#endif
CTAssetsPickerControllerDelegate,
KITAssetsPickerControllerDelegate,
RMImageCropperDelegate, UIViewControllerPreviewingDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *imagesCollectionView;

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet OLRemoteImageCropper *imageCropView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *maskAspectRatio;
@property (strong, nonatomic) OLPrintPhoto *imagePicked;
@property (strong, nonatomic) OLPrintPhoto *imageDisplayed;
@property (strong, nonatomic) NSIndexPath *previewingIndexPath;
@property (nonatomic, copy) void (^saveJobCompletionHandler)();
@property (nonatomic, strong) UITapGestureRecognizer *tapBehindQRUploadModalGestureRecognizer;

@end

static BOOL hasMoved;

@interface OLProduct ()
@property (strong, nonatomic) NSMutableSet <OLUpsellOffer *>*declinedOffers;
@property (strong, nonatomic) NSMutableSet <OLUpsellOffer *>*acceptedOffers;
@property (strong, nonatomic) OLUpsellOffer *redeemedOffer;
- (BOOL)hasOfferIdBeenUsed:(NSUInteger)identifier;
@end

@interface OLProductPrintJob ()
@property (strong, nonatomic) NSMutableSet <OLUpsellOffer *>*declinedOffers;
@property (strong, nonatomic) NSMutableSet <OLUpsellOffer *>*acceptedOffers;
@property (strong, nonatomic) OLUpsellOffer *redeemedOffer;
@end

@implementation OLSingleImageProductReviewViewController

-(void)viewDidLoad{
    [super viewDidLoad];
    
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackReviewScreenViewed:self.product.productTemplate.name];
#endif
    
    if ([UITraitCollection class] && [self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable){
        [self registerForPreviewingWithDelegate:self sourceView:self.imagesCollectionView];
        [self registerForPreviewingWithDelegate:self sourceView:self.imageCropView];
    }
    
    if ([OLKiteABTesting sharedInstance].launchedWithPrintOrder){
        if ([[OLKiteABTesting sharedInstance].launchWithPrintOrderVariant isEqualToString:@"Review-Overview-Checkout"]){
            [self.ctaButton setTitle:NSLocalizedStringFromTableInBundle(@"Next", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") forState:UIControlStateNormal];
        }
        
        if(!self.editingPrintJob){
            OLKiteViewController *kiteVc = [OLKiteUtils kiteVcForViewController:self];
            self.editingPrintJob = [kiteVc.printOrder.jobs firstObject];
            self.product.uuid = self.editingPrintJob.uuid;
        }
    }
    
    if ([self.presentingViewController respondsToSelector:@selector(viewControllers)] || !self.presentingViewController) {
        UIViewController *paymentVc = [(UINavigationController *)self.presentingViewController viewControllers].lastObject;
        if ([paymentVc respondsToSelector:@selector(saveAndDismissReviewController)]){
            [self.ctaButton setTitle:NSLocalizedStringFromTableInBundle(@"Save", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") forState:UIControlStateNormal];
            [self.ctaButton removeTarget:self action:@selector(onButtonNextClicked) forControlEvents:UIControlEventTouchUpInside];
            [self.ctaButton addTarget:paymentVc action:@selector(saveAndDismissReviewController) forControlEvents:UIControlEventTouchUpInside];
        }
    }
    
    self.ctaButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.ctaButton.titleLabel.minimumScaleFactor = 0.5;
    
    self.title = NSLocalizedStringFromTableInBundle(@"Reposition the Photo", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"");
    
    if (self.imageCropView){
        self.imageCropView.delegate = self;
        OLPrintPhoto *photo = [[OLUserSession currentSession].userSelectedPhotos firstObject];
        self.imageDisplayed = photo;
        [photo screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.imageCropView setImage:image];
                self.imageCropView.imageView.transform = self.imageDisplayed.edits.cropTransform;
            });
        }];
    }
    
    for (OLPrintPhoto *printPhoto in [OLUserSession currentSession].userSelectedPhotos){
        [printPhoto unloadImage];
    }
    
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapGestureRecognized)];
    gesture.delegate = self;
    [self.imageCropView addGestureRecognizer:gesture];
    
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Back", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
    
    self.imagesCollectionView.dataSource = self;
    self.imagesCollectionView.delegate = self;
    
    if (![OLKiteUtils imageProvidersAvailable:self] && [OLUserSession currentSession].userSelectedPhotos.count == 1){
        self.imagesCollectionView.hidden = YES;
    }
    
    [self.hintView viewWithTag:10].transform = CGAffineTransformMakeRotation(M_PI_4);
    
    self.hintView.layer.masksToBounds = NO;
    self.hintView.layer.shadowOffset = CGSizeMake(-5, -5);
    self.hintView.layer.shadowRadius = 5;
    self.hintView.layer.shadowOpacity = 0.3;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    NSTimeInterval delay = 1;
    NSTimeInterval duration = 0.3;
    if ([OLUserSession currentSession].userSelectedPhotos.count == 0 && self.hintView.alpha <= 0.1f) {
        [UIView animateWithDuration:duration delay:delay options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.hintView.alpha = 1;
        } completion:NULL];
    }
}

- (void)onTapGestureRecognized{
    [self enterFullCrop:YES];
}

- (void)enterFullCrop:(BOOL)animated{
    if (!self.imageCropView.imageView.image){
        return;
    }
    
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackReviewScreenEnteredCropScreenForProductName:self.product.productTemplate.name];
#endif
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if ([self.presentingViewController respondsToSelector:@selector(viewControllers)]) {
        UIViewController *presentingVc = [(UINavigationController *)self.presentingViewController viewControllers].lastObject;
        if (![presentingVc isKindOfClass:[OLPaymentViewController class]]){
            [self addBasketIconToTopRight];
        }
    }
    else{
        [self addBasketIconToTopRight];
    }
    
    hasMoved = NO;
    self.imageCropView.imageView.transform = self.imageDisplayed.edits.cropTransform;
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
#ifndef OL_NO_ANALYTICS
    if (!self.navigationController){
        [OLAnalytics trackReviewScreenHitBack:self.product.productTemplate.name numberOfPhotos:[OLUserSession currentSession].userSelectedPhotos.count];
    }
#endif
}

-(IBAction)onButtonNextClicked{
    if ([self shouldDoCheckout]){
        [self doCheckout];
    }
}

- (void)saveJobWithCompletionHandler:(void(^)())handler{
    
    self.imageDisplayed.edits.cropImageFrame = [self.imageCropView getFrameRect];
    self.imageDisplayed.edits.cropImageRect = [self.imageCropView getImageRect];
    self.imageDisplayed.edits.cropImageSize = [self.imageCropView croppedImageSize];
    self.imageDisplayed.edits.cropTransform = self.imageCropView.imageView.transform;
    
    OLAsset *asset = [OLAsset assetWithDataSource:[self.imageDisplayed copy]];
    [asset dataLengthWithCompletionHandler:^(long long dataLength, NSError *error){
        if (dataLength < 40000){
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Image Is Too Small", @"") message:NSLocalizedString(@"Please zoom out or pick a higher quality image", @"") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:NULL]];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Print It Anyway", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self saveJobNowWithCompletionHandler:handler];
            }]];
            [self presentViewController:alert animated:YES completion:NULL];
            return;
            
        }
        
        [self saveJobNowWithCompletionHandler:handler];
    }];
}

- (void)saveJobNowWithCompletionHandler:(void(^)())handler {
    OLAsset *asset = [OLAsset assetWithDataSource:[self.imageDisplayed copy]];
    NSArray *assetArray = @[asset];
    
    OLPrintOrder *printOrder = [OLKiteUtils kiteVcForViewController:self].printOrder;
    OLProductPrintJob *job = [[OLProductPrintJob alloc] initWithTemplateId:self.product.templateId OLAssets:assetArray];
    for (NSString *option in self.product.selectedOptions.allKeys){
        [job setValue:self.product.selectedOptions[option] forOption:option];
    }
    NSArray *jobs = [NSArray arrayWithArray:printOrder.jobs];
    for (id<OLPrintJob> existingJob in jobs){
        if ([existingJob.uuid isEqualToString:self.product.uuid]){
            job.dateAddedToBasket = [existingJob dateAddedToBasket];
            if ([existingJob extraCopies] > 0){
                [existingJob setExtraCopies:[existingJob extraCopies]-1];
            }
            else{
                [printOrder removePrintJob:existingJob];
            }
            job.uuid = self.product.uuid;
        }
    }
    [job.acceptedOffers addObjectsFromArray:self.product.acceptedOffers.allObjects];
    [job.declinedOffers addObjectsFromArray:self.product.declinedOffers.allObjects];
    job.redeemedOffer = self.product.redeemedOffer;
    self.product.uuid = job.uuid;
    self.editingPrintJob = job;
    if ([printOrder.jobs containsObject:self.editingPrintJob]){
        id<OLPrintJob> existingJob = printOrder.jobs[[printOrder.jobs indexOfObject:self.editingPrintJob]];
        [existingJob setExtraCopies:[existingJob extraCopies]+1];
    }
    else{
        [printOrder addPrintJob:self.editingPrintJob];
    }
    
    [printOrder saveOrder];
    
    if (handler){
        handler();
    }
    
    self.saveJobCompletionHandler = nil;
}

- (BOOL)shouldDoCheckout{
    OLUpsellOffer *offer = [self upsellOfferToShow];
    BOOL shouldShowOffer = offer != nil;
    if (offer){
        shouldShowOffer &= offer.minUnits <= [OLUserSession currentSession].userSelectedPhotos.count;
        shouldShowOffer &= [OLProduct productWithTemplateId:offer.offerTemplate] != nil;
    }
    if (shouldShowOffer){
        OLUpsellViewController *c = [self.storyboard instantiateViewControllerWithIdentifier:@"OLUpsellViewController"];
        c.providesPresentationContextTransitionStyle = true;
        c.definesPresentationContext = true;
        c.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        c.delegate = self;
        c.offer = offer;
        c.triggeredProduct = self.product;
        [self presentViewController:c animated:NO completion:NULL];
        return NO;
    }
    else{
        return YES;
    }
}

- (OLUpsellOffer *)upsellOfferToShow{
    NSArray *upsells = self.product.productTemplate.upsellOffers;
    if (upsells.count == 0){
        return nil;
    }
    
    OLUpsellOffer *offerToShow;
    for (OLUpsellOffer *offer in upsells){
        //Check if offer is valid for this point
        if (offer.active && offer.type == OLUpsellOfferTypeItemAdd){
            
            if ([self.product hasOfferIdBeenUsed:offer.identifier]){
                continue;
            }
            if ([[OLKiteUtils kiteVcForViewController:self].printOrder hasOfferIdBeenUsed:offer.identifier]){
                continue;
            }
            
            //Find the max priority offer
            if (!offerToShow || offerToShow.priority < offer.priority){
                offerToShow = offer;
            }
        }
    }
    
    return offerToShow;
}

-(void) doCheckout{
    if (!self.imageCropView.image) {
        return;
    }
    
    [self saveJobWithCompletionHandler:^{
        if ([OLKiteABTesting sharedInstance].launchedWithPrintOrder && [[OLKiteABTesting sharedInstance].launchWithPrintOrderVariant isEqualToString:@"Review-Overview-Checkout"]){
            UIViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"OLProductOverviewViewController"];
            [vc safePerformSelector:@selector(setUserEmail:) withObject:[(OLKiteViewController *)vc userEmail]];
            [vc safePerformSelector:@selector(setUserPhone:) withObject:[(OLKiteViewController *)vc userPhone]];
            [vc safePerformSelector:@selector(setKiteDelegate:) withObject:self.delegate];
            [vc safePerformSelector:@selector(setProduct:) withObject:self.product];
            [self.navigationController pushViewController:vc animated:YES];
        }
        else{
            OLPrintOrder *printOrder = [OLKiteUtils kiteVcForViewController:self].printOrder;
            [OLKiteUtils checkoutViewControllerForPrintOrder:printOrder handler:^(id vc){
                [vc safePerformSelector:@selector(setUserEmail:) withObject:[OLKiteUtils userEmail:self]];
                [vc safePerformSelector:@selector(setUserPhone:) withObject:[OLKiteUtils userPhone:self]];
                [vc safePerformSelector:@selector(setKiteDelegate:) withObject:[OLKiteUtils kiteDelegate:self]];
                
                [self.navigationController pushViewController:vc animated:YES];
            }];
        }
    }];
}

- (void)imageCropperDidTransformImage:(RMImageCropper *)imageCropper{
#ifndef OL_NO_ANALYTICS
    if (!hasMoved){
        hasMoved = YES;
        [OLAnalytics trackReviewScreenDidCropPhotoForProductName:self.product.productTemplate.name];
    }
#endif
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location{
    if (previewingContext.sourceView == self.imagesCollectionView){
        NSIndexPath *indexPath = [self.imagesCollectionView indexPathForItemAtPoint:location];
        UICollectionViewCell *cell = [self.imagesCollectionView cellForItemAtIndexPath:indexPath];
        
        OLRemoteImageView *imageView = (OLRemoteImageView *)[cell viewWithTag:11];
        if (!imageView.image){
            return nil;
        }
        
        self.previewingIndexPath = indexPath;
        
        UIImageView *cellImageView = [cell viewWithTag:1];
        
        [previewingContext setSourceRect:[cell convertRect:cellImageView.frame toView:self.imagesCollectionView]];
        
        OLImagePreviewViewController *previewVc = [self.storyboard instantiateViewControllerWithIdentifier:@"OLImagePreviewViewController"];
        [[OLUserSession currentSession].userSelectedPhotos[indexPath.item] screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                previewVc.image = image;
            });
        }];
        previewVc.providesPresentationContextTransitionStyle = true;
        previewVc.definesPresentationContext = true;
        previewVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        return previewVc;
    }
    else if (previewingContext.sourceView == self.imageCropView){
        OLImagePreviewViewController *previewVc = [self.storyboard instantiateViewControllerWithIdentifier:@"OLImagePreviewViewController"];
        [self.imageDisplayed screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                previewVc.image = image;
            });
        }];
        previewVc.providesPresentationContextTransitionStyle = true;
        previewVc.definesPresentationContext = true;
        previewVc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        return previewVc;
    }
    else{
        return nil;
    }
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit{
    if (previewingContext.sourceView == self.imagesCollectionView){
        [self collectionView:self.imagesCollectionView didSelectItemAtIndexPath:self.previewingIndexPath];
    }
    else if (previewingContext.sourceView == self.imageCropView){
        [self enterFullCrop:NO];
    }
}

#pragma mark CollectionView delegate and data source

- (NSInteger) sectionForMoreCell{
    return 0;
}

- (NSInteger) sectionForImageCells{
    return [OLKiteUtils imageProvidersAvailable:self] ? 1 : 0;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if (section == [self sectionForImageCells]){
        return [OLUserSession currentSession].userSelectedPhotos.count;
    }
    else if (section == [self sectionForMoreCell]){
        return 1;
    }
    else{
        return 0;
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    if ([OLKiteUtils imageProvidersAvailable:self]){
        return 2;
    }
    else{
        return 1;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == [self sectionForImageCells]){
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"imageCell" forIndexPath:indexPath];
        
        for (UIView *view in cell.subviews){
            if ([view isKindOfClass:[OLRemoteImageView class]]){
                [view removeFromSuperview];
            }
        }
        
        OLRemoteImageView *imageView = [[OLRemoteImageView alloc] initWithFrame:CGRectMake(0, 0, 138, 138)];
        imageView.tag = 11;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        [cell addSubview:imageView];
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        NSDictionary *views = NSDictionaryOfVariableBindings(imageView);
        NSMutableArray *con = [[NSMutableArray alloc] init];
        
        NSArray *visuals = @[@"H:|-0-[imageView]-0-|",
                             @"V:|-0-[imageView]-0-|"];
        
        
        for (NSString *visual in visuals) {
            [con addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:visual options:0 metrics:nil views:views]];
        }
        
        [imageView.superview addConstraints:con];
        
        
        [[OLUserSession currentSession].userSelectedPhotos[indexPath.item] screenImageWithSize:imageView.frame.size applyEdits:NO progress:^(float progress){
            dispatch_async(dispatch_get_main_queue(), ^{
                [imageView setProgress:progress];
            });
        }completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = image;
            });
        }];
        
        return cell;
    }
    
    else {
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"moreCell" forIndexPath:indexPath];
        return cell;
    }
    
    
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    return CGSizeMake(collectionView.frame.size.height, collectionView.frame.size.height);
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

- (CGFloat) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    NSInteger numberOfProviders = 0;
    NSInteger numberOfCustomProviders = [OLKiteUtils kiteVcForViewController:self].customImageProviders.count;
    numberOfProviders += numberOfCustomProviders;
    
    if ([OLKiteUtils cameraRollEnabled:self]){
        numberOfProviders++;
    }
    if ([OLKiteUtils facebookEnabled]){
        numberOfProviders++;
    }
    if ([OLKiteUtils instagramEnabled]){
        numberOfProviders++;
    }
    
    if ([OLKiteUtils qrCodeUploadEnabled]) {
        numberOfProviders++;
    }
    
    if (indexPath.section == [self sectionForImageCells]){
        OLRemoteImageView *imageView = (OLRemoteImageView *)[cell viewWithTag:11];
        if (!imageView.image){
            return;
        }
        
        self.imageDisplayed = [OLUserSession currentSession].userSelectedPhotos[indexPath.item];
        
        id activityView = [self.view viewWithTag:1010];
        if ([activityView isKindOfClass:[UIActivityIndicatorView class]]){
            [(UIActivityIndicatorView *)activityView startAnimating];
        }
        self.imageCropView.imageView.image = nil;
        __weak OLSingleImageProductReviewViewController *welf = self;
        [self.imageDisplayed screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:^(float progress){
            dispatch_async(dispatch_get_main_queue(), ^{
                [welf.imageCropView setProgress:progress];
            });
        }completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                [activityView stopAnimating];
                [welf.imageCropView setImage:image];
                [welf.view setNeedsLayout];
                [welf.view layoutIfNeeded];
                welf.imageCropView.imageView.transform = welf.imageDisplayed.edits.cropTransform;
            });
        }];
    }
    else if (numberOfProviders > 1){
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTableInBundle(@"Add photos from:", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") preferredStyle:UIAlertControllerStyleActionSheet];
        if ([OLKiteUtils cameraRollEnabled:self]){
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTableInBundle(@"Camera Roll", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showCameraRollImagePicker];
            }]];
        }
        if ([OLKiteUtils instagramEnabled]){
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Instagram", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showInstagramImagePicker];
            }]];
        }
        if ([OLKiteUtils facebookEnabled]){
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Facebook", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showFacebookImagePicker];
            }]];
        }
        if ([OLKiteUtils qrCodeUploadEnabled]) {
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTableInBundle(@"Transfer from your phone", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showQRCodeImagePicker];
            }]];
        }
        for (OLCustomPhotoProvider *provider in [OLKiteUtils kiteVcForViewController:self].customImageProviders){
            [ac addAction:[UIAlertAction actionWithTitle:provider.name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                [self showPickerForProvider:provider];
            }]];
        }
        
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"KitePrintSDK", [OLKiteUtils kiteBundle], @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
            [ac dismissViewControllerAnimated:YES completion:NULL];
        }]];
        ac.popoverPresentationController.sourceView = cell;
        ac.popoverPresentationController.sourceRect = cell.frame;
        [self presentViewController:ac animated:YES completion:NULL];
    }
    else{
        if ([OLKiteUtils cameraRollEnabled:self]){
            [self showCameraRollImagePicker];
        }
        else if ([OLKiteUtils facebookEnabled]){
            [self showFacebookImagePicker];
        }
        else if ([OLKiteUtils instagramEnabled]){
            [self showInstagramImagePicker];
        }
        else{
            [self showPickerForProvider:[OLKiteUtils kiteVcForViewController:self].customImageProviders.firstObject];
        }
    }
}

- (void)onQRCodeScannerDidCancel{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.view.window removeGestureRecognizer:self.tapBehindQRUploadModalGestureRecognizer];
    self.tapBehindQRUploadModalGestureRecognizer = nil;
}

- (void)onTapBehindQRCodeScannerModal:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint location = [sender locationInView:nil]; // Passing nil gives us coordinates in the window
        // swap (x,y) on iOS 8 in landscape
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
            if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                location = CGPointMake(location.y, location.x);
            }
        }
        
        // Convert tap location into the local view's coordinate system. If outside, dismiss the view.
        if (![self.presentedViewController.view pointInside:[self.presentedViewController.view convertPoint:location fromView:self.view.window] withEvent:nil]) {
            if(self.presentedViewController) {
                [self dismissViewControllerAnimated:YES completion:nil];
                [self.view.window removeGestureRecognizer:sender];
                self.tapBehindQRUploadModalGestureRecognizer = nil;
                
            }
        }
    }
}

- (NSArray *)createAssetArray {
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[OLUserSession currentSession].userSelectedPhotos.count];
    for (OLPrintPhoto *object in [OLUserSession currentSession].userSelectedPhotos) {
        if ([object.asset isKindOfClass:[OLAsset class]] && [object.asset dataSource]){
            [array addObject:[object.asset dataSource]];
        }
        else if (![object.asset isKindOfClass:[OLAsset class]] && object.asset){
            [array addObject:object.asset];
        }
    }
    return array;
}

- (void)showCameraRollImagePicker{
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProviderPicked:@"Camera Roll" forProductName:self.product.productTemplate.name];
#endif
    __block UIViewController *picker;
    __block Class assetClass;
    
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined){
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
            if (status == PHAuthorizationStatusAuthorized){
                picker = [[CTAssetsPickerController alloc] init];
                ((CTAssetsPickerController *)picker).showsEmptyAlbums = NO;
                PHFetchOptions *options = [[PHFetchOptions alloc] init];
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
                ((CTAssetsPickerController *)picker).assetsFetchOptions = options;
                assetClass = [PHAsset class];
                ((CTAssetsPickerController *)picker).delegate = self;
                NSArray *allAssets = [[self createAssetArray] mutableCopy];
                NSMutableArray *alAssets = [[NSMutableArray alloc] init];
                for (id asset in allAssets){
                    if ([asset isKindOfClass:assetClass]){
                        [alAssets addObject:asset];
                    }
                }
                [(id)picker setSelectedAssets:alAssets];
                picker.modalPresentationStyle = [OLKiteUtils kiteVcForViewController:self].modalPresentationStyle;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:picker animated:YES completion:nil];
                });
            }
        }];
    }
    else{
        picker = [[CTAssetsPickerController alloc] init];
        ((CTAssetsPickerController *)picker).showsEmptyAlbums = NO;
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
        ((CTAssetsPickerController *)picker).assetsFetchOptions = options;
        assetClass = [PHAsset class];
        ((CTAssetsPickerController *)picker).delegate = self;
    }
    if (picker){
        NSArray *allAssets = [[self createAssetArray] mutableCopy];
        NSMutableArray *alAssets = [[NSMutableArray alloc] init];
        for (id asset in allAssets){
            if ([asset isKindOfClass:assetClass]){
                [alAssets addObject:asset];
            }
        }
        [(id)picker setSelectedAssets:alAssets];
        picker.modalPresentationStyle = [OLKiteUtils kiteVcForViewController:self].modalPresentationStyle;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)showFacebookImagePicker{
#ifdef OL_KITE_OFFER_FACEBOOK
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProviderPicked:@"Facebook" forProductName:self.product.productTemplate.name];
#endif
    OLFacebookImagePickerController *picker = nil;
    picker = [[OLFacebookImagePickerController alloc] init];
    picker.delegate = self;
    picker.selected = [self createAssetArray];
    picker.modalPresentationStyle = [OLKiteUtils kiteVcForViewController:self].modalPresentationStyle;
    [self presentViewController:picker animated:YES completion:nil];
#endif
}

- (void)showInstagramImagePicker{
#ifdef OL_KITE_OFFER_INSTAGRAM
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProviderPicked:@"Instagram" forProductName:self.product.productTemplate.name];
#endif
    OLInstagramImagePickerController *picker = nil;
    picker = [[OLInstagramImagePickerController alloc] initWithClientId:[OLKitePrintSDK instagramClientID] secret:[OLKitePrintSDK instagramSecret] redirectURI:[OLKitePrintSDK instagramRedirectURI]];
    picker.delegate = self;
    picker.selected = [self createAssetArray];
    picker.modalPresentationStyle = [OLKiteUtils kiteVcForViewController:self].modalPresentationStyle;
    [self presentViewController:picker animated:YES completion:nil];
#endif
}

- (void)showQRCodeImagePicker{
    OLQRCodeUploadViewController *vc = (OLQRCodeUploadViewController *) [[UIStoryboard storyboardWithName:@"OLKiteStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"OLQRCodeUploadViewController"];
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    vc.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || [self isHorizontalSizeClassCompact]){
        vc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onQRCodeScannerDidCancel)];
        OLNavigationController *nvc = [[OLNavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:nvc animated:YES completion:nil];
    }
    else{
        [self presentViewController:vc animated:YES completion:nil];
    }
    
    self.tapBehindQRUploadModalGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapBehindQRCodeScannerModal:)];
    self.tapBehindQRUploadModalGestureRecognizer.delegate = self;
    [self.tapBehindQRUploadModalGestureRecognizer setNumberOfTapsRequired:1];
    [self.tapBehindQRUploadModalGestureRecognizer setCancelsTouchesInView:NO]; // So the user can still interact with controls in the modal view
    [self.view.window addGestureRecognizer:self.tapBehindQRUploadModalGestureRecognizer];
}

- (void)showPickerForProvider:(OLCustomPhotoProvider *)provider{
    UIViewController<KITCustomAssetPickerController> *vc;
    if (provider.vc){
        vc = provider.vc;
    }
    else{
        KITAssetsPickerController *kvc = [[KITAssetsPickerController alloc] init];
        kvc.collectionDataSources = provider.collections;
        vc = kvc;
    }
    
    if ([vc respondsToSelector:@selector(setSelectedAssets:)]){
        [vc performSelector:@selector(setSelectedAssets:) withObject:[[self createAssetArray] mutableCopy]];
    }
    vc.delegate = self;
    vc.modalPresentationStyle = [OLKiteUtils kiteVcForViewController:self].modalPresentationStyle;
    [self presentViewController:vc animated:YES completion:NULL];
}

#pragma mark OLUpsellViewControllerDelegate

- (void)userDidDeclineUpsell:(OLUpsellViewController *)vc{
    [self.product.declinedOffers addObject:vc.offer];
    [vc dismissViewControllerAnimated:NO completion:^{
        [self doCheckout];
    }];
}

- (id<OLPrintJob>)addItemToBasketWithTemplateId:(NSString *)templateId{
    OLProduct *offerProduct = [OLProduct productWithTemplateId:templateId];
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    if (offerProduct.productTemplate.templateUI == kOLTemplateUINonCustomizable){
        //Do nothing, no assets needed
    }
    else if (offerProduct.quantityToFulfillOrder == 1){
        [assets addObject:[OLAsset assetWithDataSource:[[OLUserSession currentSession].userSelectedPhotos.firstObject copy]]];
    }
    else{
        for (OLPrintPhoto *photo in [OLUserSession currentSession].userSelectedPhotos){
            [assets addObject:[OLAsset assetWithDataSource:[photo copy]]];
        }
    }
    
    id<OLPrintJob> job;
    if ([OLProductTemplate templateWithId:templateId].templateUI == kOLTemplateUIPhotobook){
        job = [OLPrintJob photobookWithTemplateId:templateId OLAssets:assets frontCoverOLAsset:nil backCoverOLAsset:nil];
    }
    else{
        job = [OLPrintJob printJobWithTemplateId:templateId OLAssets:assets];
    }
    
    [[OLKiteUtils kiteVcForViewController:self].printOrder addPrintJob:job];
    return job;
}

- (void)userDidAcceptUpsell:(OLUpsellViewController *)vc{
    [self.product.acceptedOffers addObject:vc.offer];
    [vc dismissViewControllerAnimated:NO completion:^{
        if (vc.offer.prepopulatePhotos){
            id<OLPrintJob> job = [self addItemToBasketWithTemplateId:vc.offer.offerTemplate];
            [(OLProductPrintJob *)job setRedeemedOffer:vc.offer];
            [self doCheckout];
        }
        else{
            [self saveJobWithCompletionHandler:^{
                OLProduct *offerProduct = [OLProduct productWithTemplateId:vc.offer.offerTemplate];
                UIViewController *nextVc = [self.storyboard instantiateViewControllerWithIdentifier:[OLKiteUtils reviewViewControllerIdentifierForProduct:offerProduct photoSelectionScreen:[OLKiteUtils imageProvidersAvailable:self]]];
                [nextVc safePerformSelector:@selector(setKiteDelegate:) withObject:self.delegate];
                [nextVc safePerformSelector:@selector(setProduct:) withObject:offerProduct];
                NSMutableArray *stack = [self.navigationController.viewControllers mutableCopy];
                [stack removeObject:self];
                [stack addObject:nextVc];
                [self.navigationController setViewControllers:stack animated:YES];
            }];
        }
    }];
}

#pragma mark - CTAssetsPickerControllerDelegate Methods

- (void)populateArrayWithNewArray:(NSArray *)array dataType:(Class)class {
    NSMutableArray *photoArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    
    for (id object in array) {
        if ([object isKindOfClass:[OLPrintPhoto class]]){
            [photoArray addObject:object];
        }
        else{
            OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
            printPhoto.asset = object;
            [photoArray addObject:printPhoto];
        }
    }
    
    // First remove any that are not returned.
    NSMutableArray *removeArray = [NSMutableArray arrayWithArray:[OLUserSession currentSession].userSelectedPhotos];
    for (OLPrintPhoto *object in [OLUserSession currentSession].userSelectedPhotos) {
        if ([object.asset isKindOfClass:[OLAsset class]] && [[object.asset dataSource] isKindOfClass:class]){
            if ([photoArray containsObject:object]){
                [removeArray removeObjectIdenticalTo:object];
                [photoArray removeObject:object];
            }
        }
        else if (![object.asset isKindOfClass:class]) {
            [removeArray removeObjectIdenticalTo:object];
        }
        
        else if([photoArray containsObject:object]){
            [removeArray removeObjectIdenticalTo:object];
        }
    }
    
    [[OLUserSession currentSession].userSelectedPhotos removeObjectsInArray:removeArray];
    
    // Second, add the remaining objects to the end of the array without replacing any.
    NSMutableArray *addArray = [NSMutableArray arrayWithArray:photoArray];
    for (id object in [OLUserSession currentSession].userSelectedPhotos) {
        if ([addArray containsObject:object]){
            [addArray removeObject:object];
        }
    }
    
    for (OLPrintPhoto *photo in addArray){
        if (![removeArray containsObject:photo]){
            self.imagePicked = photo;
            break;
        }
    }
    
    [[OLUserSession currentSession].userSelectedPhotos addObjectsFromArray:addArray];
    
    [self.imagesCollectionView reloadData];
    
    if ([OLUserSession currentSession].userSelectedPhotos.count > 0){
        self.hintView.alpha = 0;
    }
}

- (void)assetsPickerController:(id)picker didFinishPickingAssets:(NSArray *)assets {
    id view = [self.view viewWithTag:1010];
    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView *)view startAnimating];
    }
    
    NSInteger originalCount = [OLUserSession currentSession].userSelectedPhotos.count;
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProvider:@"Camera Roll" numberOfPhotosAdded:[OLUserSession currentSession].userSelectedPhotos.count - originalCount forProductName:self.product.productTemplate.name];
#endif
    Class assetClass;
    if ([picker isKindOfClass:[CTAssetsPickerController class]]){
        assetClass = [PHAsset class];
    }
    else if ([picker isKindOfClass:[KITAssetsPickerController class]]){
        NSMutableArray *olAssets = [[NSMutableArray alloc] init];
        for (id<OLAssetDataSource> asset in assets){
            if ([asset isKindOfClass:[OLPrintPhoto class]]){
                [olAssets addObject:asset];
                assetClass = [assets.lastObject class];
            }
            else if ([asset respondsToSelector:@selector(dataWithCompletionHandler:)]){
                [olAssets addObject:[OLAsset assetWithDataSource:asset]];
                assetClass = [[olAssets.lastObject dataSource] class];
            }
        }
        assets = olAssets;
    }
    [self populateArrayWithNewArray:assets dataType:assetClass];
    
    if (self.imagePicked){
        self.imageDisplayed = self.imagePicked;
        __weak OLSingleImageProductReviewViewController *welf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.imagePicked screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
                dispatch_async(dispatch_get_main_queue(), ^{
                    welf.imageCropView.image = image;
                    welf.imagePicked = nil;
                    
                    if ([OLUserSession currentSession].userSelectedPhotos.count > 0){
                        id view = [welf.view viewWithTag:1010];
                        if ([view isKindOfClass:[UIActivityIndicatorView class]]){
                            [(UIActivityIndicatorView *)view stopAnimating];
                        }
                    }
                });
            }];
        });
        
    }
    [picker dismissViewControllerAnimated:YES completion:^(void){}];
    
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didDeSelectAsset:(PHAsset *)asset{
    if (![asset isKindOfClass:[PHAsset class]]){
        return;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    [[OLImageCachingManager sharedInstance].photosCachingManager stopCachingImagesForAssets:@[asset] targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:options];
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didSelectAsset:(PHAsset *)asset{
    if (![asset isKindOfClass:[PHAsset class]]){
        return;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.networkAccessAllowed = YES;
    [[OLImageCachingManager sharedInstance].photosCachingManager startCachingImagesForAssets:@[asset] targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFill options:options];
}

#ifdef OL_KITE_OFFER_INSTAGRAM
#pragma mark - OLInstagramImagePickerControllerDelegate Methods

- (void)instagramImagePicker:(OLInstagramImagePickerController *)imagePicker didFailWithError:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)instagramImagePicker:(OLInstagramImagePickerController *)imagePicker didFinishPickingImages:(NSArray *)images {
    id view = [self.view viewWithTag:1010];
    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView *)view startAnimating];
    }
    
    
    NSInteger originalCount = [OLUserSession currentSession].userSelectedPhotos.count;
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    for (id<OLAssetDataSource> asset in images){
        if ([asset isKindOfClass:[OLInstagramImage class]]){
            [assets addObject:asset];
        }
    }
    images = assets;
    
    [self populateArrayWithNewArray:images dataType:[OLInstagramImage class]];
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProvider:@"Instagram" numberOfPhotosAdded:[OLUserSession currentSession].userSelectedPhotos.count - originalCount forProductName:self.product.productTemplate.name];
#endif
    if (self.imagePicked){
        __weak OLSingleImageProductReviewViewController *welf = self;
        [self.imagePicked screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                welf.imageCropView.image = image;
                
                if ([OLUserSession currentSession].userSelectedPhotos.count > 0){
                    id view = [welf.view viewWithTag:1010];
                    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
                        [(UIActivityIndicatorView *)view stopAnimating];
                    }
                }
            });
        }];
        self.imageDisplayed = self.imagePicked;
        self.imagePicked = nil;
    }
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

- (void)instagramImagePickerDidCancelPickingImages:(OLInstagramImagePickerController *)imagePicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
#endif

#ifdef OL_KITE_OFFER_FACEBOOK
#pragma mark - OLFacebookImagePickerControllerDelegate Methods

- (void)facebookImagePicker:(OLFacebookImagePickerController *)imagePicker didFailWithError:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)facebookImagePicker:(OLFacebookImagePickerController *)imagePicker didFinishPickingImages:(NSArray *)images {
    id view = [self.view viewWithTag:1010];
    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView *)view startAnimating];
    }
    
    NSInteger originalCount = [OLUserSession currentSession].userSelectedPhotos.count;
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    for (id<OLAssetDataSource> asset in images){
        if ([asset isKindOfClass:[OLFacebookImage class]]){
            [assets addObject:asset];
        }
    }
    images = assets;
    
    [self populateArrayWithNewArray:images dataType:[OLFacebookImage class]];
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackPhotoProvider:@"Facebook" numberOfPhotosAdded:[OLUserSession currentSession].userSelectedPhotos.count - originalCount forProductName:self.product.productTemplate.name];
#endif
    if (self.imagePicked){
        __weak OLSingleImageProductReviewViewController *welf = self;
        [self.imagePicked screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
            dispatch_async(dispatch_get_main_queue(), ^{
                welf.imageCropView.image = image;
                
                if ([OLUserSession currentSession].userSelectedPhotos.count > 0){
                    id view = [welf.view viewWithTag:1010];
                    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
                        [(UIActivityIndicatorView *)view stopAnimating];
                    }
                }
            });
        }];
        self.imageDisplayed = self.imagePicked;
        self.imagePicked = nil;
    }
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

- (void)facebookImagePickerDidCancelPickingImages:(OLFacebookImagePickerController *)imagePicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
#endif

#pragma mark OLQRCodeUploadViewControllerDelegate methods
- (void)qrCodeUpload:(OLQRCodeUploadViewController *)vc didFinishPickingAsset:(OLAsset *)asset {
    id view = [self.view viewWithTag:1010];
    if ([view isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView *)view startAnimating];
    }
    
    OLPrintPhoto *printPhoto = [[OLPrintPhoto alloc] init];
    printPhoto.asset = asset;
    [[OLUserSession currentSession].userSelectedPhotos addObject:printPhoto];
    self.imagePicked = printPhoto;
    
    __weak OLSingleImageProductReviewViewController *welf = self;
    [self.imagePicked screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
        dispatch_async(dispatch_get_main_queue(), ^{
            welf.imageCropView.image = image;
            
            if ([OLUserSession currentSession].userSelectedPhotos.count > 0){
                id view = [welf.view viewWithTag:1010];
                if ([view isKindOfClass:[UIActivityIndicatorView class]]){
                    [(UIActivityIndicatorView *)view stopAnimating];
                }
            }
        });
    }];
    self.imageDisplayed = self.imagePicked;
    self.imagePicked = nil;
    
    [self.imagesCollectionView reloadData];
    
    [self dismissViewControllerAnimated:YES completion:^(void){}];
    [self.view.window removeGestureRecognizer:self.tapBehindQRUploadModalGestureRecognizer];
    self.tapBehindQRUploadModalGestureRecognizer = nil;
}

#pragma mark - OLImageEditorViewControllerDelegate methods

- (void)scrollCropViewControllerDidCancel:(OLScrollCropViewController *)cropper{
    [cropper dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)scrollCropViewControllerDidDropChanges:(OLScrollCropViewController *)cropper{
    [cropper dismissViewControllerAnimated:NO completion:NULL];
}

-(void)scrollCropViewController:(OLScrollCropViewController *)cropper didFinishCroppingImage:(UIImage *)croppedImage{
    [self.imageDisplayed unloadImage];
    
    self.imageDisplayed.edits = cropper.edits;
    [self.imageCropView setImage:nil];
    id activityView = [self.view viewWithTag:1010];
    if ([activityView isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView *)activityView startAnimating];
    }
    
    __weak OLSingleImageProductReviewViewController *welf = self;
    [self.imageDisplayed screenImageWithSize:[UIScreen mainScreen].bounds.size applyEdits:NO progress:NULL completionHandler:^(UIImage *image){
        dispatch_async(dispatch_get_main_queue(), ^{
            [activityView stopAnimating];
            [welf.imageCropView setImage:image];
            [welf.view setNeedsLayout];
            [welf.view layoutIfNeeded];
            welf.imageCropView.imageView.transform = welf.imageDisplayed.edits.cropTransform;
        });
    }];
    
    [cropper dismissViewControllerAnimated:YES completion:^{
        [UIView animateWithDuration:0.25 animations:^{
        }];
    }];
    
#ifndef OL_NO_ANALYTICS
    [OLAnalytics trackReviewScreenDidCropPhotoForProductName:self.product.productTemplate.name];
#endif
}

#pragma mark - UIGestureRecognizer Delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ((gestureRecognizer.view == self.imageCropView && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) || (![otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] && otherGestureRecognizer.state == UIGestureRecognizerStateEnded)){
        gestureRecognizer.enabled = NO;
        gestureRecognizer.enabled = YES;
        return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}


@end
