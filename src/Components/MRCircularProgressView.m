//
//  MRCircularProgressView.m
//  MRProgress
//
//  Created by Marius Rackwitz on 10.10.13.
//  Copyright (c) 2013 Marius Rackwitz. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MRCircularProgressView.h"
#import "MRProgressHelper.h"
#import "MRWeakProxy.h"


@interface MRCircularProgressView ()

@property (nonatomic, strong, readwrite) NSNumberFormatter *numberFormatter;

@property (nonatomic, weak, readwrite) UILabel *valueLabel;
@property (nonatomic, weak, readwrite) UIView *stopView;

@property (nonatomic, assign, readwrite) float fromProgress;
@property (nonatomic, assign, readwrite) float toProgress;
@property (nonatomic, assign, readwrite) CFTimeInterval startTime;
@property (nonatomic, strong, readwrite) CADisplayLink *displayLink;

@property (nonatomic, readonly) UIImageView *fillBackground;
@property (nonatomic, readonly) UIImageView *ringBackground;
@property (nonatomic, readonly) UIImageView *startCap;
@property (nonatomic, readonly) UIImageView *endCap;
@property (nonatomic, readonly) UIImageView *endSecondaryCap;

@end


@implementation MRCircularProgressView

- (void)setFillBackgroundAlpha:(CGFloat)fillBackgroundAlpha
{
    _fillBackgroundAlpha = fillBackgroundAlpha;
    _fillBackground.alpha = fillBackgroundAlpha;
}

- (void)setFillBackgroundImage:(UIImage *)fillBackgroundImage
{
    _fillBackgroundImage = fillBackgroundImage;
    [_fillBackground removeFromSuperview];
    if (fillBackgroundImage) {
        _fillBackground = [[UIImageView alloc] initWithImage: _fillBackgroundImage];
        _fillBackground.layer.mask = [[CAShapeLayer alloc] init];
        _arcLayer = [[CAShapeLayer alloc] init];
        [_fillBackground.layer addSublayer: _arcLayer];
        [self addSubview: _fillBackground];
        [self bringSubviewToFront: _startCap];
        [self bringSubviewToFront: _endCap];

        self.shapeLayer.lineWidth = ((CAShapeLayer*)self.layer).lineWidth;
        self.shapeLayer.fillColor = UIColor.clearColor.CGColor;
        self.shapeLayer.strokeColor = ((CAShapeLayer*)self.layer).strokeColor;
    } else {
        _fillBackground = nil;
    }
}

- (void)setRingBackgroundAlpha:(CGFloat)ringBackgroundAlpha
{
    _ringBackgroundAlpha = ringBackgroundAlpha;
    _ringBackground.alpha = ringBackgroundAlpha;
}

- (void)setRingBackgroundImage:(UIImage *)ringBackgroundImage
{
    _ringBackgroundImage = ringBackgroundImage;
    _ringBackground.image = ringBackgroundImage;
    _ringBackground.frame = CGRectMake(0.0f, 0.0f,
                                       _ringBackgroundImage.size.width,
                                       _ringBackgroundImage.size.height);
    _ringBackground.frame = CGRectOffset(_ringBackground.bounds,
                                         self.bounds.size.width / 2.0f - _ringBackground.bounds.size.width / 2.0f,
                                         self.bounds.size.height / 2.0f - _ringBackground.bounds.size.height / 2.0f);
}

- (void)setStartCapImage:(UIImage *)endCapImage
{
    _startCap.image = endCapImage;
    _startCap.frame = CGRectMake(self.bounds.size.width / 2.0f - endCapImage.size.width,
                                 -endCapImage.size.height / 2.0f,
                                 endCapImage.size.width,
                                 endCapImage.size.height);
}

- (void)setEndCapImage:(UIImage *)endCapImage
{
    _endCap.image = endCapImage;
    _endCap.frame = CGRectMake(self.bounds.size.width / 2.0f,
                               self.bounds.size.height / 2.0f - endCapImage.size.height / 2.0f,
                               endCapImage.size.width,
                               endCapImage.size.height);
    [self setEndCapTranform];
}

