import Foundation
import Capacitor
import Photos
import Kingfisher

let KEY = "_CAP_IMAGE_CACHE_"
typealias JSObject = [String:Any]
@objc(ImageCachePlugin)
public class ImageCachePlugin: CAPPlugin {
    private var cache: NSDictionary?
    private var manager: KingfisherManager?
    public override func load() {
        let imageCache = ImageCache.default
        imageCache.diskStorage.config.pathExtension = "png"
        
        self.manager = KingfisherManager.init(downloader: ImageDownloader.default, cache: ImageCache.default)
    }

    @objc func get(_ call: CAPPluginCall) {
        let src = call.getString("src") ?? ""
        if(src.contains("http:") || src.contains("https:")){
            var path = src
            DispatchQueue.main.async {
                if (self.manager!.cache.isCached(forKey: src)) {
                   let systemPath = self.manager!.cache.cachePath(forKey: src)
                   path = CAPFileManager.getPortablePath(host: self.bridge!.getLocalUrl(), uri: URL.init(string: systemPath))!;
               } else {
                   self.saveImage(src: path)
               }
               
              var obj = JSObject()
              obj["value"] = path
              call.resolve(obj)
            }
        }else{
            var obj = JSObject()
            obj["value"] = src;
            call.resolve(obj)
        }

    }

    @objc func hasItem(_ call: CAPPluginCall) {
        let src = call.getString("src") ?? ""
        let exists = self.manager!.cache.isCached(forKey: src)
        DispatchQueue.main.async {
                       var obj = JSObject()
                       obj["value"] = exists
                       call.resolve(obj)
                   }
    }

    @objc func clearItem(_ call: CAPPluginCall) {
        let src = call.getString("src") ?? ""
        self.manager!.cache.removeImage(forKey: src, processorIdentifier: "", fromMemory: true, fromDisk: true, callbackQueue: .untouch) {
            DispatchQueue.main.async {
                call.resolve()
            }
        }
    }


    @objc func clear(_ call: CAPPluginCall) {
        self.manager!.cache.clearDiskCache()
        self.manager!.cache.clearMemoryCache()
    }
    
    @objc func saveImage(_ call: CAPPluginCall) {
        let src = call.getString("src") ?? ""
        if(src.contains("http:") || src.contains("https:")) {
            let url = URL.init(string: src )
            self.manager!.downloader.downloadImage(with: url!, options: nil) { (result) in
                switch result {
                case .success(let value):
                    self.manager!.cache.store(value.image, forKey: src, options: KingfisherParsedOptionsInfo([.cacheSerializer(FormatIndicatedCacheSerializer.png)]),
                    toDisk: true,completionHandler: { (result) in
                        call.resolve()
                    })
                case .failure(let error):
                    call.reject(error.localizedDescription)
                }
            }
        } else {
            call.reject("src must use an http or https scheme")
        }

    }
    
    private func saveImage(src: String) {
        if(src.contains("http:") || src.contains("https:")) {
            let url = URL.init(string: src )
            self.manager!.downloader.downloadImage(with: url!, options: nil) { (result) in
                switch result {
                case .success(let value):
                    self.manager!.cache.store(value.image, forKey: src, options: KingfisherParsedOptionsInfo([.cacheSerializer(FormatIndicatedCacheSerializer.png)]),
                    toDisk: true,completionHandler: { (result) in
                        print(result)
                    })
                case .failure(let error):
                    print("Cannot save image", error)
                }
            }
        } else {
             print("Cannot save image","src must use an http or https scheme")
        }
    }
    
    func checkAuthorization(allowed: @escaping () -> Void, notAllowed: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == PHAuthorizationStatus.authorized {
            allowed()
        } else {
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                if newStatus == PHAuthorizationStatus.authorized {
                    allowed()
                } else {
                    notAllowed()
                }
            })
        }
    }
}
