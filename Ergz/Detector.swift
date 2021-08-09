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



struct TpxPacket: Equatable {
    var frameID: UInt16
    var packetID: UInt16
    var mode: UInt8
    var nPixels: UInt8
    var pixelData: [[UInt8]]
}

enum PacketStage {
    case frameID
    case packetID
    case mode
    case nPixels
    case pixelData
}



class Detector: NSObject, StreamDelegate, ObservableObject {
    var session: EASession?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    
    
    let fm = DateFormatter()
    var url: URL?
    var measuring = false {
        willSet {
            if isConnected && session?.outputStream?.hasSpaceAvailable ?? false {
                let startMeas = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                startMeas[0] = newValue ? 0xcb : 0xbc
                session?.outputStream?.write(startMeas, maxLength: 1)
                stateDesc = "Measuring: "
                if !measuring {
                    url = Scope.db.icloudURL?.appendingPathComponent(fm.string(from: Date()))
                }
            }
        }
    }
    var receiving = false
    
    var lastMetadata: [Dictionary<String, AnyObject>] = []
    var preparingFrame: [(Int, Int, Int, Float, Int)] = []
    var badPackets: Int = 0
    var frameCount: Int = 0
    var preparingTpxPacket = TpxPacket(frameID: 0, packetID: 0, mode: 0, nPixels: 0, pixelData: [])
    var packetStage: PacketStage = .frameID
    var subIndex = 0
    var pixelsRead = 0
    var lastFrameID = 0
    
    //state consumed by views
    @Published var isConnected: Bool = false
    @Published var lastFrame: [Float] = [Float](repeating: 0.0, count: 65536)
    @Published var lastValue: Double = 0
    @Published var temperature: Double = 0
    @Published var stateDesc = "Initializing..."
    var bytesRead = 0
    
    
    static var ins = Detector()
    
    private override init() {
        fm.locale = Locale(identifier: "en_US_POSIX")
        fm.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        fm.timeZone = TimeZone(secondsFromGMT: 0)
        
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
        
    }
    
    private func handlePacket(stream: InputStream) {
        print("packet received")
        if isConnected {
            while stream.hasBytesAvailable {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 128)
                
                stream.read(buffer, maxLength: 128)
                
                let temp = Data(buffer: UnsafeMutableBufferPointer<UInt8>(start: buffer, count: 128))
                
                //write raw stream data to file
                let defaultUrl = Scope.db.icloudURL!.appendingPathComponent("nildump")
                DispatchQueue.global(qos: .utility).async {
                    if FileManager.default.fileExists(atPath: (self.url ?? defaultUrl).path) {
                        if let fileHandle = try? FileHandle(forWritingTo: (self.url ?? defaultUrl)) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(temp)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? temp.write(to: (self.url ?? defaultUrl), options: .atomicWrite)
                    }
                }
                bytesRead += temp.count
                /*for i in temp { //parse the stream for TPX packets & frames, writing to all expecting sources as expected
                    if packetStage == .frameID {
                        if subIndex == 0 {
                            preparingTpxPacket.frameID = UInt16(i) << 8
                            subIndex += 1
                        } else if subIndex == 1 {
                            preparingTpxPacket.frameID |= UInt16(i)
                            subIndex = 0
                            packetStage = .packetID
                        }
                    } else if packetStage == .packetID {
                        if subIndex == 0 {
                            preparingTpxPacket.packetID = UInt16(i) << 8
                            subIndex += 1
                        } else if subIndex == 1{
                            preparingTpxPacket.packetID |= UInt16(i)
                            subIndex = 0
                            packetStage = .mode
                        }
                    } else if packetStage == .mode {
                        preparingTpxPacket.mode = i
                        packetStage = .nPixels
                    } else if packetStage == .nPixels {
                        preparingTpxPacket.nPixels = i
                        packetStage = .pixelData
                    } else if packetStage == .pixelData {
                        if subIndex == 0 {
                            preparingTpxPacket.pixelData.append([i])
                            subIndex += 1
                        }
                        if subIndex < 5 {
                            preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1].append(i)
                            subIndex += 1
                        }
                        if subIndex == 5 {
                            preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1].append(i)
                            let pixel = Data(preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1])
                            let decoded = decodePixel(data: pixel)
                            pixelsRead += 1
                            subIndex = 0
                            
                            if pixelsRead == preparingTpxPacket.nPixels {
                                print("packet \(preparingTpxPacket.packetID) read")
                                if preparingTpxPacket.frameID == lastFrameID {
                                    preparingFrame.append(decoded)
                                } else {
                                    lastFrameID += 1
                                    let active = Dictionary(uniqueKeysWithValues: preparingFrame.map{($0.0 + 256 * ($0.1 - 1), $0)})
                                    lastFrame = (1...65536).map { pixelIndex in
                                        if let _ = active[pixelIndex] {
                                            return active[pixelIndex]!.3
                                        } else {
                                            return 0.0
                                        }
                                    }
                                    stateDesc = "Measuring: frame ID \(lastFrameID) received"
                                    lastValue = preparingFrame.reduce(0.0, {x, y in x + Double(y.3)})
                                    try? Scope.db.write(Measurement(date: Date(), exposure: 0.2, deposition: lastValue))
                                    packetStage = .frameID
                                }
                            }
                        }
                        
                    }
                }*/
                
                buffer.deallocate()
                stateDesc = "Measuring: read \(bytesRead) bytes."
            }
        }
    }
    
    @objc private func onDisconnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        if changed.name == "iPix" {
            if self.isConnected {
                
                self.session = nil
                
                self.session?.inputStream?.close()
                
                self.isConnected = false
                self.stateDesc = "Waiting for detector..."
                self.bytesRead = 0
                
            }
        }
    }
}
