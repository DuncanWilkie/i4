//
//  DoubleSlider.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/1/21
//

import SwiftUI
import Combine

//SliderValue to restrict double range: 0.0 to 1.0
@propertyWrapper
struct SliderValue {
    var value: Double
    
    init(wrappedValue: Double) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Double {
        get { value }
        set { value = min(max(0.0, newValue), 1.0) }
    }
}

class SliderHandle: ObservableObject {
    
    //Slider Size
    let sliderWidth: CGFloat
    let sliderHeight: CGFloat
    
    //Slider Range
    let sliderValueStart: Double
    let sliderValueEnd: Double
    let sliderValueRange: Double
    
    //Slider Handle
    var diameter: CGFloat = 30
    var startLocation: CGPoint
    
    //Current Value
    @Published var currentPercentage: SliderValue
    
    //Slider Button Location
    @Published var onDrag: Bool {
        willSet {
            if (newValue == !onDrag) {
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.impactOccurred()
            }
        }
    }
    @Published var currentLocation: CGPoint
    
    init(sliderWidth: CGFloat, sliderHeight: CGFloat, sliderValueStart: Double, sliderValueEnd: Double, startPercentage: SliderValue) {
        self.sliderWidth = sliderWidth
        self.sliderHeight = sliderHeight
        
        self.sliderValueStart = sliderValueStart
        self.sliderValueEnd = sliderValueEnd
        self.sliderValueRange = sliderValueEnd - sliderValueStart
        
        let startLocation = CGPoint(x: (CGFloat(startPercentage.wrappedValue)/1.0)*sliderWidth, y: sliderHeight/2)
        
        self.startLocation = startLocation
        self.currentLocation = startLocation
        self.currentPercentage = startPercentage
        
        self.onDrag = false
    }
    
    lazy var sliderDragGesture: _EndedGesture<_ChangedGesture<DragGesture>>  = DragGesture()
        .onChanged { value in
            self.onDrag = true
            
            let dragLocation = value.location
            
            //Restrict possible drag area
            self.restrictSliderBtnLocation(dragLocation)
            self.currentPercentage.wrappedValue = Double(self.currentLocation.x / self.sliderWidth)
            
        }.onEnded { _ in
            self.onDrag = false
            
        }
    
    private func restrictSliderBtnLocation(_ dragLocation: CGPoint) {
        //On Slider Width
        if dragLocation.x > CGPoint.zero.x && dragLocation.x < sliderWidth {
            calcSliderBtnLocation(dragLocation)
        }
    }
    
    private func calcSliderBtnLocation(_ dragLocation: CGPoint) {
        if dragLocation.y != sliderHeight/2 {
            currentLocation = CGPoint(x: dragLocation.x, y: sliderHeight/2)
        } else {
            currentLocation = dragLocation
        }
    }
    
    //Current Value
    var currentValue: Double {
        return sliderValueStart + currentPercentage.wrappedValue * sliderValueRange
    }
}

class DoubleSlider: ObservableObject {
    
    //Slider Size
    final let width: CGFloat = 350
    final let lineWidth: CGFloat = 8
    
    //Slider value range from valueStart to valueEnd
    final let valueStart: Double
    final let valueEnd: Double
    
    //Slider Handle
    @ObservedObject var highHandle: SliderHandle
    @ObservedObject var lowHandle: SliderHandle
    
    //Handle start percentage (also for starting point)
    @SliderValue var highHandleStartPercentage = 1.0
    @SliderValue var lowHandleStartPercentage = 0.0
    
    final var anyCancellableHigh: AnyCancellable?
    final var anyCancellableLow: AnyCancellable?
    
    init(_ bounds: (Date, Date)) {
        valueStart = bounds.0.timeIntervalSinceReferenceDate
        valueEnd = bounds.1.timeIntervalSinceReferenceDate
        
        highHandle = SliderHandle(sliderWidth: width,
                                  sliderHeight: lineWidth,
                                  sliderValueStart: valueStart,
                                  sliderValueEnd: valueEnd,
                                  startPercentage: _highHandleStartPercentage
        )
        
        lowHandle = SliderHandle(sliderWidth: width,
                                 sliderHeight: lineWidth,
                                 sliderValueStart: valueStart,
                                 sliderValueEnd: valueEnd,
                                 startPercentage: _lowHandleStartPercentage
        )
        
        anyCancellableHigh = highHandle.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }
        anyCancellableLow = lowHandle.objectWillChange.sink { _ in
            self.objectWillChange.send()
        }
    }
    
    //Percentages between high and low handle
    var percentagesBetween: String {
        return String(format: "%.2f", highHandle.currentPercentage.wrappedValue - lowHandle.currentPercentage.wrappedValue)
    }
    
    //Value between high and low handle
    var valueBetween: String {
        return String(format: "%.2f", highHandle.currentValue - lowHandle.currentValue)
    }
}


struct SliderPathBetweenView: View {
    @ObservedObject var slider: DoubleSlider
    
    var body: some View {
        Path { path in
            path.move(to: slider.lowHandle.currentLocation)
            path.addLine(to: slider.highHandle.currentLocation)
        }
        .stroke(Color("primaryAccent"), lineWidth: slider.lineWidth)
    }
}

struct SliderHandleView: View {
    @ObservedObject var handle: SliderHandle
    @EnvironmentObject var store: Store
    
    var body: some View {
        ZStack {
            
            Text("\(autoFormatter(Date(timeIntervalSinceReferenceDate: handle.currentValue), Date(timeIntervalSinceReferenceDate: handle.sliderValueStart), Date(timeIntervalSinceReferenceDate: handle.sliderValueEnd), store.fm))"
            )
            .foregroundColor(Color.gray)
            .position(x: handle.currentLocation.x, y: handle.currentLocation.y - 40)
            .opacity(handle.onDrag ? 1.0 : 0.0)
            Circle()
                .frame(width: handle.diameter, height: handle.diameter)
                .foregroundColor(.gray)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 0)
                .scaleEffect(handle.onDrag ? 1.3 : 1)
                .contentShape(Rectangle())
                .position(x: handle.currentLocation.x, y: handle.currentLocation.y)
            
        }
    }
}

struct SliderView: View {
    @ObservedObject var slider: DoubleSlider
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: slider.lineWidth)
                .fill(Color.gray.opacity(0.2))
                .frame(width: slider.width, height: slider.lineWidth)
                .overlay(
                    ZStack {
                        //Path between both handles
                        SliderPathBetweenView(slider: slider)
                        
                        //Low Handle
                        SliderHandleView(handle: slider.lowHandle)
                            .highPriorityGesture(slider.lowHandle.sliderDragGesture)
                        
                        //High Handle
                        SliderHandleView(handle: slider.highHandle)
                            .highPriorityGesture(slider.highHandle.sliderDragGesture)
                    })
        }
    }
}
