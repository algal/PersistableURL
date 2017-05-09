# Persistable URL

This is an experiment in iOS filesystem persistence.

You want to save your app data in the filesystem because a lot of your app's data are files, and that's what filesystems are good for. That much is clear.

But how do you remember where those files are? The usual way would be to remember a String containing an absolute path to the file or, as Cocoa recommends, a path-based file URL containing an absolute path to the file. A "path-based file URL" is just a URL of the form "file:///absolute/path/to/your/file".

But no, child, you cannot! From time to time iOS will change the absolute path of your app's sandbox, and then all your absolute paths and path-based file URLs break.

So what your app really needs to remember is the _semantic prefix_ of the path (which will be one of a few standard directories like caches, user documents, application support, or bundle resources) as well as the actual custom suffix path to your resource. 

This is a less convenient thing to keep track of. Do you define a struct containing a custom enum for the prefix and a String for the path suffix? Seems less handy than a plain old URL.

What to do? Behold, persistable URLs!

A "persistable URL" is just a URL which instead of using the "file" scheme and an absolute path, uses a scheme that specifies the standard iOS directory and the relative path from there. So to track that your file is in "foo/bar" off of the Caches directory, you can just use the URL "app-caches:foo/bar".

This playground provides a URL extension to freely convert between ordinary path-based file URLs and these persistable URLs.

Is this all a good idea? I'm not sure. It may be poor substitute for Cocoa's file bookmarks. Or maybe it's better in some cases.
