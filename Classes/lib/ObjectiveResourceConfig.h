//
//  ObjectiveResourceConfig.h
//  objective_resource
//
//  Created by vickeryj on 1/29/09.
//  Copyright 2009 Joshua Vickery. All rights reserved.
//

#import "ObjectiveResource.h"

@interface ObjectiveResourceConfig : NSObject 

+ (NSString *)getSite;
+ (void)setSite:(NSString*)siteURL;
+ (NSString *)getUser;
+ (void)setUser:(NSString *)user;
+ (NSString *)getPassword;
+ (void)setPassword:(NSString *)password;
+ (SEL)getParseDataMethod;
+ (void)setParseDataMethod:(SEL)parseMethod;
+ (SEL) getSerializeMethod;
+ (void) setSerializeMethod:(SEL)serializeMethod;
+ (NSString *)protocolExtension;
+ (void)setProtocolExtension:(NSString *)protocolExtension;
+ (void)setResponseType:(ORSResponseFormat) format;
+ (ORSResponseFormat)getResponseType;

/**
 Returns TRUE if the connection will submit multipart/related requests.
 Returns FALSE otherwise.  Defaults to TRUE.
 */
+ (BOOL) getAllowMultipart;

/**
 Set to TRUE if you want binary data to be sent as part of a multipart/related request.
 Set to FALSE if your server does not support multipart/requests.  (Binary data will be
 Base64-encoded into flat XML or JSON request.  Note that this approach is somewhat inefficient.)
 Defaults to TRUE.
 */
+ (void) setAllowMultipart: (BOOL) flag;


@end
