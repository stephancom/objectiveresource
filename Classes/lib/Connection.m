//
//  Connection.m
//  
//
//  Created by Ryan Daigle on 7/30/08.
//  Copyright 2008 yFactorial, LLC. All rights reserved.
//

#import "Connection.h"
#import "Response.h"
#import "ORBinaryData.h"
#import "NSData+Additions.h"
#import "NSMutableURLRequest+ResponseType.h"
#import "ConnectionDelegate.h"

//#define debugLog(...) NSLog(__VA_ARGS__)
#ifndef debugLog(...)
	#define debugLog(...)
#endif

@implementation Connection

static float timeoutInterval = 5.0;

static NSMutableArray *activeDelegates;

+ (NSMutableArray *)activeDelegates {
	if (nil == activeDelegates) {
		activeDelegates = [NSMutableArray array];
		[activeDelegates retain];
	}
	return activeDelegates;
}

+ (void)setTimeout:(float)timeOut {
	timeoutInterval = timeOut;
}
+ (float)timeout {
	return timeoutInterval;
}

+ (void)logRequest:(NSURLRequest *)request to:(NSString *)url {
	debugLog(@"%@ -> %@", [request HTTPMethod], url);
	if([request HTTPBody]) {
		debugLog([[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease]);
	}
}

+ (Response *)sendRequest:(NSMutableURLRequest *)request withUser:(NSString *)user andPassword:(NSString *)password {
	
	//lots of servers fail to implement http basic authentication correctly, so we pass the credentials even if they are not asked for
	//TODO make this configurable?
	NSURL *url = [request URL];
	if(user && password) {
		NSString *authString = [[[NSString stringWithFormat:@"%@:%@",user, password] dataUsingEncoding:NSUTF8StringEncoding] base64Encoding];
		[request addValue:[NSString stringWithFormat:@"Basic %@", authString] forHTTPHeaderField:@"Authorization"]; 
		NSString *escapedUser = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
																																								(CFStringRef)user, NULL, (CFStringRef)@"@.:", kCFStringEncodingUTF8);
		NSString *escapedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
																																										(CFStringRef)password, NULL, (CFStringRef)@"@.:", kCFStringEncodingUTF8);
		NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@://%@:%@@%@",[url scheme],escapedUser,escapedPassword,[url host],nil];
		if([url port]) {
			[urlString appendFormat:@":%@",[url port],nil];
		}
		[urlString appendString:[url path]];
		if([url query]){
			[urlString appendFormat:@"?%@",[url query],nil];
		}
		[request setURL:[NSURL URLWithString:urlString]];
		[escapedUser release];
		[escapedPassword release];
	}


	[self logRequest:request to:[url absoluteString]];
	
	ConnectionDelegate *connectionDelegate = [[[ConnectionDelegate alloc] init] autorelease];

	[[self activeDelegates] addObject:connectionDelegate];
	NSURLConnection *connection = [[[NSURLConnection alloc] initWithRequest:request delegate:connectionDelegate startImmediately:NO] autorelease];
	connectionDelegate.connection = connection;

	
	//use a custom runloop
	static NSString *runLoopMode = @"com.yfactorial.objectiveresource.connectionLoop";
	[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:runLoopMode];
	[connection start];
	while (![connectionDelegate isDone]) {
		[[NSRunLoop currentRunLoop] runMode:runLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.3]];
	}
	Response *resp = [Response responseFrom:(NSHTTPURLResponse *)connectionDelegate.response 
								   withBody:connectionDelegate.data 
								   andError:connectionDelegate.error];
	[resp log];
	
	[activeDelegates removeObject:connectionDelegate];
	
	//if there are no more active delegates release the array
	if (0 == [activeDelegates count]) {
		NSMutableArray *tempDelegates = activeDelegates;
		activeDelegates = nil;
		[tempDelegates release];
	}
	
	return resp;
}

+ (Response *)post:(NSString *)body to:(NSString *)url withAttachments:(NSMutableArray *) attachments {
	return [self post:body to:url withAttachments:attachments withUser:@"X" andPassword:@"X"];
}

