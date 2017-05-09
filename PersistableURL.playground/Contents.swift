import UIKit

/*:

 > UPDATE: I'm not sure, but this whole idea of "persistable URLs" may be misguided. Why? This is the purpose of [Cocoa file bookmarks](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html#//apple_ref/doc/uid/TP40010672-CH3-SW10), a piece of API that lets you convert path-based URLs into data blobs that are valid across launches. Although bookmarks are less readable than URLs, they are built in to Cocoa.


 # iOS Directories and Persistable URLs

 This playground provides conveniences to help manage two problems with using the filesystem for persistence in iOS apps -- helping you know where to put your files, and accessing your files across separate launches of your app.

 ## Standard Directory Provider

 The first problem is boring: it's hard to know _which directory_ you should save your files to. iOS defines a number of "standard directories", which differ in a number of ways:

 1. whether the user can modify their contents directly
 2. whether they will be backed up to iTunes or iCloud
 3. whether iOS guarantees it will preserve their contents across launches of your app, or how aggressively it will try to erase their contents.
 
 All of the policy is described in [Apple's File System Programming Guide](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html), notably in the sections _Where You Should Put Your App's Files_ and in _iOS Standard Directories_. But it's still confusing.
 
 The type `StandardDirectoryProvider` has static variables that provide URLs to all the key locations, with copious plain English comments describing what they're good for. It provides the storage locations, as well as the read-only location of the main bundle's resources directory. (Access to framework bundles is not supported.)
 
 ## Persistable URL
 

 The second problem is how to persist these URLs so they remain valid across launches.  Normal path-based URLs use the "file" scheme and contain an absolute file system path. But the absolute paths of all these locations _can change across launches of your app_.
 
 So if you are using the filesystem in order to save a file before your app quits and then load the file when it's running again, then you cannot save the location of a file by saving the path-based URL that points to the file.

 So to remember how to find a file, you need to remember the _semantic prefix_ of its path (caches, application support, documents, bundle, etc.), and the suffix of its path. The type PersistableURL does that. Internally, it uses a URL with custom schemes corresponding to the various standard directories. Alternatively, you can just use plain `URL` values with those custom schemes.

 */

//: ### DirectoryProvider

/**

 Convenience wrapper for important iOS filesystem directories.

 Provides docs and access to important directoress.

 Note: These absolute URLs change between launches! So if you want to persist to the filesystem between launches, it does not suffice to save the absolute URL, since it will be invalid on the next run. You need to remember how you formed the root of the URL, and then the suffix of i

 https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html

 */
struct StandardDirectoryProvider
{
  // MARK: places to lookup data

  /// Bundle Resources. Readonly, installed at build time. This is the root containing everything that's installed by Xcode as a "resource"
  static let mainBundleResourceURL = Bundle.main.resourceURL!

  // MARK: places to store data

  /// Documents. Backed up by iTunes & iCloud. Read/writeable by the user via iTunes File Sharing. This is where to store data you want the user to be able directly to delete, add, and read.
  static let documentDirectory = StandardDirectoryProvider.urlInUserDomain(for: .documentDirectory)!

  /// Application Support. Backed up by iTunes and iCloud. Stored reliably by the OS. This is almost certainly where the app should store data on the filesystem.
  static let applicationSupportDirectory = StandardDirectoryProvider.urlInUserDomain(for: .applicationSupportDirectory)!

  /// Caches. Not backed up by iTunes and iCloud. May sometimes be deleted by the OS between launches (!). This is where you should store data which you would like to have persisted across runs, but which you can regenerate without too much pain, and which you don't want to be stored in backups.
  static let cachesDirectory = StandardDirectoryProvider.urlInUserDomain(for: .cachesDirectory)!

  /// Creates a unique temporary directory. Most likely to be deleted by the OS between runs. This is where to put truly temporary files, which you probably should delete yourself when you are done using them within a single run of the application
  static func createTemporaryDirectory() -> URL? {
    return try? FileManager.default.url(for: .itemReplacementDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: StandardDirectoryProvider.applicationDirectory,
                                        create: true)
  }

