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

struct PixelData: Codable {
    var tot: UInt16
    var toa: UInt16
    var ftoa: UInt8
}

struct PixelCoords: Codable, Hashable {
    var x: Int
    var y: Int
}

struct Pixel {
    var coords: PixelCoords
    var data: PixelData
}

typealias Frame = [PixelCoords : PixelData] // associate (x,y) for x,y <- 1...256 with pixel data.
typealias CalibratedFrame = [PixelCoords : Double]

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
func decodePixel(data: Data) -> Pixel { // byte-for-byte identical to Advacam's Python script on several inputs.
    guard data.count == 6 else {
        print("\(data.count) bytes passed to processPixel; expected 6")
        return Pixel(coords: PixelCoords(x: 0, y: 0), data: PixelData(tot: 0, toa: 0, ftoa: 0))
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
    
    return Pixel(coords: PixelCoords(x: x, y: y), data: PixelData(tot: tot, toa: toa, ftoa: ftoa))
}

func calibratedFrame(uncalibrated: Frame, detectorID: String, config: Config) -> CalibratedFrame { // TODO: Validate this conversion
    var calibrated: CalibratedFrame = [:]
    for (coords, pixData) in uncalibrated {
        let tot = Double(Float16(bitPattern: pixData.tot))
        let pixcal = config.detectors.first { $0.id == detectorID }!.cal[coords]!
        if pixcal.a == 0 {
            let energy =  pixcal.c / (pixcal.b - tot) + pixcal.t
            calibrated[coords] = Double(energy)
        } else {
            let b = tot + pixcal.a * pixcal.t - pixcal.b
            let sq = pow(pixcal.b - pixcal.a * pixcal.t - tot, 2)
            let ac = pixcal.a * (tot * pixcal.t - pixcal.b * pixcal.t - pixcal.c)
            let energy = (b + sqrt(sq - 4 * ac)) / (2 * pixcal.a) // calculation following doi:10.1088/1742-6596/396/2/022023
            // notably, the inversion of the TOT(Energy) formula given is not unique; I've taken the positive branch here.
            calibrated[coords] = Double(energy)
        }
    }
    
    return calibrated
    
}

class Detector: NSObject, StreamDelegate, ObservableObject { // TODO: Incorporate detector ID from stream in stateDesc when connected but not measuring
    var store: Store
    var config: Config
    var session: EASession?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    // Validation so far: the parsing as appearing below produces identical results to ADVACAM's Python script
    // that serves the same purpose.
    
    var url: URL?
    var measuring = false { // TODO: Make sure property wrapper not needed to set this from MeasurementSettingsView
        willSet {
            print(isConnected)
            stateDesc = newValue ? "Measuring: "  : (isConnected ? "Connected: ready to measure" : "Disconnected.")
            if isConnected && session?.outputStream?.hasSpaceAvailable ?? false {
                let startMeas = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                startMeas[0] = newValue ? 0xcb : 0xbc
                session?.outputStream?.write(startMeas, maxLength: 1)
            }
        }
    }
    
    var lastMetadata: [Dictionary<String, AnyObject>] = []
    var preparingFrame: Frame = [:]
    var badPackets: Int = 0
    var frameCount: Int = 0
    var preparingTpxPacket = TpxPacket(frameID: 0, packetID: 0, mode: 0, nPixels: 0, checksumMatched: 0, pixelData: [])
    var parseStage: parseStage = .head
    var subIndex = 0
    var pixelsRead = 0
    var lastFrameID = 0
    
    
    //state consumed by views
    @Published var isConnected: Bool = false
    @Published var lastFrame: CalibratedFrame = [:]
    @Published var lastValue: Double = 0.0
    var exposure: Double {
        guard let result = Double(exposure_str) else {
            print("Exposure string \(exposure_str) not convertible to Double")
            return 0.2
        }
        
        return result
    }
    
    @Published var exposure_str: String = "0.2"
    
    @Published var stateDesc = "Initializing..."
    var bytesRead = 0
    
    
    
    init(store: Store, config: Config) {
        self.store = store
        self.config = config
        
        
        super.init() //NSObject init
        
        //register self as observer and enter connection and disconnection methods on receiving associated messages
        nc.addObserver(self, selector: #selector(self.onConnection(_:)), name: .EAAccessoryDidConnect, object: nil)
        nc.addObserver(self, selector: #selector(self.onDisconnection(_:)), name: .EAAccessoryDidDisconnect, object: nil)
        //actually receive EA.* messages thru NC in this Store
        self.manager.registerForLocalNotifications()
        
        self.stateDesc = "Disconnected."
    }
    
    
    @objc private func onConnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        print(changed.name)
        
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
        
        
        let input =  self.session!.inputStream! // If we get here and these are nil, there's something really wrong with the detector.
        let output = self.session!.outputStream!
        input.delegate = self
        input.schedule(in: .current, forMode: .common)
        input.open()
        
        output.delegate = self
        output.schedule(in: .current, forMode: .common)
        output.open()
        
        
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print(eventCode)
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            self.handlePacket(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            break
        case Stream.Event.errorOccurred:
            print("Stream Error \(eventCode) Occured: line \(#line) in \(#file)")
        default:
            print("Unrecognized stream event")
        }
    }
    
    private func handlePacket(stream: InputStream) {
        if isConnected {
            while stream.hasBytesAvailable {
                let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
                
                stream.read(temp, maxLength: 512)
                
                let buffer = Data(buffer: UnsafeMutableBufferPointer<UInt8>(start: temp, count: 512))
                temp.deallocate()
                
                bytesRead += buffer.count
                
                for byte in buffer { // parse the stream for TPX packets & frames, writing to all expecting sources
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
                        }
                        
                    case .mode:
                        preparingTpxPacket.mode = byte
                        parseStage = .nPixels
                        
                    case .nPixels:
                        preparingTpxPacket.nPixels = byte
                        if preparingTpxPacket.nPixels == 0 { // nullary packets are sent after frame's end; write out & reset here
                            // TODO: Should this be asynchronous? How long does it take to add a FrameRecord to the database?
                            lastFrame = calibratedFrame(uncalibrated: preparingFrame, detectorID: config.selected, config: config)
                            
                            stateDesc = "Measuring: frame ID \(preparingTpxPacket.frameID) received"
                            let totalKeV = lastFrame.reduce(0.0, {x, y in x + y.1})
                            let volume = 2 * 0.005 // cm^3
                            let density = 2.3212 // g/cm^3
                            let mass = volume * density // g
                            let totalGy = totalKeV / (mass * 6.24e12) // calculation following doi:10.1088/1742-6596/396/2/022023
                            try? store.write(Measurement(date: Date(), exposure: exposure, deposition: totalKeV * 1000, dose: totalGy))
                            try? store.write(FrameRecord(date: Date(), detector: config.selected, exposure: exposure, frame: preparingFrame))
                            lastValue = (config.units == "eV" ? totalKeV * 1000 : (config.units == "Gy" ? totalGy : totalGy * (Double(config.conversion_str) ?? 1))) / exposure
                            parseStage = .head
                            preparingFrame = [:]
                            
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
                            preparingFrame[decoded.coords] = decoded.data
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
                self.stateDesc = "Disconnected."
                self.bytesRead = 0
                
            }
        }
    }
}


