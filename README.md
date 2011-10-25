# WebServiceManager

### A Simple Solution for Objective-C integration with Web APIs

The goal of this project is to provide a simple way to define an Objective-C wrapper for web services without writing much code. Instead of re-implementing web specific classes for every project, simply link in the WebServiceManager library, drop in a plist identifying your web API endpoints, and start implementing the delegates that will handle the data that comes back from your web service. 

The initial version of this class is _extremely_ limited, and can only handle GET requests, with no URL parameters. This will of course change, hopefully in the near future, to support all the HTTP request methods. That means no file uploads, no queries, no parameters. At least for now. 

This project is ARC only. I was tired of typing *autorelease*

### Features
* Specify your full set of APIs and callbacks in a plist file. 
* Refer to API by key (Defined in the plist) when calling
* Automatic data conversion for commonly used types (Image, JSON, PList, text)
* Success and Failure callbacks
* Request queuing. Every WebServiceManager object maintains is own queue of requests and will only issue one at a time. 

### So How Do I Use It?
I'm glad you asked. Check out the included WebServiceManagerTests project for a sample, but here's the short of it:

1. Create a class that needs to get data from a web service
2. Include the WebService*.* files or link in the resulting .a from this project (and of course copy the headers)
3. Create a plist that looks like the WebServiceManagerCalls.plist used in our test bundle. This will include all the endpoints you want to talk to in your application.
4. Create a WebServiceManager object; you'll need to give it the path to the plist file containing your web service information.
5. Call makeRequestWithKey:(NSString*)key andTarget:(id)target on the WebServiceManager object. "key" refers to the key of the API you defined in the PList. Target is the object that will handle the callbacks from the manager; this object should implement the success and failure cases defined in your plist for this api. 

### Overrides
* There aren't may things you can currently override, but as you can see in Test Case 5 (concurrent requests), you have the ability to override the success and failure cases of a request programatically. This of course defeats the purpose of using this framework, and should be avoided. 

### Roadmap
These items are the short term features I would like to add to this project. 

* Support for POST (and yeah, the other HTTP methods as well)
* support for basic key/value specified parameters lists for supported HTTP methods. 
* Support for mulitpart-form and file uploads
* support for streaming from disk for file uploads. 
* delegate callback for additional header and parameter injection to the mutable request before send.
* progress callbacks 
* More data converters. There's more to life than dictionaries and images.
* Data cache
* Specify number of concurrent allowable requests
* Core Data Mapping - map a requests results right into your database. 
