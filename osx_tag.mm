#import <Foundation/Foundation.h>

#include <node.h>
#include <nan.h>
#include <iostream>
#include <cstring>

using namespace v8;

class GetTagsWorker : public NanAsyncWorker {
public:
    GetTagsWorker(NanCallback *callback, const char *path) : NanAsyncWorker(callback), path(path) {}
    ~GetTagsWorker() {}

    void Execute()
    {
        NSString *s = [NSString stringWithUTF8String:this->path];
        NSURL *url = [NSURL fileURLWithPath:s];
        NSError *error = nil;
        NSArray *tags;
        
        [url getResourceValue:&tags forKey:NSURLTagNamesKey error:&error];

        if (error) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            this->tags = [NSMutableSet setWithArray:tags];    
        }
    }

    void HandleOKCallback()
    {
        NanScope();

        Handle<Value> args[2] = { NanNull(), NanNew<v8::Array>([this->tags count]) };

        int i = 0;
        for (NSString *item in this->tags) {
            args[1].As<Array>()->Set(i++, NanNew([item UTF8String]));
        }

        callback->Call(2, args);
    }
private:
    NSMutableSet *tags;
    const char *path;
};

class SetTagsWorker : public NanAsyncWorker {
public:
    SetTagsWorker(NanCallback *callback, const char *path, NSMutableSet *tags) : NanAsyncWorker(callback), path(path), tags(tags) {}
    ~SetTagsWorker() {}

    void Execute()
    {
        NSString *s = [NSString stringWithUTF8String:this->path];
        NSURL *url = [NSURL fileURLWithPath:s];
        NSError *error = nil;
        
        [url setResourceValue:[this->tags allObjects] forKey:NSURLTagNamesKey error:&error];

        if (error) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }

    void HandleOKCallback()
    {
        NanScope();

        Handle<Value> args[2] = { NanNull(), NanNew<v8::Array>([this->tags count]) };

        int i = 0;
        for (NSString *item in this->tags) {
            args[1].As<Array>()->Set(i++, NanNew([item UTF8String]));
        }

        callback->Call(2, args);
    }
private:
    const char *path;
    NSMutableSet *tags;
};

class AddTagsWorker : public NanAsyncWorker {
public:
    AddTagsWorker(NanCallback *callback, const char *path, NSMutableSet *tags) : NanAsyncWorker(callback), path(path), tags(tags) {}
    ~AddTagsWorker() {}

    void Execute()
    {
        NSString *s = [NSString stringWithUTF8String:this->path];
        NSURL *url = [NSURL fileURLWithPath:s];
        NSError *error = nil;
        NSMutableSet *oldTags = nil;
        NSArray *oldTagsArray;

        [url getResourceValue:&oldTagsArray forKey:NSURLTagNamesKey error:&error];

        if (error) {
            return SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            oldTags = [NSMutableSet setWithArray:oldTagsArray];    
        }

        [tags unionSet:oldTags];

        [url setResourceValue:[tags allObjects] forKey:NSURLTagNamesKey error:&error];

        if (error) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }
private:
    const char *path;
    NSMutableSet *tags;
};

class RemoveTagsWorker : public NanAsyncWorker {
public:
    RemoveTagsWorker(NanCallback *callback, const char *path, NSMutableSet *tags) : NanAsyncWorker(callback), path(path), tags(tags) {}
    ~RemoveTagsWorker() {}

    void Execute()
    {
        NSString *s = [NSString stringWithUTF8String:this->path];
        NSURL *url = [NSURL fileURLWithPath:s];
        NSError *error = nil;
        NSMutableSet *oldTags = nil;
        NSArray *oldTagsArray;

        [url getResourceValue:&oldTagsArray forKey:NSURLTagNamesKey error:&error];

        if (error) {
            return SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            oldTags = [NSMutableSet setWithArray:oldTagsArray];    
        }

        [oldTags minusSet:tags];

        [url setResourceValue:[oldTags allObjects] forKey:NSURLTagNamesKey error:&error];

        if (error) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }
private:
    const char *path;
    NSMutableSet *tags;
};

