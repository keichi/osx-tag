{
  "targets": [
    {
      "target_name": "osx_tag",
      "sources": [ "osx_tag.mm" ],
      "libraries": [ "Foundation.framework" ],
      "xcode_settings": { "CLANG_ENABLE_OBJC_ARC": "YES" },
      "include_dirs" : [
	    "<!(node -e \"require('nan')\")"
	  ]
    }
  ]
}
