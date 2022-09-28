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
typealias CalibratedFrame = [PixelCoords : Double] // codomain is keV

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



enum ParseState {
    case len
    case type
    case bytes
}

class StateDelegate: NSObject, StreamDelegate {
    var session: EASession
    var detector: Detector
    var msg_len = 0
    var msg_type = 0
    var bytes_read = 0
    var parse_state: ParseState = .len
    var current_packet: [UInt8] = []
    init(changed: EAAccessory, detector: Detector) {
        self.session = EASession(accessory: changed, forProtocol: "space.chancellor.state")!
        self.detector = detector
        
        super.init()
        
        let input =  session.inputStream! // If we get here and these are nil, there's something really wrong with the detector.
        let output = session.outputStream!
        
        
        input.delegate = self
        input.schedule(in: .current, forMode: .common)
        input.open()
        print(session.protocolString)
        
        output.delegate = self
        output.schedule(in: .current, forMode: .common)
        output.open()
    }
    
    func handle_message() {
        switch(msg_type) {
        case 0xaa:
            print("Received frame packet.")
            detector.saveFrame()
        case 0xab:
            print("Received temperature packet.")
            let temperature: Int = Int((UInt16(current_packet[0]) << 8) & UInt16(current_packet[1]))
            // TODO: integrate into UI and send commands
        case 0xac:
            let str = String(decoding: Data(current_packet), as: UTF8.self)
            print("Received status message\(str)") // TODO: integrate status messages into app
        case 0xae:
            let errors = ["Frame measurement failed", "Powerup failed", "Powerup TPX3 reset recv data error",
                          "Powerup TPX3 init resets error", "Powerup TPX3 init chip ID error", "Powerup TPX3 init DACs error",
                          "Powerup TPX3 init PixCfg error", "Powerup TPX3 init matrix error", "Invalid preset parameter"]
            print("MiniPIX Error: \(errors[Int(current_packet[0])])")
            // TODO: integrate error messages into app
            
        default:
            print("Unrecognized detector message type \(msg_type)")
            break
            // handle the single-byte state messages received from accessory
        }
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch(eventCode) {
        case Stream.Event.hasBytesAvailable:
            let stream = aStream as! InputStream
            while stream.hasBytesAvailable {
                let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                let from_stream_cnt = stream.read(bytes, maxLength: 1)
                let byte = bytes[0]
                bytes.deallocate()
                if from_stream_cnt == 1 {
                    switch(parse_state) {
                    case .len:
                        msg_len = Int(byte)
                        parse_state = .type
                        
                    case .type:
                        msg_type = Int(byte)
                        parse_state = .bytes
                        
                    case .bytes:
                        current_packet.append(byte)
                        bytes_read += 1
                        if bytes_read == msg_len {
                            self.handle_message()
                            parse_state = .len
                            msg_len = 0
                            msg_type = 0
                            current_packet = []
                        }
                    }
                }
            }
            
        case Stream.Event.endEncountered:
            break
        case Stream.Event.errorOccurred:
            print("State stream error \(eventCode)")
        default:
            print("Unrecognized state stream event \(eventCode)")
        }
    }
    
    func write(_ byte: UInt8) {
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        buf[0] = byte
        let code = session.outputStream!.write(buf, maxLength: 1)
        guard code == 1 else {
            print("Write to StreamDelegate output failed with return code \(code)")
            return
        }
    }
}

