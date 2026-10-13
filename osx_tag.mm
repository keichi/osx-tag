#import <Foundation/Foundation.h>

#include <nan.h>
#include <mutex>

// Serializes tag read-modify-write so concurrent add/remove/set don't lose updates.
// ponytail: global lock, per-path locks if throughput matters
static std::mutex tagsMutex;

class GetTagsWorker : public Nan::AsyncWorker {
public:
    GetTagsWorker(Nan::Callback *callback, const char *path)
        : Nan::AsyncWorker(callback), path([NSString stringWithUTF8String:path]) {}
    ~GetTagsWorker() {}

    void Execute()
    {
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        NSArray *tags;

        if (![url getResourceValue:&tags forKey:NSURLTagNamesKey error:&error]) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            this->tags = [NSMutableSet setWithArray:tags];
        }
    }
    }

    void HandleOKCallback()
    {
    @autoreleasepool {
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
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        std::lock_guard<std::mutex> lock(tagsMutex);

        if (![url setResourceValue:[this->tags allObjects] forKey:NSURLTagNamesKey error:&error]) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }
    }

    void HandleOKCallback()
    {
    @autoreleasepool {
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
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        NSMutableSet *oldTags = nil;
        NSArray *oldTagsArray;
        std::lock_guard<std::mutex> lock(tagsMutex);

        if (![url getResourceValue:&oldTagsArray forKey:NSURLTagNamesKey error:&error]) {
            return SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            oldTags = [NSMutableSet setWithArray:oldTagsArray];
        }

        [tags unionSet:oldTags];

        if (![url setResourceValue:[tags allObjects] forKey:NSURLTagNamesKey error:&error]) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
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
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        NSMutableSet *oldTags = nil;
        NSArray *oldTagsArray;
        std::lock_guard<std::mutex> lock(tagsMutex);

        if (![url getResourceValue:&oldTagsArray forKey:NSURLTagNamesKey error:&error]) {
            return SetErrorMessage([[error localizedDescription] UTF8String]);
        } else {
            oldTags = [NSMutableSet setWithArray:oldTagsArray];
        }

        [oldTags minusSet:tags];

        if (![url setResourceValue:[oldTags allObjects] forKey:NSURLTagNamesKey error:&error]) {
            SetErrorMessage([[error localizedDescription] UTF8String]);
        }
    }
    }
private:
    NSString *path;
    NSMutableSet *tags;
};

NAN_METHOD(getTags)
{
@autoreleasepool {
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString() || info[0].As<v8::String>()->Length() == 0) {
        Nan::ThrowTypeError("Path must be a non-empty string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    Nan::Callback *callback = new Nan::Callback(info[1].As<v8::Function>());

    Nan::AsyncQueueWorker(new GetTagsWorker(callback, *path));

    info.GetReturnValue().Set(Nan::Undefined());
}
}

NAN_METHOD(setTags)
{
@autoreleasepool {
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString() || info[0].As<v8::String>()->Length() == 0) {
        Nan::ThrowTypeError("Path must be a non-empty string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() < 3 || !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    NSMutableSet *tags = [NSMutableSet new];

    v8::Local<v8::Array> t = info[1].As<v8::Array>();

    for (uint32_t i = 0; i < t->Length(); i++) {
        v8::Local<v8::Value> v;
        if (!Nan::Get(t, i).ToLocal(&v)) {
            return;
        }
        if (!v->IsString()) {
            Nan::ThrowTypeError("Tags must be an array of strings");
            info.GetReturnValue().Set(Nan::Undefined());
            return;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(v))]];
    }

    Nan::Callback *callback = new Nan::Callback(info[2].As<v8::Function>());
    Nan::AsyncQueueWorker(new SetTagsWorker(callback, *path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}
}

NAN_METHOD(addTags)
{
@autoreleasepool {
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString() || info[0].As<v8::String>()->Length() == 0) {
        Nan::ThrowTypeError("Path must be a non-empty string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() < 3 || !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    NSMutableSet *tags = [NSMutableSet new];

    v8::Local<v8::Array> t = info[1].As<v8::Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        v8::Local<v8::Value> v;
        if (!Nan::Get(t, i).ToLocal(&v)) {
            return;
        }
        if (!v->IsString()) {
            Nan::ThrowTypeError("Tags must be an array of strings");
            info.GetReturnValue().Set(Nan::Undefined());
            return;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(v))]];
    }

    Nan::Callback *callback = new Nan::Callback(info[2].As<v8::Function>());
    Nan::AsyncQueueWorker(new AddTagsWorker(callback, *path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}
}

NAN_METHOD(removeTags)
{
@autoreleasepool {
    Nan::HandleScope scope;

    if (info.Length() < 2) {
        Nan::ThrowTypeError("Wrong number of arguments");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[0]->IsString() || info[0].As<v8::String>()->Length() == 0) {
        Nan::ThrowTypeError("Path must be a non-empty string");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (!info[1]->IsArray()) {
        Nan::ThrowTypeError("Tags must be an array");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }
    if (info.Length() < 3 || !info[2]->IsFunction()) {
        Nan::ThrowTypeError("Callback must be a function");
        info.GetReturnValue().Set(Nan::Undefined());
        return;
    }

    Nan::Utf8String path(info[0]);
    NSMutableSet *tags = [NSMutableSet new];

    v8::Local<v8::Array> t = info[1].As<v8::Array>();
    for (uint32_t i = 0; i < t->Length(); i++) {
        v8::Local<v8::Value> v;
        if (!Nan::Get(t, i).ToLocal(&v)) {
            return;
        }
        if (!v->IsString()) {
            Nan::ThrowTypeError("Tags must be an array of strings");
            info.GetReturnValue().Set(Nan::Undefined());
            return;
        }

        [tags addObject:[NSString stringWithUTF8String:*(Nan::Utf8String(v))]];
    }

    Nan::Callback *callback = new Nan::Callback(info[2].As<v8::Function>());
    Nan::AsyncQueueWorker(new RemoveTagsWorker(callback,*path, tags));

    info.GetReturnValue().Set(Nan::Undefined());
}
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
