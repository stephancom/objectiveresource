//
//  NSMutableURLRequest+ResponseType.m
//  active_resource
//
//  Created by James Burka on 1/19/09.
//  Copyright 2009 Burkaprojects. All rights reserved.
//

#import "NSMutableURLRequest+ResponseType.h"
#import "ObjectiveResource.h"
#import "Connection.h"

@implementation NSMutableURLRequest(ResponseType)


+(NSMutableURLRequest *) requestWithUrl:(NSURL *)url andMethod:(NSString*)method {
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData
																											timeoutInterval:[Connection timeout]];

	NSMutableString *rootMIMEType = [NSMutableString string];
	
	[request setHTTPMethod:method];
	switch ([ObjectiveResourceConfig getResponseType]) {
		case JSONResponse:
			rootMIMEType = @"application/json";
			break;
		default:
			rootMIMEType = @"application/xml";
			break;
	}
	
	[request setValue:rootMIMEType forHTTPHeaderField:@"Content-Type"];	
	[request addValue:rootMIMEType forHTTPHeaderField:@"Accept"];

	
	return request;
}

/**
 Returns this request's root mime type, which can be used to override defaults,
 as in the case of a request that needs to append multipart attachments
 */
- (NSString *) rootMIMEType {

	NSMutableString *rootMIMEType = [NSMutableString string];

	switch ([ObjectiveResourceConfig getResponseType]) {
		case JSONResponse:
			rootMIMEType = @"application/json";
			break;
		default:
			rootMIMEType = @"application/xml";
			break;
	}
		
	return rootMIMEType;	
}

@end