class FrameDelegate: NSObject, StreamDelegate {
    var session: EASession
    var detector: Detector
    var preparing_pixel: Data = Data(capacity: 6)
    var bytes_read = 0
    var pixels_read = 0
    var pixel_count = 0
    init(changed: EAAccessory, detector: Detector) {
        self.session = EASession(accessory: changed, forProtocol: "space.chancellor.frame")!
        self.detector = detector
        
        super.init()
        
        let input =  session.inputStream! // If we get here and these are nil, there's something really wrong with the detector.
        let output = session.outputStream!
        
        
        input.delegate = self
        input.schedule(in: .current, forMode: .common)
        input.open()
        
        output.delegate = self
        output.schedule(in: .current, forMode: .common)
        output.open()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch(eventCode) {
        case Stream.Event.hasBytesAvailable:
            let stream = aStream as! InputStream
            while stream.hasBytesAvailable {
                let temp = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
                let bytes_from_stream = stream.read(temp, maxLength: 1)
                let byte = temp[0]
                temp.deallocate()
                
                if bytes_from_stream == 1 {
                    if pixel_count == 0 {
                        pixel_count = Int(byte)
                    } else {
                        preparing_pixel[bytes_read] = byte
                        bytes_read += 1
                        
                        if bytes_read == 6 {
                            let pixel = decodePixel(data: preparing_pixel)
                            detector.preparingFrame[pixel.coords] = pixel.data
                            bytes_read = 0
                            pixels_read += 1
                        }
                        
                        if pixels_read == pixel_count {
                            pixel_count = 0
                            pixels_read = 0
                        }
                    }
                }
            }
            
        case Stream.Event.endEncountered:
            break
        case Stream.Event.errorOccurred:
            print("Frame stream error \(eventCode)")
        default:
            print("Unrecognized frame stream event \(eventCode)")
        }
    }
}


class Detector: NSObject, StreamDelegate, ObservableObject { // TODO: Incorporate detector ID from stream in stateDesc when connected but not measuring
    var store: Store
    var config: Config
    var state_session: StateDelegate?
    var frame_session: FrameDelegate?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    // Validation so far: the parsing as appearing below produces identical results to ADVACAM's Python script
    // that serves the same purpose.
    
    var measuring = false { // TODO: Make sure property wrapper not needed to set this from MeasurementSettingsView
        willSet {
            stateDesc = newValue ? "Measuring: "  : (isConnected ? "Connected: ready to measure" : "Disconnected.")
            if isConnected && state_session?.session.outputStream?.hasSpaceAvailable ?? false {
                let startMeas: UInt8 = newValue ? 0xcb : 0xbc
                state_session?.write(startMeas)
            }
        }
    }
    
    var preparingFrame: Frame = [:]
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
    @Published var stateDesc = "Disconnected."
    
    
    init(store: Store, config: Config) {
        self.store = store
        self.config = config
        
        super.init()
        
        //register self as observer and enter connection and disconnection methods on receiving associated messages
        nc.addObserver(self, selector: #selector(self.onConnection(_:)), name: .EAAccessoryDidConnect, object: nil)
        nc.addObserver(self, selector: #selector(self.onDisconnection(_:)), name: .EAAccessoryDidDisconnect, object: nil)
        //actually receive EA.* messages through NC here
        self.manager.registerForLocalNotifications()
    }
    
    
    @objc private func onConnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        print(changed.name)
        
        if changed.name == "iPix" {
            self.state_session = StateDelegate(changed: changed, detector: self)
            self.frame_session = FrameDelegate(changed: changed, detector: self)
            self.isConnected = true
            self.stateDesc = "Connected: ready to measure"
        } else {
            return
        }
        
    }
    
    func saveFrame() {
        lastFrame = calibratedFrame(uncalibrated: preparingFrame, detectorID: config.selected, config: config)
        let totalKeV = lastFrame.reduce(0.0, {x, y in x + y.1})
        let volume = 2 * 0.005 // cm^3
        let density = 2.3212 // g/cm^3
        let mass = volume * density // g
        let totalGy = totalKeV / (mass * 6.24e12) // calculation following doi:10.1088/1742-6596/396/2/022023
        try? store.write(Measurement(date: Date(), exposure: exposure, deposition: totalKeV * 1000, dose: totalGy))
        try? store.write(FrameRecord(date: Date(), detector: config.selected, exposure: exposure, frame: preparingFrame)) // TODO: change to lastFrame?
        lastValue = (config.units == "eV" ? totalKeV * 1000 : (config.units == "Gy" ? totalGy : totalGy * (Double(config.conversion_str) ?? 1))) / exposure
        preparingFrame = [:]
    }
    
    
    
    @objc private func onDisconnection(_ notification: Notification) {
        let changed = notification.userInfo?["EAAccessoryKey"] as! EAAccessory
        if changed.name == "iPix" {
            if self.isConnected {
                self.state_session?.session.outputStream?.close()
                self.state_session?.session.inputStream?.close()
                
                self.frame_session?.session.outputStream?.close()
                self.frame_session?.session.inputStream?.close()
                self.isConnected = false
                self.stateDesc = "Disconnected."
            }
        }
    }
}