- (void)setEndCapSecondaryImage:(UIImage *)endCapSecondaryImage
{
    _endSecondaryCap.image = endCapSecondaryImage;
    _endSecondaryCap.frame = CGRectMake(self.bounds.size.width / 2.0f,
                                        self.bounds.size.height / 2.0f - endCapSecondaryImage.size.height / 2.0f,
                                        endCapSecondaryImage.size.width,
                                        endCapSecondaryImage.size.height);
    [self setEndCapTranform];
}

- (void)setStartCapAlpha:(CGFloat)startCapAlpha
{
    _startCapAlpha = startCapAlpha;
    _startCap.alpha = startCapAlpha;
}

- (void)setEndCapAlpha:(CGFloat)endCapAlpha
{
    _endCapAlpha = endCapAlpha;
    _endCap.alpha = endCapAlpha;
}

- (void)setEndCapSecondaryAlpha:(CGFloat)endCapSecondaryAlpha
{
    _endCapSecondaryAlpha = endCapSecondaryAlpha;
    _endSecondaryCap.alpha = endCapSecondaryAlpha;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

+ (Class)layerClass {
    return CAShapeLayer.class;
}

- (CAShapeLayer *)shapeLayer {
    return _fillBackground ? _arcLayer : (CAShapeLayer*)self.layer;
}

- (void)commonInit {
    self.animationDuration = 0.3;
    self.progress = 0;
    
    _ringBackground = [[UIImageView alloc] init];
    [self addSubview: _ringBackground];
    
    _startCap = [[UIImageView alloc] init];
    [self addSubview: _startCap];
    _endCap = [[UIImageView alloc] init];
    [self addSubview: _endCap];
    _endSecondaryCap = [[UIImageView alloc] init];
    [self addSubview: _endSecondaryCap];
    
    [self addTarget:self action:@selector(didTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(didTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    self.numberFormatter = numberFormatter;
    numberFormatter.numberStyle = NSNumberFormatterPercentStyle;
    numberFormatter.locale = NSLocale.currentLocale;
    
    self.layer.borderWidth = 2.0f;
    
    self.shapeLayer.lineWidth = 2.0f;
    self.shapeLayer.fillColor = UIColor.clearColor.CGColor;
    
    UILabel *valueLabel = [UILabel new];
    self.valueLabel = valueLabel;
    valueLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    valueLabel.textColor = UIColor.blackColor;
    valueLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:valueLabel];
    
    UIControl *stopView = [UIControl new];
    self.stopView = stopView;
    [self addSubview:stopView];
    
    [self mayStopDidChange];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _fillBackground.frame = CGRectOffset(_fillBackground.bounds,
                                         self.bounds.size.width / 2.0f - _fillBackground.bounds.size.width / 2.0f,
                                         self.bounds.size.height / 2.0f - _fillBackground.bounds.size.height / 2.0f);
    _fillBackground.layer.mask.frame = _fillBackground.bounds;
    _ringBackground.frame = CGRectOffset(_ringBackground.bounds,
                                         self.bounds.size.width / 2.0f - _ringBackground.bounds.size.width / 2.0f,
                                         self.bounds.size.height / 2.0f - _ringBackground.bounds.size.height / 2.0f);
    _arcLayer.frame = CGRectOffset(self.bounds,
                                   _fillBackground.bounds.size.width / 2.0f - self.bounds.size.width / 2.0f,
                                   _fillBackground.bounds.size.height / 2.0f - self.bounds.size.height / 2.0f);
    _startCap.frame = CGRectMake(self.bounds.size.width / 2.0f - _startCap.image.size.width,
                                 -_startCap.image.size.height / 2.0f,
                                 _startCap.image.size.width,
                                 _startCap.image.size.height);
    [self setEndCapTranform];

    const CGFloat offset = 4;
    CGRect valueLabelRect = self.bounds;
    valueLabelRect.origin.x += offset;
    valueLabelRect.size.width -= offset;
    self.valueLabel.frame = valueLabelRect;
    
    self.layer.cornerRadius = self.frame.size.width / 2.0f;
    ((CAShapeLayer*)self.layer).path = [self layoutPath].CGPath;
    _arcLayer.path = [self layoutPath].CGPath;
    ((CAShapeLayer*)_fillBackground.layer.mask).path = [self layoutMaskPath].CGPath;

    CGFloat stopViewSizeValue = MIN(self.bounds.size.width, self.bounds.size.height);
    CGSize stopViewSize = CGSizeMake(stopViewSizeValue, stopViewSizeValue);
    const CGFloat stopViewSizeRatio = 0.35;
    CGRect stopViewFrame = CGRectInset(MRCenterCGSizeInCGRect(stopViewSize, self.bounds),
                                       self.bounds.size.width * stopViewSizeRatio,
                                       self.bounds.size.height * stopViewSizeRatio);
    if (self.tracking && self.touchInside) {
        stopViewFrame = CGRectInset(stopViewFrame,
                                    self.bounds.size.width * 0.033,
                                    self.bounds.size.height * 0.033);
    }
    self.stopView.frame = stopViewFrame;
}

- (UIBezierPath *)layoutPath {
    const double TWO_M_PI = 2.0 * M_PI;
    const double startAngle = 0.75 * TWO_M_PI;
    const double endAngle = startAngle + TWO_M_PI * self.progress;
    
    CGFloat width = self.frame.size.width;
    return [UIBezierPath bezierPathWithArcCenter:CGPointMake(width/2.0f, width/2.0f)
                                          radius:width/2.0f - 2.5f
                                      startAngle:startAngle
                                        endAngle:endAngle
                                       clockwise:YES];
}

- (UIBezierPath *)layoutMaskPath {
    const double TWO_M_PI = 2.0 * M_PI;
    const double startAngle = 0.75 * TWO_M_PI;
    const double endAngle = startAngle + TWO_M_PI * self.progress;
    
    CGFloat width = _fillBackground.frame.size.width;
    UIBezierPath *path = [[UIBezierPath alloc] init];
    [path moveToPoint: CGPointMake(width/2.0f, width/2.0f)];
    [path addLineToPoint: CGPointMake(width/2.0f, 0.0f)];
    [path addArcWithCenter: CGPointMake(width/2.0f, width/2.0f)
                    radius: width/2.0f
                startAngle: startAngle
                  endAngle: endAngle
                 clockwise: YES];
    [path closePath];
    return path;
}

- (void)setEndCapTranform
{
    const double TWO_M_PI = 2.0 * M_PI;
    const double startAngle = 0.75 * TWO_M_PI;
    const double endAngle = startAngle + TWO_M_PI * self.progress;
    const CGFloat radius = self.bounds.size.width / 2.0f;
    
    _endCap.transform = CGAffineTransformIdentity;
    _endSecondaryCap.transform = CGAffineTransformIdentity;
    _endCap.frame = CGRectMake(radius + (radius * (cos(endAngle))) - _endCap.image.size.width / 2.0f,
                               radius + (radius * (sin(endAngle))) - _endCap.image.size.height / 2.0f,
                               _endCap.image.size.width, _endCap.image.size.height);
    _endSecondaryCap.frame = CGRectMake(radius + (radius * (cos(endAngle))) - _endSecondaryCap.image.size.width / 2.0f,
                                        radius + (radius * (sin(endAngle))) - _endSecondaryCap.image.size.height / 2.0f,
                                        _endSecondaryCap.image.size.width, _endSecondaryCap.image.size.height);
    _endCap.transform = CGAffineTransformMakeRotation(endAngle - startAngle);
    _endSecondaryCap.transform = CGAffineTransformMakeRotation(endAngle - startAngle);
}

#pragma mark - Hook tintColor

- (void)tintColorDidChange {
    [super tintColorDidChange];
    UIColor *tintColor = self.tintColor;
    self.shapeLayer.strokeColor = tintColor.CGColor;
    self.layer.borderColor = tintColor.CGColor;
    self.valueLabel.textColor = tintColor;
    self.stopView.backgroundColor = tintColor;
}


#pragma mark - May stop implementation

- (void)setMayStop:(BOOL)mayStop {
    _mayStop = mayStop;
    [self mayStopDidChange];
}

- (void)mayStopDidChange {
    self.enabled = self.mayStop;
    self.stopView.hidden = !self.mayStop;
    self.valueLabel.hidden = self.mayStop;
}

- (void)didTouchDown {
   [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
       [self layoutSubviews];
   } completion:nil];
}

- (void)didTouchUpInside {
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self layoutSubviews];
    } completion:nil];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self.stopView) {
        // Allow hits inside stop view
        return self;
    } else if (hitView == self) {
        // Ignore hits inside whole circular view
        return nil;
    }
    // Allow all other subviews (external?)
    return hitView;
}


