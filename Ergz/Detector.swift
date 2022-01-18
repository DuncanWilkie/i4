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
    var checksumMatched: UInt8
    var pixelData: [[UInt8]]
}

enum parseStage {
    case head
    case frameID
    case packetID
    case mode
    case nPixels
    case checksumMatched
    case pixelData
}

// translation of the wonderfully-named convert_packet() function from ADVACAM.
// colShiftNum is always 4 in their code, and for now we only need ToA/ToT tpx_mode.
func decodePixel(data: Data) -> (Int, Int, UInt16, UInt16, UInt8) {
    guard data.count == 6 else {
        print("\(data.count) bytes passed to processPixel; expected 6")
        return (0,0,0,0,0)
    }
    
    let data = [UInt8](data)
    let address: UInt16 = ((UInt16(data[0]) & 0x0f) << 12) | (UInt16(data[1]) << 4) | ((UInt16(data[2]) >> 4) & 0x0f)
    var toa: UInt16 = ((UInt16(data[2]) & 0x0f) << 10) | (UInt16(data[3]) << 2) | ((UInt16(data[4]) >> 6) & 0x03)
    var tot: UInt16 = ((UInt16(data[4]) & 0x3f) << 4) | ((UInt16(data[5]) >> 4) & 0x0f)
    var ftoa = (UInt8(data[5]) & 0x0f)
    let eoc = (address >> 9) & 0x7f
    let sp = (address >> 3) & 0x3f
    let pix = address & 0x07
    let x = Int(eoc) * 2 + (Int(pix) / 4)
    let y = Int(sp) * 4 + (Int(pix) % 4)
    
    toa = UInt16((toa >= 1 && toa < MAX_LUT_TOA) ? LUT_TOA[Int(toa)] : WRONG_LUT_TOA)
    ftoa = ftoa + UInt8(LUT_COLSHIFT4[Int(x)])
    tot = UInt16((tot >= 1 && tot < MAX_LUT_TOT) ? LUT_TOT[Int(tot)] : WRONG_LUT_TOT)
    
    return (x, y, tot, toa, ftoa)
}


class Detector: NSObject, StreamDelegate, ObservableObject {
    var session: EASession?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    
    
    let fm = DateFormatter() // expensive to create, so we don't do it on every update to measuring
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
    
    var lastMetadata: [Dictionary<String, AnyObject>] = []
    var preparingFrame: [(Int, Int, UInt16, UInt16, UInt8)] = []
    var badPackets: Int = 0
    var frameCount: Int = 0
    var preparingTpxPacket = TpxPacket(frameID: 0, packetID: 0, mode: 0, nPixels: 0, checksumMatched: 0, pixelData: [])
    var parseStage: parseStage = .head
    var subIndex = 0
    var pixelsRead = 0
    var lastFrameID = 0
    
    //state consumed by views
    @Published var isConnected: Bool = false
    @Published var lastFrame: [Int:(UInt16, UInt16, UInt8)] = [:]
    @Published var lastValue: Int = 0
    @Published var temperature: Double = 0
    @Published var stateDesc = "Initializing..."
    var bytesRead = 0
    
    
    static var ins = Detector()
    
    private override init() {
        fm.locale = Locale(identifier: "en_US_POSIX")
        fm.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        fm.timeZone = TimeZone(secondsFromGMT: 0)
        
        super.init() //NSObject init
        
        //register self as observer and enter connection and disconnection methods on receiving associated messages
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
                let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
                
                stream.read(temp, maxLength: 512)
                
                let buffer = Data(buffer: UnsafeMutableBufferPointer<UInt8>(start: temp, count: 512))
                temp.deallocate()
                
                //write raw stream data to file
                let defaultUrl = Scope.db.icloudURL!.appendingPathComponent("rawdump")
                DispatchQueue.global(qos: .utility).async {
                    if FileManager.default.fileExists(atPath: (self.url ?? defaultUrl).path) {
                        if let fileHandle = try? FileHandle(forWritingTo: (self.url ?? defaultUrl)) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(buffer)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? buffer.write(to: (self.url ?? defaultUrl), options: .atomicWrite)
                    }
                }
                
                bytesRead += buffer.count
                
                for byte in buffer { // parse the stream for TPX packets & frames, writing to all expecting sources as expected
                    
                    //if parseStage != .pixelData {print(parseStage)}
                    
                    switch (parseStage) {
                    case .head:
                        if byte == 0x14 {
                            parseStage = .frameID
                        }
                        
                    case .frameID:
                        if subIndex == 0 {
                            preparingTpxPacket.frameID = UInt16(byte)
                            subIndex += 1
                        } else if subIndex == 1 {
                            preparingTpxPacket.frameID |= UInt16(byte) << 8
                            //print("frameID: " + String(format: "%02X", preparingTpxPacket.frameID))
                            subIndex = 0
                            parseStage = .packetID
                        }
                        
                    case .packetID:
                        if subIndex == 0 {
                            preparingTpxPacket.packetID = UInt16(byte)
                            subIndex += 1
                        } else if subIndex == 1 {
                            preparingTpxPacket.packetID |= UInt16(byte) << 8
                            subIndex = 0
                            parseStage = .mode
                            //print("packetID: " + String(format: "%02X", preparingTpxPacket.packetID))
                        }
                        
                    case .mode:
                        preparingTpxPacket.mode = byte
                        parseStage = .nPixels
                        //print("mode: " + String(format: "%02X", preparingTpxPacket.mode))
                        
                    case .nPixels:
                        preparingTpxPacket.nPixels = byte
                        //print(String("nPixels: " + String(byte)))
                        if preparingTpxPacket.nPixels == 0 { // nullary packets are sent after frames end; write out & reset here
                            lastFrame = Dictionary(uniqueKeysWithValues: preparingFrame.map{($0 + 256 * ($1 - 1), ($2, $3, $4))})
                            
                            stateDesc = "Measuring: frame ID \(preparingTpxPacket.frameID) received"
                            lastValue = preparingFrame.reduce(0, {x, y in Int(x) + Int(y.2)})
                            //try? Scope.db.write(Measurement(date: Date(), exposure: 0.2, deposition: lastValue))
                            
                            parseStage = .head
                            preparingFrame = []
                        } else {
                            parseStage = .checksumMatched
                        }
                        
                    case .checksumMatched:
                        preparingTpxPacket.checksumMatched = byte
                        parseStage = .pixelData
                        
                    case .pixelData:
                        //print(pixelsRead) 
                        if subIndex == 0 {
                            preparingTpxPacket.pixelData.append([byte])
                            subIndex += 1
                        } else if subIndex < 5 {
                            preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1].append(byte)
                            subIndex += 1
                        }
                        
                        else {
                            preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1].append(byte)
                            let pixel = Data(preparingTpxPacket.pixelData[preparingTpxPacket.pixelData.count - 1])
                            //for i in pixel {print(String(format: "%02X", i))}
                            let decoded = decodePixel(data: pixel)
                            //print("decoded: \(decoded)")
                            pixelsRead += 1
                            subIndex = 0
                            preparingFrame.append(decoded)
                            //print(decoded.0, decoded.1)
                            if pixelsRead == preparingTpxPacket.nPixels { // reset packet parsing
                                pixelsRead = 0
                                parseStage = .head
                            }
                        }
                    }
                }
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
