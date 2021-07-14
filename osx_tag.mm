#import <Foundation/Foundation.h>

#include <node.h>
#include <nan.h>
#include <iostream>
#include <cstring>

using namespace v8;

class GetTagsWorker : public Nan::AsyncWorker {
public:
    GetTagsWorker(Nan::Callback *callback, const char *path)
        : Nan::AsyncWorker(callback), path([NSString stringWithUTF8String:path]) {}
    ~GetTagsWorker() {}

    void Execute()
    {
        NSURL *url = [NSURL fileURLWithPath:path];
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
        Nan::HandleScope scope;

        v8::Local<v8::Primitive> err = Nan::Null();
        v8::Local<v8::Object> tags = Nan::New<v8::Array>([this->tags count]);

        int i = 0;
        for (NSString *item in this->tags) {
            Nan::Set(tags, i++, Nan::New([item UTF8String]).ToLocalChecked());
        }

        v8::Local<v8::Value> argv[] = {err, tags};
        Nan::Call(*callback, 2, argv);
    }
private:
    NSMutableSet *tags;
    NSString *path;
};

class SetTagsWorker : public Nan::AsyncWorker {
public:
    SetTagsWorker(Nan::Callback *callback, const char *path, NSMutableSet *tags)
        : Nan::AsyncWorker(callback), path([NSString stringWithUTF8String:path]), tags(tags) {}
    ~SetTagsWorker() {}

    void Execute()
    {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;

        [url setResourceValue:[this->tags allObjects] forKey:NSURLTagNamesKey error:&error];

        if (error) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }

    void HandleOKCallback()
    {
        Nan::HandleScope scope;

        v8::Local<v8::Primitive> err = Nan::Null();
        v8::Local<v8::Object> tags = Nan::New<v8::Array>([this->tags count]);

        int i = 0;
        for (NSString *item in this->tags) {
            Nan::Set(tags, i++, Nan::New([item UTF8String]).ToLocalChecked());
        }

        v8::Local<v8::Value> argv[] = {err, tags};
        Nan::Call(*callback, 2, argv);
    }
private:
    NSString *path;
    NSMutableSet *tags;
};

class AddTagsWorker : public Nan::AsyncWorker {
public:
    AddTagsWorker(Nan::Callback *callback, const char *path, NSMutableSet *tags)
        : Nan::AsyncWorker(callback), path([NSString stringWithUTF8String:path]), tags(tags) {}
    ~AddTagsWorker() {}

    void Execute()
    {
        NSURL *url = [NSURL fileURLWithPath:path];
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
    NSString *path;
    NSMutableSet *tags;
};

class RemoveTagsWorker : public Nan::AsyncWorker {
public:
    RemoveTagsWorker(Nan::Callback *callback, const char *path, NSMutableSet *tags)
        : Nan::AsyncWorker(callback), path([NSString stringWithUTF8String:path]), tags(tags) {}
    ~RemoveTagsWorker() {}

    void Execute()
    {
        NSURL *url = [NSURL fileURLWithPath:path];
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
    NSString *path;
    NSMutableSet *tags;
};

NAN_METHOD(getTags)
{
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString()) {
        Nan::ThrowTypeError("Path must be a string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    Nan::Callback *callback = new Nan::Callback(info[1].As<Function>());

    Nan::AsyncQueueWorker(new GetTagsWorker(callback, *path));

    info.GetReturnValue().Set(Nan::Undefined());
}

NAN_METHOD(setTags)
{
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString()) {
        Nan::ThrowTypeError("Path must be a string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() >= 3 && !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    Nan::Callback *callback = new Nan::Callback(info[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    v8::Local<v8::Array> t = info[1].As<Array>();

    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!Nan::Get(t, i).ToLocalChecked()->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(Nan::Get(t, i).ToLocalChecked()))]];
    }

    Nan::AsyncQueueWorker(new SetTagsWorker(callback, *path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}

NAN_METHOD(addTags)
{
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString()) {
        Nan::ThrowTypeError("Path must be a string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() >= 3 && !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    Nan::Callback *callback = new Nan::Callback(info[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    Local<Array> t = info[1].As<Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!Nan::Get(t, i).ToLocalChecked()->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(Nan::Get(t, i).ToLocalChecked()))]];
    }

    Nan::AsyncQueueWorker(new AddTagsWorker(callback, *path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}

NAN_METHOD(removeTags)
{
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString()) {
        Nan::ThrowTypeError("Path must be a string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() >= 3 && !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    Nan::Callback *callback = new Nan::Callback(info[2].As<Function>());
    NSMutableSet *tags = [NSMutableSet new];

    Local<Array> t = info[1].As<Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        if (!Nan::Get(t, i).ToLocalChecked()->IsString()) {
            continue;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(Nan::Get(t, i).ToLocalChecked()))]];
    }

    Nan::AsyncQueueWorker(new RemoveTagsWorker(callback,*path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}

NAN_MODULE_INIT(init)
{
    Nan::Set(target,
        Nan::New<v8::String>("getTags").ToLocalChecked(),
        Nan::GetFunction(Nan::New<v8::FunctionTemplate>(getTags)).ToLocalChecked());
    Nan::Set(target,
        Nan::New<v8::String>("setTags").ToLocalChecked(),
        Nan::GetFunction(Nan::New<v8::FunctionTemplate>(setTags)).ToLocalChecked());
    Nan::Set(target,
        Nan::New<v8::String>("addTags").ToLocalChecked(),
        Nan::GetFunction(Nan::New<v8::FunctionTemplate>(addTags)).ToLocalChecked());
    Nan::Set(target,
        Nan::New<v8::String>("removeTags").ToLocalChecked(),
        Nan::GetFunction(Nan::New<v8::FunctionTemplate>(removeTags)).ToLocalChecked());
}

NODE_MODULE(osx_tag, init)