#pragma mark - Control progress

- (void)setProgress:(float)progress {
    NSParameterAssert(progress >= 0 && progress <= 1);
    
    // Stop running animation
    if (self.displayLink) {
        [self.displayLink removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        self.displayLink = nil;
    }
    
    _progress = progress;
    
    [self updateProgress];
}

- (void)updateProgress {
    [self updatePath];
    [self updateLabel];
}

- (void)updatePath {
    ((CAShapeLayer*)self.layer).path = [self layoutPath].CGPath;
    _arcLayer.path = [self layoutPath].CGPath;
    ((CAShapeLayer*)_fillBackground.layer.mask).path = [self layoutMaskPath].CGPath;
    [self setEndCapTranform];
}

- (void)updateLabel {
    self.valueLabel.text = [self.numberFormatter stringFromNumber:@(self.progress)];
}

- (void)setProgress:(float)progress animated:(BOOL)animated {
    if (animated) {
        if (self.progress == progress) {
            return;
        }
        
        if (self.displayLink) {
            // Reuse current display link and manipulate animation params
            self.startTime = CACurrentMediaTime();
            self.fromProgress = self.progress;
            self.toProgress = progress;
        } else {
            [self animateToProgress:progress];
        }
    } else {
        self.progress = progress;
    }
}

- (void)setAnimationDuration:(CFTimeInterval)animationDuration {
    NSParameterAssert(animationDuration > 0);
    _animationDuration = animationDuration;
}

- (void)animateToProgress:(float)progress {
    self.fromProgress = self.progress;
    self.toProgress = progress;
    self.startTime = CACurrentMediaTime();
    
    [self.displayLink removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.displayLink = [CADisplayLink displayLinkWithTarget:[MRWeakProxy weakProxyWithTarget:self] selector:@selector(animateFrame:)];
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)animateFrame:(CADisplayLink *)displayLink {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        CGFloat d = (displayLink.timestamp - self.startTime) / self.animationDuration;
        
        if (d >= 1.0) {
            // Order is important! Otherwise concurrency will cause errors, because setProgress: will detect an
            // animation in progress and try to stop it by itself.
            [self.displayLink removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
            self.displayLink = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progress = self.toProgress;
            });
            
            return;
        }
        
        _progress = self.fromProgress + d * (self.toProgress - self.fromProgress);
        UIBezierPath *path = [self layoutPath];
        UIBezierPath *maskPath = [self layoutMaskPath];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ((CAShapeLayer*)self.layer).path = path.CGPath;
            _arcLayer.path = path.CGPath;
            ((CAShapeLayer*)_fillBackground.layer.mask).path = maskPath.CGPath;
            [self updateLabel];
            [self setEndCapTranform];
        });
    });
}

@end