+ (Response *)sendBy:(NSString *)method withBody:(NSString *)body to:(NSString *)url withAttachments:(NSMutableArray *) attachments withUser:(NSString *)user andPassword:(NSString *)password{

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithUrl:[NSURL URLWithString:url] andMethod:method];
	
	// If the request includes attachments, we have to format it as a "multipart/related" request
	// (note that this differs from a multipart/form-data request)
	if ([attachments count]) {

		NSMutableData *formattedBody = [[NSMutableData alloc] init];

		// The main request body and each attachment must be separated by a string boundary pattern
		// It doesn't really matter what pattern is used, so long as it doesn't match a string of
		// actual content.  I've borrowed this particular pattern from ASIHTTPRequest's implmentation
		// of ASIFormDataRequest.  You can find their code at http://allseeing-i.com/ASIHTTPRequest/
		NSString *stringBoundary = @"0xKhTmLbOuNdArY";
		

		// override default content type configured by the requestWithURL:andMethod method
		[request setValue:(@"multipart/related; boundary=%@; type=\"%@\"",stringBoundary, [request rootMIMEType]) forHTTPHeaderField:@"Content-Type"];
		
		// Set the boundary for the root content and declare its MIME TYPE
		[formattedBody appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[formattedBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n",[request rootMIMEType]] dataUsingEncoding:NSUTF8StringEncoding]];

		// now append the main content
		[formattedBody appendData:[body dataUsingEncoding:NSUTF8StringEncoding]];

		// terminate the root content
		[formattedBody appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];

		// Loop through the attachments array and append each file
		for (ORBinaryData *attachment in attachments) {
			
			// counter used to generate unique content ids
			// if the caller hasn't set the property in the attached ORBinaryDatas
			int i = 1;
			
			// prepare header info
			NSString *mimetype = [[attachment MIMEType] length] ? [attachment MIMEType] : @"application/octet-stream";
			NSString *contentID = [[attachment contentId] length] ? [attachment contentId] : [NSString stringWithFormat:@"file%d", i];
			NSString *fileName= [[attachment fileName] length] ? [attachment fileName] : contentID;
			
			// generate headers
			[formattedBody appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
			[formattedBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n",mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
			[formattedBody appendData:[[NSString stringWithFormat:@"Content-ID: %@\r\n",contentID] dataUsingEncoding:NSUTF8StringEncoding]];
			[formattedBody appendData:[[NSString stringWithFormat:@"Content-Disposition: INLINE; filename=\"%@\"\r\n",fileName] dataUsingEncoding:NSUTF8StringEncoding]];
			
			// and add the file
//			[formattedBody appendData:[[attachment base64Encoding] dataUsingEncoding:NSUTF8StringEncoding]];
			[formattedBody appendData:[NSData dataWithData: (NSData *)attachment]];
			
			// add a blank line at the end of each attachment
			[formattedBody appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			
			i++;
			
		}
		
		// terminate the upload set with one last boundary string and a new line.
		[formattedBody appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
		
		// Calculate the upload size and add it to the headers
		[request setValue:[NSString stringWithFormat:@"%d", [formattedBody length]] forHTTPHeaderField:@"Content-Length"];
		
		// pass the formatted body to the main request object
		[request setHTTPBody:formattedBody];

		[formattedBody release];
		
		
	}
	else {
			// This request has no attachments.  Only include the main body 
			[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

	}
	
	
	return [self sendRequest:request withUser:user andPassword:password];
}

+ (Response *)post:(NSString *)body to:(NSString *)url withAttachments:(NSMutableArray *) attachments withUser:(NSString *)user andPassword:(NSString *)password{
	return [self sendBy:@"POST" withBody:body to:url withAttachments:attachments withUser:user andPassword:password];
}

+ (Response *)put:(NSString *)body to:(NSString *)url withAttachments:(NSMutableArray *) attachments withUser:(NSString *)user andPassword:(NSString *)password{
	return [self sendBy:@"PUT" withBody:body to:url withAttachments:attachments withUser:user andPassword:password];
}

+ (Response *)get:(NSString *)url {
	return [self get:url withUser:@"X" andPassword:@"X"];
}

+ (Response *)get:(NSString *)url withUser:(NSString *)user andPassword:(NSString *)password {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithUrl:[NSURL URLWithString:url] andMethod:@"GET"];
	return [self sendRequest:request withUser:user andPassword:password];
}

+ (Response *)delete:(NSString *)url withUser:(NSString *)user andPassword:(NSString *)password {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithUrl:[NSURL URLWithString:url] andMethod:@"DELETE"];
	return [self sendRequest:request withUser:user andPassword:password];
}

+ (void) cancelAllActiveConnections {
	for (ConnectionDelegate *delegate in activeDelegates) {
		[delegate performSelectorOnMainThread:@selector(cancel) withObject:nil waitUntilDone:NO];
	}
}

@end