  // MARK: places used less often

  /// Bundle. Readonly. This is the bundle itself, which includes not only the bundle's resources, but also the bundle compiled code, embedded frameworks, etc.. You probably don't need to look in here.
  private static let mainBundleURL = Bundle.main.bundleURL

  /// Inbox. Backed up by iTunes & iCloud. This is a where other apps, like Mail, put files for your app to process, and has strange access restrictions.
  static let documentsInboxDirectory = StandardDirectoryProvider.urlInUserDomain(for: .documentDirectory)!.appendingPathComponent("Inbox")


  /// Library directory. Backuped by iTunes & iCloud.
  private static let libraryDirectory = StandardDirectoryProvider.urlInUserDomain(for: .libraryDirectory)!

  /// Application. Backed up by iTunes and iCloud.
  private static let applicationDirectory = StandardDirectoryProvider.urlInUserDomain(for: .applicationDirectory)!

  private static func urlInUserDomain(for searchPath:FileManager.SearchPathDirectory) -> URL? {
    return try? FileManager.default.url(for: searchPath, in: .userDomainMask, appropriateFor: nil, create: false)
  }
}

//: ### Persistable URL helpers

/// Standard directories in iOS
enum StandardDirectory : String  {
  case bundleResource = "app-bundleResource"
  case documents = "app-documents"
  case applicationSupport = "app-appSupport"
  case caches = "app-caches"
}

private func isPersistableURL(_ u:URL) -> Bool {
  if
    let components = URLComponents(url: u, resolvingAgainstBaseURL: false),
    let scheme = components.scheme,
    let _ = StandardDirectory(rawValue: scheme)
  {
    return true
  }
  else {
    return false
  }
}

private func persistableURL(forStandardDirectory d:StandardDirectory) -> URL
{
  var components = URLComponents()
  components.scheme = d.rawValue
  return components.url!
}

/**
 Returns a file url for a persistent URL
 */
private func fileURL(forPersistableURL u:URL) -> URL? {
  guard
    let components = URLComponents(url: u, resolvingAgainstBaseURL: false),
    let scheme = components.scheme,
    let root = StandardDirectory(rawValue: scheme)
    else { return nil }

  switch root {
  case .bundleResource:
    return StandardDirectoryProvider.mainBundleResourceURL.appendingPathComponent(components.path)
  case .documents:
    return StandardDirectoryProvider.documentDirectory.appendingPathComponent(components.path)
  case .applicationSupport:
    return StandardDirectoryProvider.applicationSupportDirectory.appendingPathComponent(components.path)
  case .caches:
    return StandardDirectoryProvider.cachesDirectory.appendingPathComponent(components.path)
  }
}

private func persistableURL(forFileURL fileURL:URL) -> URL? {
  let s = fileURL.absoluteString

  let path:String
  if s.hasPrefix(StandardDirectoryProvider.mainBundleResourceURL.absoluteString) {
    path = s.substring(from: StandardDirectoryProvider.mainBundleResourceURL.absoluteString.endIndex)
    return persistableURL(forStandardDirectory: .bundleResource).appendingPathComponent(path)
  }
  else if s.hasPrefix(StandardDirectoryProvider.applicationSupportDirectory.absoluteString) {
    path = s.substring(from: StandardDirectoryProvider.applicationSupportDirectory.absoluteString.endIndex)
    return persistableURL(forStandardDirectory: .applicationSupport).appendingPathComponent(path)
  }
  else if s.hasPrefix(StandardDirectoryProvider.cachesDirectory.absoluteString) {
    path = s.substring(from: StandardDirectoryProvider.cachesDirectory.absoluteString.endIndex)
    return persistableURL(forStandardDirectory: .caches).appendingPathComponent(path)
  }
  else if s.hasPrefix(StandardDirectoryProvider.documentDirectory.absoluteString) {
    path = s.substring(from: StandardDirectoryProvider.documentDirectory.absoluteString.endIndex)
    return persistableURL(forStandardDirectory: .documents).appendingPathComponent(path)
  }

  return nil
}

