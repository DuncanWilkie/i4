//
//  Device.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/16/21.
//

import Foundation
import ExternalAccessory

//Watches for EAAccessory connection notifications in the default notification center, passing to fns that check if
//inserted or ejected object is the Timepix, beginning or stopping stream reading actions if it is.
//Dumps of the binary read from the Timepix are stored in the application support directory in 1Mb chunks in
//the file ~/stream.

//TODO: estimate file size over the mission, and implement self.compress() if necessary.

//I really wish this could be a monadic function. Apple hurts my soul with @objc and addObserver requiring object contexts...
//We have an *object that exclusively manages global state*. I shouldn't have to stress how uncomfortable that is
//from a functional programming perspective. Singletons are unequivocally an antipattern...


class Detector {
    var session: EASession?
    var manager = EAAccessoryManager.shared()
    var nc = NotificationCenter.default
    var dir: URL
    
    var inStream: InputStream? = nil //optional because I can't initialize it in initializer--only on passing to onConnection
    var outStream: OutputStream? = nil //ditto
    
    var isConnected: Bool = false
    var readoutTimer: Timer?
    var deinitLock = DispatchSemaphore(value: 0)

    var ins = Detector()
    
    private init() {
        //generate file to store stream dumps
        let appSupportDir = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask, appropriateFor: nil, create: true)
        self.dir = appSupportDir.appendingPathComponent("stream")
        

        self.manager.registerForLocalNotifications()
        
        //register self as observer and enter connection and disconnection methods on recieving associated messages
        nc.addObserver(self, selector: #selector(onConnection), name: Notification.Name("EAAccessoryDidConnect"), object: nil)
        nc.addObserver(self, selector: #selector(onDisconnection), name: Notification.Name("EAAccessoryDidDisconnect"), object: nil)
    }
    
    @objc private func onConnection() {
        DispatchQueue.global(qos: .utility).async {
            let accessories = self.manager.connectedAccessories
            
            for i in accessories {
                if i.name == "Timepix" {
                    self.session = EASession(accessory: i, forProtocol: "space.chancellor.placeholder") //TODO: fix protocol
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
            
            self.inStream = self.session!.inputStream!
            self.outStream = OutputStream(url: self.dir, append: true)
            
            self.readoutTimer = Timer.scheduledTimer(timeInterval: 1.0, //should be roughly our minimum exposure setting
                                                     target: self,
                                                     selector: #selector(self.doReading),
                                                     userInfo: nil,
                                                     repeats: true)
        }
    }
    
    @objc private func doReading() {
        if self.isConnected {
            DispatchQueue.global(qos: .utility).async {
                let input = self.inStream!
                let output = self.outStream!
                
                input.schedule(in: .current, forMode: .default)
                output.schedule(in: .current, forMode: .default)
                input.open()
                output.open()
            
                if input.hasBytesAvailable {
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256_000)
                    input.read(buffer, maxLength: 256_000)
                    output.write(buffer, maxLength: 256_000)
                }
                
                self.deinitLock.signal()
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
                        self.outStream!.close()
                        
                        self.inStream = nil
                        self.outStream = nil
                        
                        self.isConnected = false
                        self.readoutTimer?.invalidate()
                        break
                        
                    }
                }
            }
        }
    }
    
    private func compress() { //possibly need?
        return
    }
}