NAN_METHOD(getTags)
{
    NanScope();

    if (args.Length() < 2) {
        NanThrowTypeError("Wrong number of arguments");
        NanReturnUndefined();
    }
    if (!args[0]->IsString()) {
        NanThrowTypeError("Path must be a string");
        NanReturnUndefined();
    }
    if (!args[1]->IsFunction()) {
        NanThrowTypeError("Callback must be a function");
        NanReturnUndefined();
    }

    const char *path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    NanCallback *callback = new NanCallback(args[1].As<Function>());

    NanAsyncQueueWorker(new GetTagsWorker(callback, path));

    NanReturnUndefined();
}

NAN_METHOD(setTags)
{
    NanScope();

    if (args.Length() < 2) {
        NanThrowTypeError("Wrong number of arguments");
        NanReturnUndefined();
    }
    if (!args[0]->IsString()) {
        NanThrowTypeError("Path must be a string");
        NanReturnUndefined();
    }
    if (!args[1]->IsArray()) {
        NanThrowTypeError("Tags must be an array");
        NanReturnUndefined();
    }
    if (args.Length() >= 3 && !args[2]->IsFunction()) {
        NanThrowTypeError("Callback must be a function");
        NanReturnUndefined();
    }

    const char *path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    NanCallback *callback = new NanCallback(args[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    Local<Array> t = args[1].As<Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!t->Get(i)->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(t->Get(i)))]];
    }

    NanAsyncQueueWorker(new SetTagsWorker(callback, path, tags));

    NanReturnUndefined();
}

NAN_METHOD(addTags)
{
    NanScope();

    if (args.Length() < 2) {
        NanThrowTypeError("Wrong number of arguments");
        NanReturnUndefined();
    }
    if (!args[0]->IsString()) {
        NanThrowTypeError("Path must be a string");
        NanReturnUndefined();
    }
    if (!args[1]->IsArray()) {
        NanThrowTypeError("Tags must be an array");
        NanReturnUndefined();
    }
    if (args.Length() >= 3 && !args[2]->IsFunction()) {
        NanThrowTypeError("Callback must be a function");
        NanReturnUndefined();
    }

    const char *path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    NanCallback *callback = new NanCallback(args[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    Local<Array> t = args[1].As<Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!t->Get(i)->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(t->Get(i)))]];
    }

    NanAsyncQueueWorker(new AddTagsWorker(callback, path, tags));

    NanReturnUndefined();
}

NAN_METHOD(removeTags)
{
    NanScope();

    if (args.Length() < 2) {
        NanThrowTypeError("Wrong number of arguments");
        NanReturnUndefined();
    }
    if (!args[0]->IsString()) {
        NanThrowTypeError("Path must be a string");
        NanReturnUndefined();
    }
    if (!args[1]->IsArray()) {
        NanThrowTypeError("Tags must be an array");
        NanReturnUndefined();
    }
    if (args.Length() >= 3 && !args[2]->IsFunction()) {
        NanThrowTypeError("Callback must be a function");
        NanReturnUndefined();
    }

    const char *path = strcpy(new char[String::Utf8Value(args[0]).length()], *(String::Utf8Value(args[0])));
    NanCallback *callback = new NanCallback(args[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    Local<Array> t = args[1].As<Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!t->Get(i)->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(String::Utf8Value(t->Get(i)))]];
    }

    NanAsyncQueueWorker(new RemoveTagsWorker(callback, path, tags));

    NanReturnUndefined();
}

void init(Handle<Object> exports)
{
    exports->Set(NanNew("getTags"),
        NanNew<FunctionTemplate>(getTags)->GetFunction());
    exports->Set(NanNew("setTags"),
        NanNew<FunctionTemplate>(setTags)->GetFunction());
    exports->Set(NanNew("addTags"),
        NanNew<FunctionTemplate>(addTags)->GetFunction());
    exports->Set(NanNew("removeTags"),
        NanNew<FunctionTemplate>(removeTags)->GetFunction());
}

NODE_MODULE(osx_tag, init)