/*:

 #### URL extension for converting path-based file URLs to/from persistable URLs
 
 Using this extension, a persistable URL has type `URL`, just like a file-based URL, or an
 HTTP URL.
 
 This makes it easier to handle, since you can inspect its string representation easily and add path components easily. It also makes it less safe to handle, since you might mistakenly pass it to normal API that needs a file URL.

 */

extension URL
{
  /// Returns receiver as a file URL, converting from a persistable URL if needed
  var asFileURL:URL? {
    if isPersistableURL(self) {
      return fileURL(forPersistableURL: self)
    }
    else  {
      if self.isFileURL
      {
        return self
      }
      else {
        return nil
      }
    }
  }

  /// Returns receiver as a persistable URL, converting from a file URL if needed
  var asPersistableURL:URL? {
    if isPersistableURL(self) {
      return self
    }
    else {
      return persistableURL(forFileURL: self)
    }
  }
}


/*:

 #### Type wrapper for a Persistable URL

 This type-wrapper for a persistable URL makes them safer to handle, since the type system will prevent you from mistakenly passing a persistable URL to API expecting a normal URL.

 */

/**
 A persistable URL represents a resources located in one of the standard iOS directories, but in a way which is stable across app launches.

 It can be initialized from a normal path-based URL, and it can vend a normal path-based URL. Internally, however, it holds a URL with a custom scheme that encodes the standard iOS directory
 */
struct PersistableURL
{
  /// Raw persistable URL, which cannot be used to access files.

  var url:URL

  /** Create a persistable URL from a path-based URL

   - parameter fileURL: a path-based URL. That is, a URL of the form "file:///foo/bar/baz"

   Fails if the URL is not a fileURL pointing to one of the standard directories, where the standard directories are caches, documents, application support, and main bundle resources.
   */
  init?(fileURL u:URL) {
    if let pu = persistableURL(forFileURL: u) {
      self.url = pu
    }
    else {
      return nil
    }
  }

  /// Initialize a persistable URL representing the root of one of the standard directories
  init(forStandardDirectory d:StandardDirectory) {
    self.url = persistableURL(forStandardDirectory: d)
  }

  /** Returns a normal path-based URL.

   This is a URL that can be used to actually access the file, but is not valid across launches.

   */
  var asFileURL : URL {
    return fileURL(forPersistableURL: self.url)!
  }
}


//: ### Examples of use

//: Define a persistable URL for a resource "foo" in the bundle resources
let pfoo = persistableURL(forStandardDirectory: .bundleResource).appendingPathComponent("foo")

//: Convert it to a fileURL
pfoo.asFileURL

//: Convert it to a fileURL, then back to a persistable URL
pfoo.asFileURL?.asPersistableURL


let f1 = fileURL(forPersistableURL: pfoo )!
let f2 = StandardDirectoryProvider.mainBundleResourceURL.appendingPathComponent("foo")

f1 == f2
print(f1)
print(f2)

persistableURL(forFileURL: f1)

persistableURL(forFileURL:
  fileURL(forPersistableURL:
    persistableURL(forStandardDirectory: .bundleResource).appendingPathComponent("foo").appendingPathComponent("bar"))!)


let cs = URLComponents(url: StandardDirectoryProvider.mainBundleResourceURL, resolvingAgainstBaseURL: false)!
cs.scheme!
cs.debugDescription
cs.description
cs.fragment
cs.host
cs.password
cs.path
cs.percentEncodedFragment
cs.percentEncodedHost
cs.percentEncodedPassword
cs.percentEncodedPath
cs.percentEncodedQuery
cs.percentEncodedUser
cs.port
cs.query
cs.queryItems
cs.rangeOfFragment
cs.string
cs.url
cs.user



