//
//  OpenCVWrapper.m
//  VideoEffects
//
//  Created by Stanley Chiang on 3/7/17.
//  Copyright © 2017 Stanley Chiang. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <Foundation/Foundation.h>
#import "OpenCVWrapper.hpp"

@implementation OpenCVWrapper
+ (CIImage*) processImageWithOpenCV: (CIImage*) inputImage
{
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImage *img = [context createCGImage:inputImage fromRect:[inputImage extent]];
    
    cv::Mat mat = [self cvMatFromCGImage:&img];
    mat = [self applyFilterToMat:mat];
    
    CGImageRelease(img);
    return [self CIImageFromCVMat:mat];
}

+ (cv::Mat)applyFilterToMat:(cv::Mat) src
{
    cv::Mat dst;
    cv::Canny(src, dst, 10, 30);
    return dst;
}

//converting into and out of cvmat is based on: http://docs.opencv.org/3.1.0/d3/def/tutorial_image_manipulation.html

+ (cv::Mat)cvMatFromCGImage:(CGImageRef *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(*image);
    CGFloat cols = CGImageGetWidth(*image);
    CGFloat rows = CGImageGetHeight(*image);
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), *image);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

+(CIImage *)CIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    // Getting CIImage from CGImage
    CIImage *finalImage = [CIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return finalImage;
}

@end
