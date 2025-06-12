//
//  DeviceDelegate.swift
//  iPhoneVideoDownloader
//
//  Created by Davide Sicignani on 11/06/25.
//


import Foundation
import ImageCaptureCore
import UniformTypeIdentifiers

class DeviceDelegate: NSObject, ObservableObject, ICDeviceBrowserDelegate, ICDeviceDelegate, ICCameraDeviceDelegate, ICCameraDeviceDownloadDelegate {
    @Published var videos: [ICCameraItem] = []
    @Published var connectedDeviceName: String?
    private var camera: ICCameraDevice?
    private let browser = ICDeviceBrowser()

    override init() {
        super.init()
        browser.delegate = self
        browser.browsedDeviceTypeMask = ICDeviceTypeMask.camera
        browser.start()
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
        print("[cameraDevice]: Items added")
        DispatchQueue.main.async {
            let newVideo = items.filter { $0.uti == UTType.movie.identifier || $0.uti == UTType.mpeg4Movie.identifier }
            self.videos.append(contentsOf: newVideo)
            print("Vides count", self.videos.count)
        }
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {
        // print("[cameraDevice]: Items removed")
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {
        // print("[cameraDevice]: Items renamed")
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: (any Error)?) {
        // print("cameraDevice")
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable : Any]?, for item: ICCameraItem, error: (any Error)?) {
        // print("cameraDevice")
    }
    
    func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {
        // print("cameraDeviceDidChangeCapability")
    }
    
    func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {
        // print("cameraDevice")
    }
    
    func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        // print("deviceDidBecomeReady")
    }
    
    func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {
        // print("cameraDeviceDidRemoveAccessRestriction")
    }
    
    func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {
        // print("cameraDeviceDidEnableAccessRestriction")
    }
    
    func didRemove(_ device: ICDevice) {
        
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        print("Device added: \(device.name ?? "unknown")")
        
        device.delegate = self
        DispatchQueue.main.async {
            self.connectedDeviceName = device.name
        }
        device.requestOpenSession()
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        print("Device removed: \(device.name ?? "unknown")")
        
        if let cam = camera, cam == device {
            camera = nil
            DispatchQueue.main.async { self.videos = [] }
            self.connectedDeviceName = nil
        }
    }

    @objc func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        guard let cam = device as? ICCameraDevice else { return }
        camera = cam
        camera?.delegate = self
    }
    
    // Required by ICDeviceDelegate
    func deviceDidBecomeReady(_ device: ICDevice) {
        print("[deviceDidBecomeReady]: Device is connected and Ready!")
        // Now safe to get contents
        if let cam = device as? ICCameraDevice {
            self.camera = cam
            self.camera?.delegate = self
            // At this point, `cameraDevice(_:didAdd:)` will be called as items become available
            // Nothing more needed
        }
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        // You can leave this empty or handle errors if needed
    }

    func device(_ device: ICDevice, didChangeName name: String) {
        // Optional: handle name change
    }

    func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem], moreComing: Bool) {
        // cameraDevice
    }

    func download(_ item: ICCameraItem, to url: URL, completion: @escaping (Error?) -> Void) {
        guard let cam = camera else { return completion(NSError(domain: "NoDevice", code: 1)) }
        cam.requestDownloadFile(item as! ICCameraFile, options: [ICDownloadOption.downloadsDirectoryURL: url.deletingLastPathComponent()],
                                downloadDelegate: self,
                                didDownloadSelector: #selector(didDownload(_:error:options:context:)),
                                contextInfo: Unmanaged.passRetained(DownloadContext(item, url, completion)).toOpaque())
    }

    @objc func didDownload(_ item: ICCameraItem, error: Error?, options: [String: Any], context: UnsafeMutableRawPointer) {
        let ctx = Unmanaged<DownloadContext>.fromOpaque(context).takeRetainedValue()
        ctx.completion(error)
    }

    func downloadAll(to directory: URL, progress: @escaping (Int, Int) -> Void, completion: @escaping ([Error?]) -> Void) {
        guard !videos.isEmpty else { completion([]); return }
        var errors: [Error?] = Array(repeating: nil, count: videos.count)
        let group = DispatchGroup()

        for (index, video) in videos.enumerated() {
            group.enter()
            let target = directory.appendingPathComponent(video.name ?? "video_\(index).mov")
            download(video, to: target) { err in
                errors[index] = err
                DispatchQueue.main.async { progress(index+1, self.videos.count) }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(errors) }
    }

    private class DownloadContext {
        let item: ICCameraItem; let url: URL; let completion: (Error?)->Void
        init(_ item: ICCameraItem, _ url: URL, _ comp: @escaping (Error?)->Void) {
            self.item = item; self.url = url; self.completion = comp
        }
    }
}
