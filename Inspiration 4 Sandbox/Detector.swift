//
//  Device.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/16/21.
//

import Foundation
import ExternalAccessory
import Compression

//Watches for EAAccessory connection notifications in the default notification center, passing to fns that check if
//inserted or ejected object is the Timepix, beginning or stopping stream reading actions if it is.
//Dumps of the binary read from the Timepix are stored in the application support directory in 1Mb chunks in
//the file ~/stream.

//I really wish this could be a monadic function. Apple hurts my soul with @objc and addObserver requiring object contexts...
//We have an *object that exclusively manages global state*. I shouldn't have to stress how uncomfortable that is
//from a functional programming perspective. Singletons are unequivocally an antipattern...




class Detector: NSObject, StreamDelegate, ObservableObject {
    var session: EASession?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    var inStream: InputStream? = nil //optional because I can't initialize it in initializer--only on passing to onConnection
    
    //quite proud of this nonstandard semaphore. We need to block deinitialization when any
    //number of threads are running, but if we increment a semaphore for each thread
    //and decrement it on completion, this does the opposite: blocks on 0 threads, passes on many.
    //So, we listen for changes to a thread-counting variable (with some added syntax to let it be
    //safely mutateable by multiple threads) and increment the actual Semaphore when the thread
    //count will be set to zero, decrementing (locking) it otherwise. Is the multithread mutation safe?
    var deinitLock: DispatchSemaphore = DispatchSemaphore(value: 1)
    var threadCount: Int = 0 {
        willSet(new) {
            if new == 0 {
                deinitLock.signal() //tells future calls to wait() that no threads are running
            } else if new == 1 && threadCount == 0 {
                deinitLock.wait() //tells future calls to wait() that threads are running
            }
        }
    }
    
    var lastMetadata: [Dictionary<String, AnyObject>] = []
    var preparingFrame: [[Float]] = []
    var badPackets: Int = 0
    var frameCount: Int = 0
    
    //state consumed by views
    @Published var isConnected: Bool = false
    @Published var lastFrame: [[Float]] = []
    @Published var lastValue: Double = 0
    @Published var temperature: Double = 0
    
    
    static var ins = Detector()
    
    private override init() {
        self.manager.registerForLocalNotifications()
        
        super.init() //NSObject init
        
        //register self as observer and enter connection and disconnection methods on recieving associated messages
        nc.addObserver(self, selector: #selector(onConnection), name: Notification.Name("EAAccessoryDidConnect"), object: nil)
        nc.addObserver(self, selector: #selector(onDisconnection), name: Notification.Name("EAAccessoryDidDisconnect"), object: nil)
    }
    
    @objc private func onConnection() {
        DispatchQueue.global(qos: .utility).async {
            let accessories = self.manager.connectedAccessories
            
            for i in accessories {
                if i.name == "Timepix" {
                    self.session = EASession(accessory: i, forProtocol: "space.chancellor.test") //TODO: fix protocol
                    self.isConnected = true
                    break
                }
            }
            
            if !self.isConnected { //it's some other accessory
                return
            }
            
            guard let _ = self.session else { //EASession returns nil if error
                print("unsupported protocol/communication warning: line \(#line) in \(#file)")
                return
            }
            
            self.inStream = self.session?.inputStream
            let input = self.inStream!
            
            input.delegate = self
            input.schedule(in: .current, forMode: .default)
            input.open()
        }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        threadCount += 1
        
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            handlePacket(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            break
        case Stream.Event.errorOccurred:
            print("Stream Error Occured: line \(#line) in \(#file)")
        default:
            print("Unrecognized stream event")
        }
        
        threadCount -= 1
    }
    
    private func handlePacket(stream: InputStream) {
        if isConnected {
            DispatchQueue.global(qos: .utility).async {
                while stream.hasBytesAvailable {
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
                    
                    stream.read(buffer, maxLength: 65_536)
                    
                    var packet = Data(buffer: UnsafeMutableBufferPointer<UInt8>(start: buffer, count: 65_536))
                    let header = packet.remove(at: 0)
                    
                    switch (header) {
                    case  0x00:
                        //handle metadata packet
                        //should write out lastMetadata + lastFrame to iCloud archive,
                        //then replace the first with new metadata and clear the second.
                        let container = FileManager.default.url(forUbiquityContainerIdentifier: nil)!.appendingPathComponent("Documents")
                        
                        if !FileManager.default.fileExists(atPath: container.path, isDirectory: nil) {
                            do {
                                try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true, attributes: nil)
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                        
                        let dir = container.appendingPathComponent("dumps")
                        do {
                            try (self.lastMetadata as NSArray).write(to: dir.appendingPathComponent("metadata_\(self.frameCount)"))
                            try (self.lastFrame as NSArray).write(to: dir.appendingPathComponent("frame_\(self.frameCount)"))
                        } catch {
                            print(error.localizedDescription)
                        }
                        self.frameCount += 1
                    case 0x01:
                        //handle a frame byte
                        //should test this to make sure .chunked extension of Data works
                        self.preparingFrame += packet.chunked(into: 4).map { pixel in
                            return Float(bitPattern: UInt32(littleEndian: Data(pixel).withUnsafeBytes { $0.pointee }))
                        }.chunked(into: 256)
                    default:
                        self.badPackets += 1
                    }
                }
            }
        }
    }
    
    @objc private func onDisconnection() {
        DispatchQueue.global(qos: .utility).async {
            let accessories = self.manager.connectedAccessories
            
            for i in accessories {
                if i.name == "Timepix" {
                    if self.isConnected {
                        self.deinitLock.wait()
                        
                        self.session = nil
                        
                        self.inStream!.close()
                        self.inStream = nil
                        
                        self.isConnected = false
                        
                        break
                    }
                }
            }
        }
    }
}
