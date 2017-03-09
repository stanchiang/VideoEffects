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

using namespace cv;
using namespace std;

@implementation OpenCVWrapper

HOGDescriptor hog;
bool initd = false;

- (CIImage*) processImageWithOpenCV: (CIImage*) inputImage
{
    if (!initd) {
        hog.setSVMDetector(HOGDescriptor::getDefaultPeopleDetector());
        
        initd = true;
    }
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImage *img = [context createCGImage:inputImage fromRect:[inputImage extent]];
    
    Mat mat = [self cvMatFromCGImage:&img];
    mat = [self applyFilterToMat:mat :hog];
    
    CGImageRelease(img);
    return [self CIImageFromCVMat:mat];
}

- (Mat)applyFilterToMat:(Mat) src :(HOGDescriptor) hog
{
    Mat dst;
    
//    https://github.com/opencv/opencv/blob/master/samples/cpp/peopledetect.cpp
    vector<cv::Rect> found, found_filtered;
    
    cvtColor( src, src, CV_RGBA2RGB );
    
    medianBlur(src, dst, 7);
    
    hog.detectMultiScale(src, found, 0, cv::Size(8,8), cv::Size(32,32), 1.05);
    
    for(size_t i = 0; i < found.size(); i++ )
    {
        cv::Rect r = found[i];
        
        size_t j;
        // Do not add small detections inside a bigger detection.
        for ( j = 0; j < found.size(); j++ )
            if ( j != i && (r & found[j]) == r )
                break;
        
        if ( j == found.size() )
            found_filtered.push_back(r);
    }
    
    for (size_t i = 0; i < found_filtered.size(); i++)
    {
        cv::Rect r = found_filtered[i];

        // The HOG detector returns slightly larger rectangles than the real objects,
        // so we slightly shrink the rectangles to get a nicer output.
        r.x += cvRound(r.width*0.1);
        r.width = cvRound(r.width*0.8);
        r.y += cvRound(r.height*0.07);
        r.height = cvRound(r.height*0.8);
//        rectangle(dst, r.tl(), r.br(), cv::Scalar(0,255,0), 1);
        src(r).copyTo(dst(r));
        
    }
    
    cvtColor( dst, dst, CV_RGB2RGBA );
    return dst;
}

//converting into and out of cvmat is based on: http://docs.opencv.org/3.1.0/d3/def/tutorial_image_manipulation.html

- (Mat)cvMatFromCGImage:(CGImageRef *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(*image);
    CGFloat cols = CGImageGetWidth(*image);
    CGFloat rows = CGImageGetHeight(*image);
    Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
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

-(CIImage *)CIImageFromCVMat:(Mat)cvMat
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
