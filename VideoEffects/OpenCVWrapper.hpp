//
//  OpenCVWrapper.h
//  VideoEffects
//
//  Created by Stanley Chiang on 3/7/17.
//  Copyright © 2017 Stanley Chiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

- (CIImage*) processImageWithOpenCV: (CIImage*) inputImage;

@end
