#import <Foundation/Foundation.h>

#include <node.h>
#include <v8.h>
#include <iostream>
#include <cstring>

using namespace v8;

struct async_data
{
    const char* path;
    const char* error;
    NSMutableSet* tags;
    NSMutableSet* updatingTags;
    Persistent<Function> callback;
};

void workGetTags(uv_work_t* req)
{
    async_data* data = static_cast<async_data*>(req->data);    

    NSString* s = [NSString stringWithUTF8String:data->path];
    NSURL* url = [NSURL fileURLWithPath:s];
    NSError* error = nil;
    NSArray* tags;
    
    [url getResourceValue:&tags forKey:NSURLTagNamesKey error:&error];

    if (error) {
        NSString* errorText = [error localizedDescription];
        int length = [errorText lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        data->error = strcpy(new char[length], [errorText UTF8String]);
    }

    data->tags = [NSMutableSet setWithArray:tags];    
}

void workSetTags(uv_work_t* req)
{    
    async_data* data = static_cast<async_data*>(req->data);

    NSString* s = [NSString stringWithUTF8String:data->path];
    NSURL* url = [NSURL fileURLWithPath:s];
    NSError* error = nil;
    
    [url setResourceValue:[data->tags allObjects] forKey:NSURLTagNamesKey error:&error];

    if (error) {
        NSString* errorText = [error localizedDescription];
        int length = [errorText lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        data->error = strcpy(new char[length], [errorText UTF8String]);
    }
}

void workAddTags(uv_work_t* req)
{
    workGetTags(req);

    async_data* data = static_cast<async_data*>(req->data);
    [data->updatingTags unionSet:data->tags];
    data->tags = data->updatingTags;

    workSetTags(req);
}

void workRemoveTags(uv_work_t* req)
{
    workGetTags(req);

    async_data* data = static_cast<async_data*>(req->data);
    [data->tags minusSet:data->updatingTags];

    workSetTags(req);
}

void afterGetTags(uv_work_t* req, int status)
{
    HandleScope scope;

    async_data* data = static_cast<async_data*>(req->data);

    TryCatch try_catch;
    Handle<Value> error;
    if (data->error) {        
        error = Exception::Error(String::New(data->error));
    } else {
        error = Null();
    }
    Handle<Value> args[2] = { error, Array::New([data->tags count]) };

    int i = 0;
    for (NSString* item in data->tags) {
        args[1].As<Array>()->Set(i++, String::New([item UTF8String]));
    }

    data->callback->Call(Context::GetCurrent()->Global(), 2, args);
    if (try_catch.HasCaught()) {
        node::FatalException(try_catch);
    }

    data->callback.Dispose();

    delete data->path;
    delete data;
    delete req;
}

void afterSetTags(uv_work_t* req, int status)
{
    HandleScope scope;
    async_data* data = static_cast<async_data*>(req->data);

    TryCatch try_catch;
    Handle<Value> error;
    if (data->error) {
        error = Exception::Error(String::New(data->error));
    } else {
        error = Null();
    }
    Handle<Value> args[1] = { error };

    data->callback->Call(Context::GetCurrent()->Global(), 1, args);
    if (try_catch.HasCaught()) {
        node::FatalException(try_catch);
    }

    data->callback.Dispose();

    delete data->path;
    delete data;
    delete req;
}

void afterAddTags(uv_work_t* req, int status)
{
    HandleScope scope;
    async_data* data = static_cast<async_data*>(req->data);

    TryCatch try_catch;
    Handle<Value> error;
    if (data->error) {
        error = Exception::Error(String::New(data->error));
    } else {
        error = Null();
    }
    Handle<Value> args[1] = { error };

    data->callback->Call(Context::GetCurrent()->Global(), 1, args);
    if (try_catch.HasCaught()) {
        node::FatalException(try_catch);
    }

    data->callback.Dispose();

    delete data->path;
    delete data;
    delete req;
}

void afterRemoveTags(uv_work_t* req, int status)
{
    HandleScope scope;
    async_data* data = static_cast<async_data*>(req->data);

    TryCatch try_catch;
    Handle<Value> error;
    if (data->error) {
        error = Exception::Error(String::New(data->error));
    } else {
        error = Null();
    }
    Handle<Value> args[1] = { error };

    data->callback->Call(Context::GetCurrent()->Global(), 1, args);
    if (try_catch.HasCaught()) {
        node::FatalException(try_catch);
    }

    data->callback.Dispose();

    delete data->path;
    delete data;
    delete req;
}

Handle<Value> getTags(const Arguments& args)
{
    HandleScope scope;

    if (args.Length() < 2) {
        ThrowException(Exception::TypeError(String::New("Wrong number of arguments")));
        return scope.Close(Undefined());
    }
    if (!args[0]->IsString()) {
        ThrowException(Exception::TypeError(String::New("Path must be a string")));
        return scope.Close(Undefined());
    }
    if (!args[1]->IsFunction()) {
        ThrowException(Exception::TypeError(String::New("Callback must be a function")));
        return scope.Close(Undefined());
    }

    async_data* data = new async_data;
    data->path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    data->callback = Persistent<Function>::New(args[1].As<Function>());
    data->error = NULL;

    uv_work_t *req = new uv_work_t;
    req->data = data;

    uv_queue_work(uv_default_loop(), req, workGetTags, (uv_after_work_cb)afterGetTags);

    return scope.Close(Undefined());
}

Handle<Value> setTags(const Arguments& args)
{
    HandleScope scope;

    if (args.Length() < 3) {
        ThrowException(Exception::TypeError(String::New("Wrong number of arguments")));
        return scope.Close(Undefined());
    }
    if (!args[0]->IsString()) {
        ThrowException(Exception::TypeError(String::New("Path must be a string")));
        return scope.Close(Undefined());
    }
    if (!args[1]->IsArray()) {
        ThrowException(Exception::TypeError(String::New("Tags must be an array")));
        return scope.Close(Undefined());
    }
    if (!args[2]->IsFunction()) {
        ThrowException(Exception::TypeError(String::New("Callback must be a function")));
        return scope.Close(Undefined());
    }

    async_data* data = new async_data;
    data->path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    data->callback = Persistent<Function>::New(args[2].As<Function>());
    data->tags = [NSMutableSet new];
    data->error = NULL;

    Local<Array> tags = args[1].As<Array>();
    for (uint32_t i = 0; i < tags->Length(); i++) {
        if (!tags->Get(i)->IsString()) {
            continue;
        }

        [data->tags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(tags->Get(i)))]];
    }

    uv_work_t *req = new uv_work_t;
    req->data = data;


    uv_queue_work(uv_default_loop(), req, workSetTags, (uv_after_work_cb)afterSetTags);

    return scope.Close(Undefined());
}

