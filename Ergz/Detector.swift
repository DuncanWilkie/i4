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
    
    
    
    var url: URL?
    var measuring = false {
        willSet {
            print("write attempted1")
            if isConnected && session?.outputStream?.hasSpaceAvailable ?? false {
                print("write attempted")
                let startMeas = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                startMeas[0] = newValue ? 0xcb : 0xbc
                session?.outputStream?.write(startMeas, maxLength: 1)
            }
        }
    }
    var receiving = false
    
    var lastMetadata: [Dictionary<String, AnyObject>] = []
    var preparingFrame: [[Float]] = []
    var badPackets: Int = 0
    var frameCount: Int = 0
    
    //state consumed by views
    @Published var isConnected: Bool = false
    @Published var lastFrame: [[Float]] = []
    @Published var lastValue: Double = 0
    @Published var temperature: Double = 0
    @Published var stateDesc = "Initializing..."
    
    
    static var ins = Detector()
    
    private override init() {
        url = Scope.db.icloudURL?.appendingPathComponent("streamdump")
        super.init() //NSObject init
        
        //register self as observer and enter connection and disconnection methods on recieving associated messages
        nc.addObserver(self, selector: #selector(self.onConnection(_:)), name: .EAAccessoryDidConnect, object: nil)
        nc.addObserver(self, selector: #selector(self.onDisconnection(_:)), name: .EAAccessoryDidDisconnect, object: nil)
        //actually receive EA.* messages thru NC in this scope
        self.manager.registerForLocalNotifications()
        
        self.stateDesc = "Waiting for detector..."
    }
    
    
    
    
    
    @objc private func onConnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        
        if  changed.name == "iPix" {
            self.session = EASession(accessory: changed, forProtocol: "space.chancellor.test")
            self.isConnected = true
            self.stateDesc = "Connected: ready to measure"
        } else {
            return
        }
        
        guard let _ = self.session else { //EASession returns nil if error
            print("unsupported protocol/communication warning: line \(#line) in \(#file)")
            return
        }
        
        
        let input =  self.session!.inputStream
        let output = self.session!.outputStream!
        input?.delegate = self
        input?.schedule(in: .current, forMode: .common)
        input?.open()
        
        output.delegate = self
        output.schedule(in: .current, forMode: .common)
        output.open()
        
        
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        receiving = true
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            self.handlePacket(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            break
        case Stream.Event.errorOccurred:
            print("Stream Error Occured: line \(#line) in \(#file)")
        default:
            print("Unrecognized stream event")
        }
        receiving = false
    }
    
    private func handlePacket(stream: InputStream) {
        print("packet received")
        if isConnected {
            while stream.hasBytesAvailable {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 128)
                
                stream.read(buffer, maxLength: 128)
                
                let temp = Data(buffer: UnsafeMutableBufferPointer<UInt8>(start: buffer, count: 128))
                
                //write raw stream data to file
               DispatchQueue.global(qos: .utility).async {
                    if FileManager.default.fileExists(atPath: self.url!.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: self.url!) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(temp)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? temp.write(to: self.url!, options: .atomicWrite)
                    }
                }
                
                //todo: parse stream here
                
                buffer.deallocate()
            }
        }
        
    }
    
    @objc private func onDisconnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        if changed.name == "iPix" {
            if self.isConnected {
                
                self.session = nil
                
                self.session?.inputStream!.close()
                
                self.isConnected = false
                self.stateDesc = "Waiting for detector..."
                
            }
        }
        
    }
}