Handle<Value> addTags(const Arguments& args)
{
    HandleScope scope;

    if (args.Length() < 3) {
        ThrowException(Exception::TypeError(String::New("Wrong number of arguments")));
        return scope.Close(Undefined());
    }
    if (!args[0]->IsString()) {
        ThrowException(Exception::TypeError(String::New("Path must be a string")));
        return scope.Close(Undefined());
    }
    if (!args[1]->IsArray()) {
        ThrowException(Exception::TypeError(String::New("Tags must be an array")));
        return scope.Close(Undefined());
    }
    if (!args[2]->IsFunction()) {
        ThrowException(Exception::TypeError(String::New("Callback must be a function")));
        return scope.Close(Undefined());
    }

    async_data* data = new async_data;
    data->path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    data->callback = Persistent<Function>::New(args[2].As<Function>());
    data->updatingTags = [NSMutableSet new];
    data->error = NULL;

    Local<Array> updatingTags = args[1].As<Array>();
    for (uint32_t i = 0; i < updatingTags->Length(); i++) {
        if (!updatingTags->Get(i)->IsString()) {
            continue;
        }

        [data->updatingTags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(updatingTags->Get(i)))]];
    }

    uv_work_t *req = new uv_work_t;
    req->data = data;

    uv_queue_work(uv_default_loop(), req, workAddTags, (uv_after_work_cb)afterAddTags);

    return scope.Close(Undefined());
}

Handle<Value> removeTags(const Arguments& args)
{
    HandleScope scope;

    if (args.Length() < 2) {
        ThrowException(Exception::TypeError(String::New("Wrong number of arguments")));
        return scope.Close(Undefined());
    }
    if (!args[0]->IsString()) {
        ThrowException(Exception::TypeError(String::New("Path must be a string")));
        return scope.Close(Undefined());
    }
    if (!args[1]->IsArray()) {
        ThrowException(Exception::TypeError(String::New("Tags must be an array")));
        return scope.Close(Undefined());
    }
    if (!args[2]->IsFunction()) {
        ThrowException(Exception::TypeError(String::New("Callback must be a function")));
        return scope.Close(Undefined());
    }

    async_data* data = new async_data;
    data->path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    data->callback = Persistent<Function>::New(args[2].As<Function>());
    data->updatingTags = [NSMutableSet new];
    data->error = NULL;

    Local<Array> updatingTags = args[1].As<Array>();
    for (uint32_t i = 0; i < updatingTags->Length(); i++) {
        if (!updatingTags->Get(i)->IsString()) {
            continue;
        }

        [data->updatingTags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(updatingTags->Get(i)))]];
    }

    uv_work_t *req = new uv_work_t;
    req->data = data;

    uv_queue_work(uv_default_loop(), req, workRemoveTags, (uv_after_work_cb)afterRemoveTags);

    return scope.Close(Undefined());
}

void init(Handle<Object> exports)
{
    exports->Set(String::NewSymbol("getTags"),
        FunctionTemplate::New(getTags)->GetFunction());
    exports->Set(String::NewSymbol("setTags"),
        FunctionTemplate::New(setTags)->GetFunction());
    exports->Set(String::NewSymbol("addTags"),
        FunctionTemplate::New(addTags)->GetFunction());
    exports->Set(String::NewSymbol("removeTags"),
        FunctionTemplate::New(removeTags)->GetFunction());
}

NODE_MODULE(osx_tag, init)
