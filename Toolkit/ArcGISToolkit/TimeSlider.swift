//
// Copyright 2018 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import QuartzCore
import ArcGIS

// MARK: - Time Slider Control

/*
 Controls how labels on the slider are displayed.
 */
public enum TimeSliderLabelMode {
    case none
    case thumbs
    case ticks
}

/*
 Playback direction when time is being animated.
 */
public enum PlaybackDirection {
    case forward
    case backward
}

/*
 The looping behavior of the slider when time is being animated.
 */
public enum LoopMode {
    case none
    case `repeat`
    case reverse
}

/*
 Different color themes of the slider.
 */
public enum Theme {
    case black
    case blue
    case oceanBlue
}

public class TimeSlider: UIControl {
    
    // MARK: - Public Properties
    
    // MARK: Current Extent Properties
    
    /*
     The current time window or time instant of the slider
     */
    public var currentExtent: AGSTimeExtent? {
        didSet {
            if let startTime = currentExtent?.startTime, let endTime = currentExtent?.endTime {
                //
                // Update current extent start and end time
                updateCurrentExtentStartTime(startTime)
                updateCurrentExtentEndTime(endTime)
                
                // Update flag only if it's not an internal update
                if !internalUpdate {
                    //
                    // Range is enabled only if both times are not same.
                    isRangeEnabled = (startTime != endTime)
                }
            }
            // This means there is only one thumb needs to be displayed and current extent start and end times are same.
            else if let startTime = currentExtent?.startTime, currentExtent?.endTime == nil {
                //
                // Only one thumb should be displayed
                // so set range to false
                isRangeEnabled = false
                
                // Update current extent start time
                updateCurrentExtentStartTime(startTime)
                
                // Start and end time must be same.
                currentExtentEndTime = currentExtentStartTime
            }
            // This means there is only one thumb needs to be displayed and current extent start and end times are same.
            else if let endTime = currentExtent?.endTime, currentExtent?.startTime == nil {
                //
                // Only one thumb should be displayed
                // so set range to false
                isRangeEnabled = false
                
                // Update current extent start time
                updateCurrentExtentStartTime(endTime)
                
                // Start and end time must be same.
                currentExtentEndTime = currentExtentStartTime
            }
            // Set start and end time to nil if
            // current extent is nil
            else if currentExtent == nil {
                currentExtentStartTime = nil
                currentExtentEndTime = nil
            }
            
            // Refresh the view
            refresh()
        }
    }
    
    /*
     The color used to tint the current extent of the slider.
     */
    public var currentExtentFillColor: UIColor = UIColor.black {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    /*
     The current extent label color.
     */
    public var currentExtentLabelColor: UIColor = UIColor.darkText {
        didSet {
            currentExtentStartTimeLabel.foregroundColor = currentExtentLabelColor.cgColor
            currentExtentEndTimeLabel.foregroundColor = currentExtentLabelColor.cgColor
        }
    }
    
    /*
     The current extent label font.
     */
    public var currentExtentLabelFont: UIFont = UIFont.systemFont(ofSize: 12.0) {
        didSet {
            currentExtentStartTimeLabel.font = currentExtentLabelFont as CFTypeRef
            currentExtentStartTimeLabel.fontSize = currentExtentLabelFont.pointSize
            currentExtentEndTimeLabel.font = currentExtentLabelFont as CFTypeRef
            currentExtentEndTimeLabel.fontSize = currentExtentLabelFont.pointSize
        }
    }
    
    /*
     The date formatter used for full extent dates.
     */
    public var currentExtentDateFormatter: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        return formatter
    }()
    
    /*
     A Boolean value that indicates whether the start time of the currentExtent can be
     manipulated through user interaction or moves when time is being animated.
     */
    public var isStartTimePinned = false {
        didSet {
            lowerThumbLayer.isPinned = isStartTimePinned
        }
    }
    
    /*
     A Boolean value that indicates whether the end time of the currentExtent can be
     manipulated through user interaction or moves when time is being animated.
     */
    public var isEndTimePinned = false {
        didSet {
            if isRangeEnabled {
                upperThumbLayer.isPinned = isEndTimePinned
            }
            else {
                isStartTimePinned = isEndTimePinned
                lowerThumbLayer.isPinned = isEndTimePinned
                upperThumbLayer.isPinned = isEndTimePinned
            }
        }
    }
    
    // MARK: Full Extent Properties
    
    /*
     The full extent time window on the slider.
     */
    public var fullExtent: AGSTimeExtent? {
        didSet {
            //
            // Set current extent if it's nil.
            if currentExtent == nil, let fullExtent = fullExtent {
                currentExtent = fullExtent
            }
            else if fullExtent == nil {
                timeSteps?.removeAll()
                tickMarks?.removeAll()
                removeTickMarkLabels()
                currentExtent = fullExtent
            }
            else {
                //
                // It is possible that the current extent times are outside of the range of
                // new full extent times. Adjust and sanp them to the tick marks.
                if let startTime = currentExtentStartTime, let endTime = currentExtentEndTime {
                    updateCurrentExtentStartTime(startTime)
                    updateCurrentExtentEndTime(endTime)
                }
            }
            refresh()
        }
    }
    
    /*
     The color used to tint the full extent border of the slider.
     */
    public var fullExtentBorderColor: UIColor = UIColor.black {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    /*
     The border width of the full extent of the slider.
     */
    public var fullExtentBorderWidth: Double = 1.0 {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    /*
     The color used to tint the full extent of the slider.
     */
    public var fullExtentFillColor: UIColor = UIColor.white {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    /*
     The full extent label color.
     */
    public var fullExtentLabelColor: UIColor = UIColor.darkText {
        didSet {
            fullExtentStartTimeLabel.foregroundColor = fullExtentLabelColor.cgColor
            fullExtentEndTimeLabel.foregroundColor = fullExtentLabelColor.cgColor
        }
    }
    
    /*
     The full extent label font.
     */
    public var fullExtentLabelFont: UIFont = UIFont.systemFont(ofSize: 12.0) {
        didSet {
            fullExtentStartTimeLabel.font = fullExtentLabelFont as CFTypeRef
            fullExtentStartTimeLabel.fontSize = fullExtentLabelFont.pointSize
            fullExtentEndTimeLabel.font = fullExtentLabelFont as CFTypeRef
            fullExtentEndTimeLabel.fontSize = fullExtentLabelFont.pointSize
        }
    }
    
    /*
     A Boolean value that indicates whether the minimum and full extent
     lables are visible or not. Default if True.
     */
    public var fullExtentLabelsVisible = true {
        didSet {
            fullExtentStartTimeLabel.isHidden = !fullExtentLabelsVisible
            fullExtentEndTimeLabel.isHidden = !fullExtentLabelsVisible
            if fullExtentLabelsVisible {
                updateFullExtentLabelFrames()
            }
        }
    }
    
    /*
     The date formatter used for full extent dates.
     */
    public var fullExtentDateFormatter: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        return formatter
    }()
    
    // MARK: Time Step Properties
    
    /*
     The time steps calculated along the time slider. These are
     calculated based on the full extent and time step interval.
     */
    public private(set) var timeSteps: [Date]?
    
    /*
     The interval at which users can move forward and
     back through the slider's full extent.
     */
    public var timeStepInterval: AGSTimeValue? {
        didSet {
            calculateTimeSteps()
            refresh()
        }
    }
    
    /*
     The date formatter used for time interval or tick mark dates.
     */
    public var timeStepIntervalDateFormatter: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        return formatter
    }()
    
    /*
     The time interval or tick mark label color.
     */
    public var timeStepIntervalLabelColor: UIColor = UIColor.darkText {
        didSet {
            tickMarkLabels.forEach { (tickMarkLabel) in
                tickMarkLabel.foregroundColor = timeStepIntervalLabelColor.cgColor
            }
        }
    }
    
    /*
     The current extent label font.
     */
    public var timeStepIntervalLabelFont: UIFont = UIFont.systemFont(ofSize: 12.0) {
        didSet {
            tickMarkLabels.forEach { (tickMarkLabel) in
                tickMarkLabel.font = timeStepIntervalLabelFont as CFTypeRef
                tickMarkLabel.fontSize = timeStepIntervalLabelFont.pointSize
            }
        }
    }
    
    /*
     The color used to tint the full extent of the slider.
     */
    public var timeStepIntervalTickColor: UIColor = UIColor.black {
        didSet {
            tickMarkLayer.setNeedsDisplay()
        }
    }
    
    /*
     Controls how labels on the slider are displayed. The default is thumbs.
     */
    public var labelMode: TimeSliderLabelMode = .thumbs {
        didSet {
            switch labelMode {
            case .none:
                //
                // Hide current extent labels
                currentExtentStartTimeLabel.isHidden = true
                currentExtentEndTimeLabel.isHidden = true
            case .thumbs:
                //
                // Show current extent labels
                // only if slider is visible.
                if isSliderVisible {
                    currentExtentStartTimeLabel.isHidden = false
                    currentExtentEndTimeLabel.isHidden = isRangeEnabled ? false : true
                    updateCurrentExtentLabelFrames()
                }
            case .ticks:
                //
                // Hide current extent labels
                currentExtentStartTimeLabel.isHidden = true
                currentExtentEndTimeLabel.isHidden = true
            }
            
            // All above cases require to remove
            // existing tick marks and reposition
            // them (none will not add it)
            removeTickMarkLabels()
            positionTickMarks()
        }
    }
    
    // MARK: Thumb Properties
    
    /*
     The color used to tint the thumbs.
     */
    public var thumbFillColor: UIColor = UIColor.white {
        didSet {
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }
    
    /*
     The color used to tint the thumb's border.
     */
    public var thumbBorderColor: UIColor = UIColor.black {
        didSet {
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }
    
    /*
     The border width of the thumb.
     */
    public var thumbBorderWidth: Double = 1.0 {
        didSet {
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }
    
    /*
     The size of the thumb.
     */
    public var thumbSize: CGSize = CGSize(width: 25.0, height: 25.0) {
        didSet {
            //
            // More than 50 width and height
            // is too big for the iOS control.
            // So, restrict it.
            if thumbSize.width > maximumThumbSize {
                thumbSize.width = maximumThumbSize
            }
            if thumbSize.height > maximumThumbSize {
                thumbSize.height = maximumThumbSize
            }
            
            // Set side padding of the track layer for the new thumb size
            // so thumb has enough space to go all the way to end.
            trackLayerSidePadding = (thumbSize.width / 2.0) + labelSidePadding
            
            // Refresh the view.
            refresh()
        }
    }
    
    /*
     The corner radius of the thumb.
     */
    public var thumbCornerRadius: Double = 1.0 {
        didSet {
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }
    
    // MARK: Playback Properties
    
    /*
     A Boolean value indicating whether playback buttons are visible or not. Default is true.
     */
    public var isPlaybackButtonsVisible: Bool = true {
        didSet {
            layoutIfNeeded()
            UIView.animate(withDuration: 0.25) {
                self.heightConstraint?.constant = self.heightConstraintConstant()
                self.playPauseButton?.isHidden = !self.isPlaybackButtonsVisible
                self.forwardButton?.isHidden = !self.isPlaybackButtonsVisible
                self.backButton?.isHidden = !self.isPlaybackButtonsVisible
                self.refresh()
            }
        }
    }
    
    /*
     The color used to tint the thumb's border.
     */
    public var playbackButtonsFillColor: UIColor = UIColor.black {
        didSet {
            //
            // Set new button images created with new fill color
            let playPauseButtonImage = isPlaying ? pauseImage?.imageWithColor(playbackButtonsFillColor) : playImage?.imageWithColor(playbackButtonsFillColor)
            playPauseButton?.setBackgroundImage(playPauseButtonImage, for: .normal)
            forwardButton?.setBackgroundImage(forwardImage?.imageWithColor(playbackButtonsFillColor), for: .normal)
            backButton?.setBackgroundImage(backImage?.imageWithColor(playbackButtonsFillColor), for: .normal)
        }
    }
    
    /*
     Playback direction when time is being animated.
     */
    public var playbackDirection: PlaybackDirection = .forward
    
    /*
     The looping behavior of the slider when time is being animated.
     */
    public var playbackLoopMode: LoopMode = .repeat
    
    /*
     The amount of time during playback that will elapse before the slider advances
     to the next time step. If geoView is available then playback will wait until
     geoView's drawing (drawStatus) is completed before advances to the next time step.
     */
    public var playbackInterval: TimeInterval = 1
    
    /*
     A Boolean value indicating whether playback is currently running.
     */
    public var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                //
                // Set the pause image
                playPauseButton?.setBackgroundImage(pauseImage?.imageWithColor(playbackButtonsFillColor), for: .normal)
                
                // Invalidate timer, in case this button is tapped multiple times
                timer.invalidate()
                
                // Start the timer with specified playback interval
                timer = Timer.scheduledTimer(timeInterval: playbackInterval, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
            }
            else {
                //
                // Set the play image
                playPauseButton?.setBackgroundImage(playImage?.imageWithColor(playbackButtonsFillColor), for: .normal)
                
                // Invalidate timer.
                timer.invalidate()
            }
        }
    }
    
    // MARK: Other Properties
    
    /*
     This will initialize the slider's fullExtent, currentExtent and timeStepInterval
     properties based on time enabled layers in the geo view.
     */
    public private(set) var geoView: AGSGeoView?
    
    /*
     A Boolean value indicating whether slider is visible or not. Default is true.
     */
    public var isSliderVisible: Bool = true {
        didSet {
            layoutIfNeeded()
            UIView.animate(withDuration: 0.25) {
                self.heightConstraint?.constant = self.heightConstraintConstant()
                self.lowerThumbLayer.isHidden = !self.isSliderVisible
                self.upperThumbLayer.isHidden = !self.isSliderVisible
                self.trackLayer.isHidden = !self.isSliderVisible
                self.tickMarkLayer.isHidden = !self.isSliderVisible
                self.fullExtentStartTimeLabel.isHidden = !self.isSliderVisible
                self.fullExtentEndTimeLabel.isHidden = !self.isSliderVisible
                self.currentExtentStartTimeLabel.isHidden = !self.isSliderVisible
                self.currentExtentEndTimeLabel.isHidden = !self.isSliderVisible
                self.tickMarkLabels.forEach({ (tickMarkLabel) in
                    tickMarkLabel.isHidden = !self.isSliderVisible
                })
                self.refresh()
            }
        }
    }
    
    /*
     The color used to tint the layer extent of the slider.
     */
    public var layerExtentFillColor: UIColor = UIColor.gray {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }
    
    /*
     The height of the slider track.
     */
    public var trackHeight: Double = 6.0 {
        didSet {
            refresh()
        }
    }
    
    /*
     Different color themes of the slider.
     */
    public var theme: Theme = .black {
        didSet {
            //
            // Set the color based on
            // selected option
            var tintColor: UIColor
            var backgroundColor: UIColor
            switch theme {
            case .black:
                tintColor = UIColor.black
                backgroundColor = UIColor.lightGray.withAlphaComponent(0.6)
            case .blue:
                tintColor = UIColor.customBlue()
                backgroundColor = UIColor.lightSkyBlue().withAlphaComponent(0.3)
            case .oceanBlue:
                tintColor = UIColor.oceanBlue()
                backgroundColor = UIColor.white.withAlphaComponent(0.6)
            }
            
            // Set colors of the components
            self.backgroundColor = backgroundColor
            currentExtentFillColor = tintColor
            currentExtentLabelColor = tintColor
            fullExtentBorderColor = tintColor
            fullExtentFillColor = UIColor.white
            fullExtentLabelColor = tintColor
            timeStepIntervalLabelColor = tintColor
            timeStepIntervalTickColor = tintColor
            thumbFillColor = UIColor.white
            thumbBorderColor = tintColor
            layerExtentFillColor = tintColor.withAlphaComponent(0.4)
            pinnedThumbFillColor = tintColor
            playbackButtonsFillColor = tintColor
        }
    }
    
    /*
     A Boolean value indicating whether changes in the slider’s value
     generate continuous update events. Default is True.
     */
    public var isContinuous: Bool = true
    
    // MARK: - Private Properties
    
    private var previousLocation = CGPoint()
    
    private var currentExtentStartTime: Date?
    private var currentExtentEndTime: Date?
    private var previousCurrentExtentStartTime: Date?
    private var previousCurrentExtentEndTime: Date?
    private var startTimeStepIndex: Int = -1
    private var endTimeStepIndex: Int = -1
    private var internalUpdate: Bool = false
    
    fileprivate var layerExtent: AGSTimeExtent?
    
    private let trackLayer = TimeSliderTrackLayer()
    private let tickMarkLayer = TimeSliderTickMarkLayer()
    private let lowerThumbLayer = TimeSliderThumbLayer()
    private let upperThumbLayer = TimeSliderThumbLayer()
    private let fullExtentStartTimeLabel: CATextLayer = CATextLayer()
    private let fullExtentEndTimeLabel: CATextLayer = CATextLayer()
    private let currentExtentStartTimeLabel: CATextLayer = CATextLayer()
    private let currentExtentEndTimeLabel: CATextLayer = CATextLayer()
    
    private let maximumThumbSize: CGFloat = 50.0
    private var trackLayerSidePadding: CGFloat = 30.0
    private let labelSidePadding: CGFloat = 10.0
    private let labelPadding: CGFloat = 3.0
    private let paddingBetweenLabels: CGFloat = 5.0
    
    private var tickMarkLabels = [CATextLayer]()
    fileprivate var tickMarks: [TickMark]?
    
    private var playPauseButton: UIButton?
    private var forwardButton: UIButton?
    private var backButton: UIButton?
    
    private var playImage: UIImage?
    private var pauseImage: UIImage?
    private var forwardImage: UIImage?
    private var backImage: UIImage?
    
    fileprivate var pinnedThumbFillColor: UIColor = UIColor.black
    
    // If set to True, it will show two thumbs, otherwise only one. Default is True.
    fileprivate var isRangeEnabled: Bool = true {
        didSet {
            upperThumbLayer.isHidden = !isRangeEnabled
            currentExtentEndTimeLabel.isHidden = !isRangeEnabled
        }
    }
    
    private var heightConstraint: NSLayoutConstraint?
    private var timer = Timer()
    
    private static var KVOContext = 0
    private var map: AGSMap?
    private var scene: AGSScene?
    private var isObserving: Bool = false
    
    // MARK: - Override Functions
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public var frame: CGRect {
        didSet {
            refresh()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        //
        // Stop playing
        isPlaying = false
        
        // Set preview location from touch
        previousLocation = touch.location(in: self)
        
        // Hit test the thumb layers.
        // If the thumb is pinned then it should not allow the interaction.
        if !lowerThumbLayer.isPinned && lowerThumbLayer.frame.contains(previousLocation) {
            lowerThumbLayer.isHighlighted = true
        }
        if !upperThumbLayer.isPinned && isRangeEnabled && upperThumbLayer.frame.contains(previousLocation) {
            upperThumbLayer.isHighlighted = true
        }
        
        // If both thumbs are highlighted and are at full extent's start time then return only highlighted upper thumb layer
        if let fullExtentStartTime = fullExtent?.startTime, let currentExtentStartTime = currentExtentStartTime, let currentExtentEndTime = currentExtentEndTime, (currentExtentStartTime, currentExtentEndTime) == (currentExtentEndTime, fullExtentStartTime), lowerThumbLayer.isHighlighted, upperThumbLayer.isHighlighted {
            lowerThumbLayer.isHighlighted = false
            upperThumbLayer.isHighlighted = true
        }
        
        return lowerThumbLayer.isHighlighted || upperThumbLayer.isHighlighted
    }
    
    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        //
        // Get the touch location
        let location = touch.location(in: self)
        
        // Update previous location
        previousLocation = location
        
        // Get the selected value
        let selectedValue = value(for: Double(location.x))
        
        // Set values based on selected thumb
        if lowerThumbLayer.isHighlighted {
            updateCurrentExtentStartTime(Date(timeIntervalSince1970: selectedValue))
        }
        else if upperThumbLayer.isHighlighted {
            updateCurrentExtentEndTime(Date(timeIntervalSince1970: selectedValue))
        }
        
        // If range is not enabled
        // then both values are same
        if !isRangeEnabled {
            currentExtentEndTime = currentExtentStartTime
        }
        
        // Set current extent
        updateCurrentExtent(AGSTimeExtent(startTime: currentExtentStartTime, endTime: currentExtentEndTime))
        
        // Notify that the value is changed
        if isContinuous {
            notifyChangeOfCurrentExtent()
        }
        
        return true
    }
    
    override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        //
        // Un-highlight thumbs
        lowerThumbLayer.isHighlighted = false
        upperThumbLayer.isHighlighted = false
        
        // Notify that the value is changed
        if !isContinuous {
            notifyChangeOfCurrentExtent()
        }
    }
    
    // Refresh the slider when requried
    public override func layoutSubviews() {
        refresh()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: Public Functions
    
    /*
     This will look for all time aware layers which are visible and are participating in time based filtering
     to initialize slider's fullExtent, currentExtent and timeStepInterval properties.
     */
    public func initializeTimeProperties(geoView: AGSGeoView, completion: @escaping (Error?)->Void) {
        //
        // Set geoview on the slider
        // it will initialize required properties.
        self.geoView = geoView
        
        //
        // Get all layers from geoView
        var operationalLayers = [AGSLayer]()
        if let mapView = geoView as? AGSMapView {
            if let layers = mapView.map?.operationalLayers as AnyObject as? [AGSLayer] {
                operationalLayers = layers
                map = mapView.map
            }
        }
        else if let sceneView = geoView as? AGSSceneView {
            if let layers = sceneView.scene?.operationalLayers as AnyObject as? [AGSLayer] {
                operationalLayers = layers
                scene = sceneView.scene
            }
        }
        
        // Start observing
        addObservers()
        
        //
        // Loop through all time aware layers which are visible and are participating in time based filtering
        // and initialize slider's fullExtent, currentExtent and timeStepInterval properties
        var timeAwareLayersFullExtent: AGSTimeExtent?
        var timeAwareLayersStepInterval: AGSTimeValue?
        var supportsRangeTimeFiltering = true
        
        //
        // This will help in waiting for all layer/sublayers
        // to be loaded to gather requried information
        // to load time properties
        let dispatchGroup = DispatchGroup()
        
        // Load all operational layers to initialize slider properties
        AGSLoadObjects(operationalLayers) { [weak self] (loaded) in
            //
            // Once, all layers are loaded,
            // loop through all of them.
            if loaded {
                operationalLayers.forEach({ (layer) in
                    //
                    // The layer must be time aware, supports time filtering and time filtering is enabled.
                    if let timeAwareLayer = layer as? AGSTimeAware, timeAwareLayer.supportsTimeFiltering, timeAwareLayer.isTimeFilteringEnabled {
                        //
                        // Get the layer's full time extent and combine with other layer's full extent.
                        if let fullTimeExtent = timeAwareLayer.fullTimeExtent {
                            timeAwareLayersFullExtent = timeAwareLayersFullExtent == nil ? timeAwareLayer.fullTimeExtent : timeAwareLayersFullExtent?.union(otherTimeExtent: fullTimeExtent)
                        }
                        
                        // This is an async operation to find out time step interval and
                        // whether range time filtering is supported by the layer.
                        dispatchGroup.enter()
                        self?.findTimeStepIntervalAndIsRangeTimeFilteringSupported(for: timeAwareLayer, completion: { (arg0) in
                            if let (timeInterval, supportsRangeFiltering) = arg0 {
                                supportsRangeTimeFiltering = supportsRangeFiltering
                                
                                // We are looking for the greater time interval than we already have it.
                                if let timeInterval = timeInterval {
                                    if var timeAwareLayersStepInterval = timeAwareLayersStepInterval {
                                        timeAwareLayersStepInterval = timeInterval.isGreaterThan(otherTimeValue: timeAwareLayersStepInterval) ? timeInterval : timeAwareLayersStepInterval
                                    }
                                    else {
                                        timeAwareLayersStepInterval = timeInterval
                                    }
                                }
                            }
                            
                            // We got all information required.
                            // Leave the group so we can set time
                            // properties and notify
                            dispatchGroup.leave()
                        })
                    }
                })
            }
            
            dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                //
                // If full extent or time step interval is not available then
                // we cannot initialize the slider. Finish with error.
                if timeAwareLayersFullExtent == nil || timeAwareLayersStepInterval == nil {
                    completion(NSError(domain: AGSErrorDomain, code: AGSErrorCode.commonNoData.rawValue, userInfo: [NSLocalizedDescriptionKey : "There are no time aware layers to initialize time slider."]))
                }
                else {
                    //
                    // Set calculated full extent and time step interval
                    self?.fullExtent = timeAwareLayersFullExtent
                    self?.timeStepInterval = timeAwareLayersStepInterval
                    
                    // Layer extent should be same as full extent.
                    self?.layerExtent = self?.fullExtent
                    
                    // If the geoview has a time extent defined, use that. Otherwise, set the current extent to either the
                    // full extent's start (if range filtering is not supported), or to the entire full extent.
                    if let geoViewTimeExtent = self?.geoView?.timeExtent {
                        self?.currentExtent = geoViewTimeExtent
                    }
                    else {
                        if let fullExtentStartTime = self?.fullExtent?.startTime, let fullExtentEndTime = self?.fullExtent?.endTime {
                            self?.currentExtent = supportsRangeTimeFiltering ? AGSTimeExtent(startTime: fullExtentStartTime, endTime: fullExtentEndTime) : AGSTimeExtent(timeInstant: fullExtentStartTime)
                        }
                    }
                    completion(nil)
                }
            })
        }
    }
    
    /*
     This will initialize slider's fullExtent, currentExtent and timeStepInterval properties
     if the layer is visible and participate in time based filtering.
     */
    public func initializeTimeProperties(timeAwareLayer: AGSTimeAware, completion: @escaping (Error?)->Void) {
        //
        // The layer must be loadable.
        if let layer = timeAwareLayer as? AGSLoadable {
            layer.load(completion: { [weak self] (error) in
                //
                // If layer fails to load then
                // return with an error.
                guard error == nil else {
                    completion(error)
                    return
                }
                
                // The layer must support time filtering and it should enabled
                // then only we can initialize the time slider.
                if timeAwareLayer.supportsTimeFiltering && timeAwareLayer.isTimeFilteringEnabled {
                    //
                    // This is an async operation to find out time step interval and
                    // whether range time filtering is supported by the layer.
                    self?.findTimeStepIntervalAndIsRangeTimeFilteringSupported(for: timeAwareLayer, completion: { [weak self] (arg0) in
                        if let (timeInterval, supportsRangeTimeFiltering) = arg0 {
                            //
                            // If either full extent or time step interval is not
                            // available then the layer does not have information
                            // required to initialize time slider. Finish with an error.
                            guard let timeInterval = timeInterval, let fullTimeExtent = timeAwareLayer.fullTimeExtent else {
                                completion(NSError(domain: AGSErrorDomain, code: AGSErrorCode.commonNoData.rawValue, userInfo: [NSLocalizedDescriptionKey : "The layer does not have time information to initialize time slider."]))
                                return
                            }
                            
                            // Set full extent of the layer
                            self?.fullExtent = fullTimeExtent
                            
                            // Layer extent should be same as full extent.
                            self?.layerExtent = self?.fullExtent
                            
                            // Set the time setp interval
                            self?.timeStepInterval = timeInterval
                            
                            // Set the current extent to either the full extent's start (if range filtering is not supported), or to the entire full extent.
                            if let fullExtentStartTime = self?.fullExtent?.startTime, let fullExtentEndTime = self?.fullExtent?.endTime {
                                self?.currentExtent = supportsRangeTimeFiltering ? AGSTimeExtent(startTime: fullExtentStartTime, endTime: fullExtentEndTime) : AGSTimeExtent(timeInstant: fullExtentStartTime)
                            }
                            
                            // Slider is loaded successfully.
                            completion(nil)
                        }
                    })
                }
                else {
                    completion(NSError(domain: AGSErrorDomain, code: AGSErrorCode.commonNoData.rawValue, userInfo: [NSLocalizedDescriptionKey : "The layer either does not support time filtering or is not enabled."]))
                }
            })
        }
        else {
            completion(NSError(domain: AGSErrorDomain, code: AGSErrorCode.commonNoData.rawValue, userInfo: [NSLocalizedDescriptionKey : "The layer is not loadable to initialize time slider."]))
        }
    }
    
    /*
     This will re-calculate's timeStepInterval based on the provided step count.
     The time slider must have full extent available to calcluate the timeStepInterval.
     */
    public func initializeTimeSteps(timeStepCount: Int) {
        //
        // If full extent is not available
        // then bail out
        if fullExtent == nil {
            return
        }
        
        if let fullExtentStartTime = fullExtent?.startTime, let fullExtentEndTime = fullExtent?.endTime {
            let timeIntervalInSeconds = ((fullExtentEndTime.timeIntervalSince1970 - fullExtentStartTime.timeIntervalSince1970) / Double(timeStepCount - 1)) + fullExtentStartTime.timeIntervalSince1970
            let timeIntervalDate = Date(timeIntervalSince1970: timeIntervalInSeconds)
            if let (duration, component) = timeIntervalDate.offset(from: fullExtentStartTime) {
                timeStepInterval = AGSTimeValue.fromCalenderComponents(duration: Double(duration), component: component)
            }
        }
    }
    
    /*
     Moves the slider thumbs forward with provided time steps.
     */
    @discardableResult public func stepForward(timeSteps: Int) -> Bool {
        //
        // Time steps must be greater than 0
        if timeSteps > 0 {
            return moveTimeStep(timeSteps: timeSteps)
        }
        return false
    }
    
    /*
     Moves the slider thumbs back with provided time steps.
     */
    @discardableResult public func stepBack(timeSteps: Int) -> Bool {
        //
        // Time steps must be greater than 0
        if timeSteps > 0 {
            return moveTimeStep(timeSteps: 0 - timeSteps)
        }
        return false
    }
    
    // MARK: - Actions
    
    @objc private func forwardAction(_ sender: UIButton) {
        isPlaying = false
        stepForward(timeSteps: 1)
    }
    
    @objc private func backAction(_ sender: UIButton) {
        isPlaying = false
        stepBack(timeSteps: 1)
    }
    
    @objc private func playPauseAction(_ sender: UIButton) {
        isPlaying = !isPlaying
    }
    
    @discardableResult private func moveTimeStep(timeSteps: Int) -> Bool {
        //
        // Time steps must be between 1 and count of calculated time steps
        if let ts = self.timeSteps, timeSteps < ts.count, let startTime = currentExtentStartTime, let endTime = currentExtentEndTime {
            //
            // Bail out if start and end both times are pinned
            if isStartTimePinned && isEndTimePinned {
                isPlaying = false
                return false
            }
            
            // Set the start time step index if it's not set
            if startTimeStepIndex <= 0 {
                if let (index, date) =  closestTimeStep(for: startTime) {
                    currentExtentStartTime = date
                    startTimeStepIndex = index
                }
            }
            
            // Set the end time step index if it's not set
            if endTimeStepIndex <= 0 {
                if let (index, date) = closestTimeStep(for: endTime) {
                    currentExtentEndTime = date
                    endTimeStepIndex = index
                }
            }
            
            // Get the minimum and maximum allowable time step indexes. This is not necessarily the end of the time slider since
            // the start and end times may be pinned.
            let minTimeStepIndex = !isStartTimePinned ? 0 : startTimeStepIndex;
            let maxTimeStepIndex = !isEndTimePinned ? ts.count - 1 : endTimeStepIndex;
            
            // Get the number of steps by which to move the current time.  If the number specified in the method call would move the current time extent
            // beyond the valid range, clamp the number of steps to the maximum number that the extent can move in the specified direction.
            var validTimeStepDelta = 0
            if timeSteps > 0 {
                validTimeStepDelta = startTimeStepIndex + timeSteps <= maxTimeStepIndex ? timeSteps : maxTimeStepIndex - startTimeStepIndex
            }
            else {
                validTimeStepDelta = endTimeStepIndex + timeSteps >= minTimeStepIndex ? timeSteps : minTimeStepIndex - endTimeStepIndex
            }
            
            // Get the new start and end time step indexes
            let newStartTimeStepIndex = !isStartTimePinned && (validTimeStepDelta > 0 || startTimeStepIndex + validTimeStepDelta >= minTimeStepIndex) && ((endTimeStepIndex + validTimeStepDelta <= maxTimeStepIndex) || isEndTimePinned) ?
                startTimeStepIndex + validTimeStepDelta : startTimeStepIndex
            let newEndTimeStepIndex = !isEndTimePinned && (validTimeStepDelta < 0 || endTimeStepIndex + validTimeStepDelta <= maxTimeStepIndex) && ((startTimeStepIndex + validTimeStepDelta >= minTimeStepIndex) || isStartTimePinned) ?
                endTimeStepIndex + validTimeStepDelta : endTimeStepIndex
            
            // Evaluate how many time steps the start and end were moved by and whether they were able to be moved by the requested number of steps
            let startDelta = newStartTimeStepIndex - startTimeStepIndex;
            let endDelta = newEndTimeStepIndex - endTimeStepIndex;
            let canMoveStartAndEndByTimeSteps = startDelta == timeSteps && endDelta == timeSteps;
            let canMoveStartOrEndByTimeSteps = startDelta == timeSteps || endDelta == timeSteps;
            
            let isRequestedMoveValid = canMoveStartAndEndByTimeSteps || canMoveStartOrEndByTimeSteps;
            
            // Apply the new extent if the new time indexes represent a valid change
            if isRequestedMoveValid && newStartTimeStepIndex < ts.count && newEndTimeStepIndex < ts.count {
                
                // Set new times and time step indexes
                currentExtentStartTime = ts[newStartTimeStepIndex]
                startTimeStepIndex = newStartTimeStepIndex
                currentExtentEndTime = ts[newEndTimeStepIndex]
                endTimeStepIndex = newEndTimeStepIndex
                
                // Set current extent
                updateCurrentExtent(AGSTimeExtent(startTime: currentExtentStartTime, endTime: currentExtentEndTime))
                
                // Notify the chagne in current extent
                notifyChangeOfCurrentExtent()
            }
            return isRequestedMoveValid
        }
        return false
    }
    
    @objc private func timerAction() {
        if let geoView = self.geoView {
            if geoView.drawStatus == .completed {
                handlePlaying()
            }
        }
        else {
            handlePlaying()
        }
    }
    
    private func handlePlaying() {
        switch playbackLoopMode {
        case .none:
            isPlaying = false
        case .repeat:
            switch playbackDirection {
            case .forward:
                var timeStepsToMove = 1
                let moveTimeStepResult = moveTimeStep(timeSteps: timeStepsToMove)
                if !moveTimeStepResult {
                    timeStepsToMove = !isStartTimePinned ? 0 - startTimeStepIndex : 0 - (endTimeStepIndex - startTimeStepIndex - 1)
                    moveTimeStep(timeSteps: timeStepsToMove)
                }
            case .backward:
                var timeStepsToMove = -1
                let moveTimeStepResult = moveTimeStep(timeSteps: timeStepsToMove)
                if !moveTimeStepResult {
                    if let ts = timeSteps {
                        timeStepsToMove = !isEndTimePinned ? ts.count - endTimeStepIndex - 1
                            : endTimeStepIndex - startTimeStepIndex - 1
                        moveTimeStep(timeSteps: timeStepsToMove)
                    }
                }
            }
        case .reverse:
            switch playbackDirection {
            case .forward:
                let moveTimeStepResult = moveTimeStep(timeSteps: 1)
                if !moveTimeStepResult {
                    playbackDirection = .backward
                }
            case .backward:
                let moveTimeStepResult = moveTimeStep(timeSteps: -1)
                if !moveTimeStepResult {
                    playbackDirection = .forward
                }
            }
        }
    }
    
    // MARK: - Private Functions
    
    private func setupUI() {
        //
        // Set height constraint
        heightConstraint = heightAnchor.constraint(equalToConstant: heightConstraintConstant())
        heightConstraint?.isActive = true
        
        // Set background color
        backgroundColor = UIColor.lightGray.withAlphaComponent(0.7)
        
        // Set corner radius
        layer.cornerRadius = 10
        
        // Add track layer
        trackLayer.timeSlider = self
        trackLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(trackLayer)
        
        // Add tick layer
        tickMarkLayer.timeSlider = self
        tickMarkLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(tickMarkLayer)
        
        // Add lower thumb layer
        lowerThumbLayer.timeSlider = self
        lowerThumbLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(lowerThumbLayer)
        
        // Add upper thumb layer
        upperThumbLayer.timeSlider = self
        upperThumbLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(upperThumbLayer)
        
        // Add the minimum value label
        fullExtentStartTimeLabel.isHidden = !(fullExtentLabelsVisible && isSliderVisible)
        fullExtentStartTimeLabel.foregroundColor = fullExtentLabelColor.cgColor
        fullExtentStartTimeLabel.alignmentMode = kCAAlignmentCenter
        fullExtentStartTimeLabel.frame = CGRect.zero
        fullExtentStartTimeLabel.contentsScale = UIScreen.main.scale
        fullExtentStartTimeLabel.fontSize = fullExtentLabelFont.pointSize
        layer.addSublayer(fullExtentStartTimeLabel)
        
        // Add the minimum value label
        fullExtentEndTimeLabel.isHidden = !(fullExtentLabelsVisible && isSliderVisible)
        fullExtentEndTimeLabel.foregroundColor = fullExtentLabelColor.cgColor
        fullExtentEndTimeLabel.alignmentMode = kCAAlignmentCenter
        fullExtentEndTimeLabel.frame = CGRect.zero
        fullExtentEndTimeLabel.contentsScale = UIScreen.main.scale
        fullExtentEndTimeLabel.fontSize = fullExtentLabelFont.pointSize
        layer.addSublayer(fullExtentEndTimeLabel)
        
        // Add the lower value label
        currentExtentStartTimeLabel.isHidden = !(labelMode == .thumbs && isSliderVisible)
        currentExtentStartTimeLabel.foregroundColor = currentExtentLabelColor.cgColor
        currentExtentStartTimeLabel.alignmentMode = kCAAlignmentCenter
        currentExtentStartTimeLabel.frame = CGRect.zero
        currentExtentStartTimeLabel.contentsScale = UIScreen.main.scale
        currentExtentStartTimeLabel.fontSize = currentExtentLabelFont.pointSize
        layer.addSublayer(currentExtentStartTimeLabel)
        
        // Add the upper value label
        currentExtentEndTimeLabel.isHidden = !(labelMode == .thumbs && isSliderVisible)
        currentExtentEndTimeLabel.foregroundColor = currentExtentLabelColor.cgColor
        currentExtentEndTimeLabel.alignmentMode = kCAAlignmentCenter
        currentExtentEndTimeLabel.frame = CGRect.zero
        currentExtentEndTimeLabel.contentsScale = UIScreen.main.scale
        currentExtentEndTimeLabel.fontSize = currentExtentLabelFont.pointSize
        layer.addSublayer(currentExtentEndTimeLabel)
        
        // Create the images
        let bundle = Bundle(for: type(of: self))
        playImage = UIImage(named: "Play", in: bundle, compatibleWith: nil)
        pauseImage = UIImage(named: "Pause", in: bundle, compatibleWith: nil)
        forwardImage = UIImage(named: "Forward", in: bundle, compatibleWith: nil)
        backImage = UIImage(named: "Back", in: bundle, compatibleWith: nil)
        
        // Add Play/Pause button
        let p = UIButton(type: .custom)
        p.setBackgroundImage(playImage, for: .normal)
        p.addTarget(self, action: #selector(TimeSlider.playPauseAction(_:)), for: .touchUpInside)
        p.showsTouchWhenHighlighted = true
        addSubview(p)
        playPauseButton = p
        
        // Add forward button
        let f = UIButton(type: .custom)
        f.setBackgroundImage(forwardImage, for: .normal)
        f.addTarget(self, action: #selector(TimeSlider.forwardAction(_:)), for: .touchUpInside)
        f.showsTouchWhenHighlighted = true
        addSubview(f)
        forwardButton = f
        
        // Add forward button
        let b = UIButton(type: .custom)
        b.setBackgroundImage(backImage, for: .normal)
        b.addTarget(self, action: #selector(TimeSlider.backAction(_:)), for: .touchUpInside)
        b.showsTouchWhenHighlighted = true
        addSubview(b)
        backButton = b
        
        // Refresh
        refresh()
    }
    
    private func refresh() {
        //
        // Calculate time steps
        if let timeSteps = self.timeSteps, timeSteps.isEmpty || self.timeSteps == nil {
            calculateTimeSteps()
        }
        
        // Update frames
        updateLayerFrames()
        
        // Update labels
        updateFullExtentLabelFrames()
        updateCurrentExtentLabelFrames()
    }
    
    private func updateLayerFrames() {
        //
        // Begin the transaction
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Set frames for slider components
        // only if slider is visible
        if isSliderVisible {
            //
            var trackLayerOriginY = bounds.midY + 20
            if !isPlaybackButtonsVisible {
                trackLayerOriginY = bounds.midY - CGFloat(trackHeight / 2)
            }
            
            // Set track layer frame
            let trackLayerOrigin = CGPoint(x: trackLayerSidePadding, y: trackLayerOriginY)
            let trackLayerSize = CGSize(width: bounds.width - trackLayerSidePadding * 2, height: CGFloat(trackHeight))
            let trackLayerFrame = CGRect(origin: trackLayerOrigin, size: trackLayerSize)
            trackLayer.frame = trackLayerFrame
            trackLayer.setNeedsDisplay()
            
            // Set track layer frame
            let tickMarkLayerFrame = trackLayerFrame.insetBy(dx: 0.0, dy: -10.0)
            tickMarkLayer.frame = tickMarkLayerFrame
            tickMarkLayer.setNeedsDisplay()
            
            // Update tick marks
            positionTickMarks()
            
            // Set lower thumb layer frame
            if let startTime = currentExtentStartTime, fullExtent != nil {
                let lowerThumbCenter = CGFloat(position(for: startTime.timeIntervalSince1970))
                let lowerThumbOrigin = CGPoint(x: trackLayerSidePadding + lowerThumbCenter - thumbSize.width / 2.0, y: trackLayerFrame.midY - thumbSize.height / 2.0)
                let lowerThumbFrame = CGRect(origin: lowerThumbOrigin, size: thumbSize)
                lowerThumbLayer.isHidden = !self.isSliderVisible
                lowerThumbLayer.frame = lowerThumbFrame
                lowerThumbLayer.setNeedsDisplay()
            }
            else {
                lowerThumbLayer.isHidden = true
            }
            
            // Set upper thumb layer frame
            if let endTime = currentExtentEndTime, isRangeEnabled, fullExtent != nil  {
                let upperThumbCenter = CGFloat(position(for: endTime.timeIntervalSince1970))
                let upperThumbOrigin = CGPoint(x: trackLayerSidePadding + upperThumbCenter - thumbSize.width / 2.0, y: trackLayerFrame.midY - thumbSize.height / 2.0)
                let upperThumbFrame = CGRect(origin: upperThumbOrigin, size: thumbSize)
                self.upperThumbLayer.isHidden = !self.isSliderVisible
                upperThumbLayer.frame = upperThumbFrame
                upperThumbLayer.setNeedsDisplay()
            }
            else {
                upperThumbLayer.isHidden = true
            }
        }
        
        // Set frames for playback buttons
        // if they are visible
        if isPlaybackButtonsVisible {
            //
            // Set frames for buttons
            let paddingBetweenButtons: CGFloat = 2.0
            let buttonSize = CGSize(width: 48, height: 48)
            
            // Set frame for play pause button
            var playPauseButtonOrigin = CGPoint(x: bounds.midX - buttonSize.width / 2.0, y: bounds.minY + 8)
            if !isSliderVisible {
                playPauseButtonOrigin = CGPoint(x: bounds.midX - buttonSize.width / 2.0, y: bounds.midY - buttonSize.height / 2.0)
            }
            playPauseButton?.frame = CGRect(origin: playPauseButtonOrigin, size: buttonSize)
            
            // Set frame for forward button
            let forwardButtonOrigin = CGPoint(x: playPauseButtonOrigin.x + buttonSize.width + paddingBetweenButtons, y: playPauseButtonOrigin.y)
            forwardButton?.frame = CGRect(origin: forwardButtonOrigin, size: buttonSize)
            
            // Set frame for back button
            let backButtonOrigin = CGPoint(x: playPauseButtonOrigin.x - paddingBetweenButtons - buttonSize.width, y: playPauseButtonOrigin.y)
            backButton?.frame = CGRect(origin: backButtonOrigin, size: buttonSize)
        }
        
        // Commit the transaction
        CATransaction.commit()
    }
    
    private func updateFullExtentLabelFrames() {
        //
        // If full extent labels are not
        // visible then bail out.
        if !fullExtentLabelsVisible {
            return
        }
        
        //
        // Begin the transaction
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        //
        // Update full extent start time label
        if let fullExtentStartTime = fullExtent?.startTime {
            //
            let startTimeString = fullExtentDateFormatter.string(from: fullExtentStartTime)
            fullExtentStartTimeLabel.string = startTimeString
            fullExtentStartTimeLabel.isHidden = !(fullExtentLabelsVisible && isSliderVisible)
            let startTimeLabelSize: CGSize = startTimeString.size(attributes: [NSFontAttributeName: fullExtentLabelFont])
            var startTimeLabelX = trackLayer.frame.minX - (startTimeLabelSize.width / 2)
            if startTimeLabelX < bounds.minX + labelSidePadding {
                startTimeLabelX = bounds.minX + labelSidePadding
            }
            
            let thumbStartTimeLabelY = lowerThumbLayer.frame.maxY + labelPadding
            let tickLayerStartTimeLabelY = tickMarkLayer.frame.maxY + labelPadding
            let startTimeLabelY = max(thumbStartTimeLabelY, tickLayerStartTimeLabelY)
            fullExtentStartTimeLabel.frame = CGRect(x: startTimeLabelX, y: startTimeLabelY, width: startTimeLabelSize.width, height: startTimeLabelSize.height)
        }
        else {
            fullExtentStartTimeLabel.string = ""
            fullExtentStartTimeLabel.isHidden = true
        }
        
        // Update full extent end time label
        if let fullExtentEndTime = fullExtent?.endTime {
            //
            let endTimeString = fullExtentDateFormatter.string(from: fullExtentEndTime)
            fullExtentEndTimeLabel.string = endTimeString
            fullExtentEndTimeLabel.isHidden = !(fullExtentLabelsVisible && isSliderVisible)
            let endTimeLabelSize: CGSize = endTimeString.size(attributes: [NSFontAttributeName: fullExtentLabelFont])
            var endTimeLabelX = trackLayer.frame.maxX - (fullExtentEndTimeLabel.frame.width / 2)
            if endTimeLabelX + endTimeLabelSize.width > bounds.maxX - labelSidePadding {
                endTimeLabelX = bounds.maxX - endTimeLabelSize.width - labelSidePadding
            }
            
            let thumbEndTimeLabelY = lowerThumbLayer.frame.maxY + labelPadding
            let tickLayerEndTimeLabelY = tickMarkLayer.frame.maxY + labelPadding
            let endTimeLabelY = max(thumbEndTimeLabelY, tickLayerEndTimeLabelY)
            fullExtentEndTimeLabel.frame = CGRect(x: endTimeLabelX, y: endTimeLabelY, width: endTimeLabelSize.width, height: endTimeLabelSize.height)
        }
        else {
            fullExtentEndTimeLabel.string = ""
            fullExtentEndTimeLabel.isHidden = true
        }
        
        // Commit the transaction
        CATransaction.commit()
    }
    
    private func updateCurrentExtentLabelFrames() {
        //
        // If label mode is not thumbs then
        // hide the current extent labels and
        // bail out.
        if labelMode != .thumbs {
            currentExtentStartTimeLabel.isHidden = true
            currentExtentEndTimeLabel.isHidden = true
            return
        }
        
        //
        // Begin the transaction
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        //
        // Update lower label
        if let startTime = currentExtentStartTime, fullExtent != nil  {
            let startTimeString = currentExtentDateFormatter.string(from: startTime)
            currentExtentStartTimeLabel.string = startTimeString
            let startTimeLabelSize: CGSize = startTimeString.size(attributes: [NSFontAttributeName: currentExtentLabelFont] )
            var startTimeLabelX = lowerThumbLayer.frame.midX - startTimeLabelSize.width / 2
            currentExtentStartTimeLabel.isHidden = !isSliderVisible
            if startTimeLabelX < bounds.origin.x + labelSidePadding {
                startTimeLabelX = bounds.origin.x + labelSidePadding
                currentExtentStartTimeLabel.isHidden = true
            }
            else if startTimeLabelX + startTimeLabelSize.width > bounds.maxX - labelSidePadding && currentExtentStartTime == currentExtentEndTime {
                startTimeLabelX = bounds.maxX - startTimeLabelSize.width - labelSidePadding
                currentExtentStartTimeLabel.isHidden = true
            }
            else if !currentExtentEndTimeLabel.isHidden && currentExtentEndTimeLabel.frame.origin.x >= 0.0 && startTimeLabelX + startTimeLabelSize.width > currentExtentEndTimeLabel.frame.origin.x {
                startTimeLabelX = currentExtentEndTimeLabel.frame.origin.x - startTimeLabelSize.width - paddingBetweenLabels
            }
            
            let thumbStartTimeLabelY = lowerThumbLayer.frame.minY - currentExtentStartTimeLabel.frame.height - labelPadding
            let tickLayerStartTimeLabelY = tickMarkLayer.frame.minY - currentExtentStartTimeLabel.frame.height - labelPadding
            let startTimeLabelY = min(thumbStartTimeLabelY, tickLayerStartTimeLabelY)
            currentExtentStartTimeLabel.frame = CGRect(x: startTimeLabelX, y: startTimeLabelY, width: startTimeLabelSize.width, height: startTimeLabelSize.height)
        }
        else {
            currentExtentStartTimeLabel.string = ""
            currentExtentStartTimeLabel.isHidden = true
        }
        
        // Update upper label
        if let endTime = currentExtentEndTime, isRangeEnabled, fullExtent != nil  {
            let endTimeString = currentExtentDateFormatter.string(from: endTime)
            currentExtentEndTimeLabel.string = endTimeString
            let endTimeLabelSize: CGSize = endTimeString.size(attributes: [NSFontAttributeName: currentExtentLabelFont] )
            var endTimeLabelX = upperThumbLayer.frame.midX - endTimeLabelSize.width / 2
            currentExtentEndTimeLabel.isHidden = !isSliderVisible
            if endTimeLabelX < bounds.origin.x + labelSidePadding && currentExtentStartTime == currentExtentEndTime {
                endTimeLabelX = bounds.origin.x + labelSidePadding
                currentExtentEndTimeLabel.isHidden = true
            }
            else if endTimeLabelX + endTimeLabelSize.width > bounds.maxX - labelSidePadding {
                endTimeLabelX = bounds.maxX - endTimeLabelSize.width - labelSidePadding
                currentExtentEndTimeLabel.isHidden = true
            }
            else if endTimeLabelX < currentExtentStartTimeLabel.frame.origin.x + currentExtentStartTimeLabel.frame.width {
                endTimeLabelX = currentExtentStartTimeLabel.frame.origin.x + currentExtentStartTimeLabel.frame.width + paddingBetweenLabels
            }
            
            let thumbEndTimeLabelY = upperThumbLayer.frame.minY - currentExtentEndTimeLabel.frame.height - labelPadding
            let tickLayerEndTimeLabelY = tickMarkLayer.frame.minY - currentExtentEndTimeLabel.frame.height - labelPadding
            let endTimeLabelY = min(thumbEndTimeLabelY, tickLayerEndTimeLabelY)
            currentExtentEndTimeLabel.frame = CGRect(x: endTimeLabelX, y: endTimeLabelY, width: endTimeLabelSize.width, height: endTimeLabelSize.height)
        }
        else {
            currentExtentEndTimeLabel.string = ""
            currentExtentEndTimeLabel.isHidden = true
        }
        
        // Commit the transaction
        CATransaction.commit()
    }
    
    private func positionTickMarks() {
        //
        // Bail out if time steps are not available
        guard let timeSteps = timeSteps, timeSteps.count > 0, isSliderVisible else {
            return
        }
        
        // Create tick marks based on
        // time steps and it's calculated
        // position on the slider
        var tms = [TickMark]()
        for i in 0..<timeSteps.count  {
            let timeStep = timeSteps[i]
            let tickX = CGFloat(position(for: timeStep.timeIntervalSince1970))
            tms.append(TickMark(originX: tickX, value: timeStep))
        }
        
        // If label mode is ticks then we need to
        // find out the major/minor ticks and
        // add labels for major ticks
        if labelMode == .ticks {
            var majorTickInterval = 2
            var doMajorTickLabelsCollide = false
            var firstMajorTickIndex = 0
            let tickCount = tms.count
            
            // Calculate the largest number of ticks to allow between major ticks. This prevents scenarios where
            // there are two major ticks placed undesirably close to the end.
            let maxMajorTickInterval = Int(ceil(Double(tickCount / 2)))
            
            // Calculate the number of ticks between each major tick and the index of the first major tick
            for i in majorTickInterval..<maxMajorTickInterval  {
                let prospectiveInterval = i
                var allowsEqualNumberOfTicksOnEnds = false
                
                // Check that the prospective interval between major ticks results in
                // an equal number of minor ticks on both ends.
                for m in stride(from: prospectiveInterval, to: tickCount, by: prospectiveInterval) {
                    let totalNumberOfTicksOnEnds = tickCount - m + 1
                    
                    // If the total number of minor ticks on both ends (i.e. before and after the
                    // first and last major ticks) is less than the major tick interval being tested, then we've
                    // found the number of minor ticks that would be on the ends if we use this major tick interval.
                    // If that total is divisible by two, then the major tick interval under test allows for an
                    // equal number of minor ticks on the ends.
                    if (totalNumberOfTicksOnEnds / 2 < prospectiveInterval && totalNumberOfTicksOnEnds % 2 == 0) {
                        allowsEqualNumberOfTicksOnEnds = true
                        break
                    }
                }
                
                // Only consider intervals that leave an equal number of ticks on the ends
                if !allowsEqualNumberOfTicksOnEnds {
                    continue
                }
                
                // Calculate the tick index of the first major tick if we were to use the prospective interval.
                // The index is calculated such that there will be an equal number of minor ticks before and
                // after the first and last major tick mark.
                firstMajorTickIndex = Int(trunc((Double(tickCount - 1).truncatingRemainder(dividingBy: Double(prospectiveInterval))) / 2.0))
                
                // With the given positioning of major tick marks, check whether their labels will overlap.
                for j in stride(from: firstMajorTickIndex, to: tickCount - prospectiveInterval, by: i) {
                    //
                    // Get the current tick and it's label
                    let currentTick = tms[j]
                    var currentTickLabelFrame: CGRect? = nil
                    if let currentTickDate = currentTick.value, let currentTickXPosition = currentTick.originX {
                        let currentTickLabelString = timeStepIntervalDateFormatter.string(from: currentTickDate)
                        let currentTickLabel = tickMarkLabel(with: currentTickLabelString, originX: currentTickXPosition)
                        currentTickLabelFrame = currentTickLabel.frame
                    }
                    
                    // Get the next tick and it's label
                    let nextTick = tms[j + i]
                    var nextTickLabelFrame: CGRect? = nil
                    if let nextTickDate = nextTick.value, let nextTickXPosition = nextTick.originX {
                        let nextTickLabelString = timeStepIntervalDateFormatter.string(from: nextTickDate)
                        let nextTickLabel = tickMarkLabel(with: nextTickLabelString, originX: nextTickXPosition)
                        nextTickLabelFrame = nextTickLabel.frame
                    }
                    
                    // Check whether labels overlap with each other or not.
                    if let currentTickLabelFrame = currentTickLabelFrame, let nextTickLabelFrame = nextTickLabelFrame {
                        if currentTickLabelFrame.maxX + paddingBetweenLabels > nextTickLabelFrame.minX {
                            doMajorTickLabelsCollide = true
                            break
                        }
                    }
                }
                
                if (!doMajorTickLabelsCollide) {
                    //
                    // The ticks don't at the given interval, so use that
                    majorTickInterval = prospectiveInterval
                    break
                }
            }
            
            if (doMajorTickLabelsCollide) {
                //
                // Multiple major tick labels won't fit without overlapping.
                // Display one major tick in the middle instead
                majorTickInterval = tickCount
                
                // Calculate the index of the middle tick. Note that, if there are an even number of ticks, there
                // is not one perfectly centered. This logic takes the one before the true center of the slider.
                if (tickCount % 2 == 0) {
                    firstMajorTickIndex = Int(trunc(Double(tickCount / 2)) - 1)
                }
                else {
                    firstMajorTickIndex = Int(trunc(Double(tickCount / 2)))
                }
            }
            
            // Remove existing tick mark labels
            // from layer so we can add new ones.
            removeTickMarkLabels()
            
            // Add tick mark labels except
            // start and end tick marks.
            for i in 1..<tickCount - 1  {
                //
                // Get the tick mark
                let tickMark = tms[i]
                
                // Calculate whether it is a major tick or not.
                tickMark.isMajorTick = (i - firstMajorTickIndex) % majorTickInterval == 0
                
                // Get the label for tick mark and add it to the display.
                if let tickMarkDate = tickMark.value, let tickMarkXPosition = tickMark.originX, tickMark.isMajorTick {
                    let tickMarkLabelString = timeStepIntervalDateFormatter.string(from: tickMarkDate)
                    let label = tickMarkLabel(with: tickMarkLabelString, originX: tickMarkXPosition)
                    tickMarkLabels.append(label)
                    layer.addSublayer(label)
                }
            }
        }
        
        // Set tick marks array
        tickMarks = tms
    }
    
    // MARK: - Observer
    
    private func addObservers() {
        if isObserving {
            removeObservers()
        }
        map?.addObserver(self, forKeyPath: #keyPath(AGSMap.operationalLayers), options: [.new, .old], context: &TimeSlider.KVOContext)
        scene?.addObserver(self, forKeyPath: #keyPath(AGSScene.operationalLayers), options: [.new, .old], context: &TimeSlider.KVOContext)
        geoView?.addObserver(self, forKeyPath: #keyPath(AGSGeoView.timeExtent), options: .new, context: &TimeSlider.KVOContext)
        isObserving = true
    }
    
    private func removeObservers() {
        if isObserving {
            map?.removeObserver(self, forKeyPath: #keyPath(AGSMap.operationalLayers))
            scene?.removeObserver(self, forKeyPath: #keyPath(AGSScene.operationalLayers))
            geoView?.removeObserver(self, forKeyPath: #keyPath(AGSGeoView.timeExtent))
            isObserving = false
        }
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &TimeSlider.KVOContext{
            if keyPath == #keyPath(AGSMap.operationalLayers) {
                //
                // Re initialize time slider if the change contains time aware layer.
                if let geoView = geoView, changeContainsTimeAwareLayer(change: change) {
                    initializeTimeProperties(geoView: geoView, completion: { (error) in
                        guard error == nil else {
                            print("error: \(String(describing: error))")
                            return
                        }
                    })
                }
            }
            else if keyPath == #keyPath(AGSGeoView.timeExtent) {
                if let geoViewTimeExtent = geoView?.timeExtent, let currentExtent = currentExtent {
                    if geoViewTimeExtent.startTime?.timeIntervalSince1970 != currentExtent.startTime?.timeIntervalSince1970 || geoViewTimeExtent.endTime?.timeIntervalSince1970 != currentExtent.endTime?.timeIntervalSince1970 {
                        self.currentExtent = geoViewTimeExtent
                    }
                }
            }
        }
        else{
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Helper Functions
    
    private func value(for position: Double) -> Double {
        //
        // Bail out if full extent start and end times are not available
        var resultValue : Double = 0.0
        guard let  fullExtentStartTime = fullExtent?.startTime, let fullExtentEndTime = fullExtent?.endTime else {
            return resultValue
        }
        
        // Find percentage of the position on the slider
        let percentage: CGFloat = (CGFloat(position) - trackLayer.bounds.minX - thumbSize.width / 2) / (trackLayer.bounds.maxX + thumbSize.width / 2 - trackLayer.bounds.minX - thumbSize.width / 2)
        
        // Calculate the value based on percentage
        resultValue = Double(percentage) * (fullExtentEndTime.timeIntervalSince1970 - fullExtentStartTime.timeIntervalSince1970) + fullExtentStartTime.timeIntervalSince1970
        
        // Return result
        return resultValue
    }
    
    fileprivate func position(for value: Double) -> Double {
        //
        // Bail out if full extent start and end times are not available
        var resultPosition: Double = 0.0
        guard let fullExtentStartTime = fullExtent?.startTime, let fullExtentEndTime = fullExtent?.endTime, fullExtentStartTime != fullExtentEndTime else {
            return resultPosition
        }
        
        // Calculate the position based on value
        resultPosition = Double(trackLayer.bounds.width) * (value - fullExtentStartTime.timeIntervalSince1970) / (fullExtentEndTime.timeIntervalSince1970 - fullExtentStartTime.timeIntervalSince1970)
        
        // Return result
        return resultPosition
    }
    
    private func boundCurrentExtentStartTime(value: Double) -> Double {
        //
        // Result value
        var resultValue: Double = 0.0
        
        // If range is enabled valid value needs to be between
        // full extent start time and current extent end time.
        if isRangeEnabled {
            //
            // Bail out if start and end times are not available
            guard let startTime = fullExtent?.startTime, let endTime = currentExtent?.endTime else {
                return resultValue
            }
            
            // Get the result value
            resultValue = min(max(value, startTime.timeIntervalSince1970), endTime.timeIntervalSince1970)
        }
        else { // Else, the valid value needs to be between full extent start and end times.
            //
            // Bail out if start and end times are not available
            guard let startTime = fullExtent?.startTime, let endTime = fullExtent?.endTime else {
                return resultValue
            }
            
            // Get the result value
            resultValue = min(max(value, startTime.timeIntervalSince1970), endTime.timeIntervalSince1970)
        }
        
        // Return result
        return resultValue
    }
    
    private func boundCurrentExtentEndTime(value: Double) -> Double {
        //
        // The valid value needs to be between current
        // extent start and full extent end times.
        // Bail out if they are not available.
        var resultValue: Double = 0.0
        guard let startTime = currentExtent?.startTime, let endTime = fullExtent?.endTime else {
            return resultValue
        }
        
        // Get the result value
        resultValue = min(max(value, startTime.timeIntervalSince1970), endTime.timeIntervalSince1970)
        
        // Return result
        return resultValue
    }
    
    private func calculateTimeSteps() {
        //
        // To calculate the time steps, full extent's start time, end time and valid time step interval must be available.
        // Bail out if they are not available.
        guard let fullExtentStartTime = fullExtent?.startTime, let fullExtentEndTime = fullExtent?.endTime, let timeInterval = timeStepInterval, timeInterval.duration > 0.0, let (duration, component) = timeInterval.toCalenderComponents() else {
            return
        }
        
        // Get the date range from the start and end times.
        let calendar = Calendar(identifier: .gregorian)
        let dateRange = calendar.dateRange(startDate: fullExtentStartTime, endDate: fullExtentEndTime, component: component , step: Int(duration))
        
        // Set time steps from the date range
        timeSteps = Array(dateRange)
    }
    
    private func tickMarkLabel(with string: String, originX: CGFloat) -> CATextLayer {
        //
        // Set label properties
        let tickMarkLabel = CATextLayer()
        tickMarkLabel.foregroundColor = timeStepIntervalLabelColor.cgColor
        tickMarkLabel.alignmentMode = kCAAlignmentCenter
        tickMarkLabel.contentsScale = UIScreen.main.scale
        tickMarkLabel.fontSize = timeStepIntervalLabelFont.pointSize
        tickMarkLabel.string = string
        
        // Calculate the size of the label based on the string and font
        let tickMarkLabelSize: CGSize = string.size(attributes: [NSFontAttributeName: timeStepIntervalLabelFont])
        
        // The tick mark labels are displayed on the top side of the slider track.
        // So, it's y position needs to be minimum value of calculated either based on
        // tick mark layer or thumb size.
        let layerOriginY = tickMarkLayer.frame.minY - tickMarkLabelSize.height - labelPadding
        let thumbOriginY = lowerThumbLayer.frame.minY - tickMarkLabelSize.height - labelPadding
        let originY = min(layerOriginY, thumbOriginY)
        
        // Set the label frame
        tickMarkLabel.frame = CGRect(x: originX, y: originY, width: tickMarkLabelSize.width, height: tickMarkLabelSize.height)
        
        // Return label
        return tickMarkLabel
    }
    
    private func closestTimeStep(for date: Date) ->  (index: Int, date: Date)? {
        //
        // Return nil if not able to find the closest time step for the provided date.
        guard let closest = timeSteps?.enumerated().min( by: { abs($0.1.timeIntervalSince1970 - date.timeIntervalSince1970) < abs($1.1.timeIntervalSince1970 - date.timeIntervalSince1970)} ) else {
            return nil
        }
        
        // Return closes date and it's index
        return (closest.offset, closest.element)
    }
    
    private func removeTickMarkLabels() {
        //
        // Remove layers from the view
        tickMarkLabels.forEach({ (tickMarkLabel) in
            tickMarkLabel.removeFromSuperlayer()
        })
        
        // Clear the array
        tickMarkLabels.removeAll()
    }
    
    // Notifies the change in value of current extent
    private func notifyChangeOfCurrentExtent() {
        //
        // Notify only if current date are different than previous dates.
        if (previousCurrentExtentStartTime != currentExtentStartTime || previousCurrentExtentEndTime != currentExtentEndTime) {
            //
            // Update previous values
            previousCurrentExtentStartTime = currentExtentStartTime
            previousCurrentExtentEndTime = currentExtentEndTime
            
            // Notify the change of dates
            sendActions(for: .valueChanged)
            
            // If geoView is available update it's time extent
            if let geoView = geoView {
                geoView.timeExtent = currentExtent
            }
        }
    }
    
    // Returns value of height constraint constant
    private func heightConstraintConstant() -> CGFloat {
        //
        // The constant value is based on whether
        // slider and/or playback buttons are visible
        if isSliderVisible && isPlaybackButtonsVisible {
            return 140.0
        }
        else if isSliderVisible && !isPlaybackButtonsVisible {
            return 100.0
        }
        else {
            return 60.0
        }
    }
    
    private func updateCurrentExtent(_ timeExtent: AGSTimeExtent) {
        //
        // Set a flag that this is an internal update
        // so we don't update the isRangeEnabled flag
        internalUpdate = true
        currentExtent = timeExtent
        internalUpdate = false
    }
    
    private func updateCurrentExtentStartTime(_ startTime: Date) {
        //
        // Make sure the time is within full extent
        let startTime = Date(timeIntervalSince1970: boundCurrentExtentStartTime(value: startTime.timeIntervalSince1970))
        
        // Update start time only if it is different than current
        if startTime != currentExtentStartTime {
            //
            // If time steps are available then snap it to the closest time step and set the index.
            if let ts = timeSteps, ts.count > 0 {
                if let (index, date) = closestTimeStep(for: startTime) {
                    currentExtentStartTime = date
                    startTimeStepIndex = index
                }
            }
            else {
                currentExtentStartTime = startTime
                startTimeStepIndex = -1
            }
        }
    }
    
    private func updateCurrentExtentEndTime(_ endTime: Date) {
        //
        // Make sure the time is within full extent
        let endTime = Date(timeIntervalSince1970: boundCurrentExtentEndTime(value: endTime.timeIntervalSince1970))
        
        // Update end time only if it is different than current
        if endTime != currentExtentEndTime {
            //
            // If time steps are available then snap it to the closest time step and set the index.
            if let ts = timeSteps, ts.count > 0 {
                if let (index, date) = closestTimeStep(for: endTime) {
                    currentExtentEndTime = date
                    endTimeStepIndex = index
                }
            }
            else {
                currentExtentEndTime = endTime
                endTimeStepIndex = -1
            }
        }
    }
    
    // Finds
    
    private func findTimeStepIntervalAndIsRangeTimeFilteringSupported(for timeAwareLayer: AGSTimeAware, completion: @escaping ((timeStepInterval: AGSTimeValue?, supportsRangeTimeFiltering: Bool)?)->Void) {
        //
        // The default is true
        var supportsRangeTimeFiltering = true
        
        // Get the time interval of the layer
        var timeStepInterval = timeAwareLayer.timeInterval
        
        // If the layer is map image layer then we need to find out details from the
        // sublayers. Let's load all sublayers and check whether sub layers supports
        // range time filtering and largets time step interval.
        if let mapImageLayer = timeAwareLayer as? AGSArcGISMapImageLayer {
            AGSLoadObjects(mapImageLayer.mapImageSublayers as! [AGSLoadable], { [weak self] (loaded) in
                if loaded {
                    var timeInterval: AGSTimeValue?
                    for i in 0..<mapImageLayer.mapImageSublayers.count {
                        if let sublayer = mapImageLayer.mapImageSublayers[i] as? AGSArcGISSublayer, sublayer.isVisible, let timeInfo = self?.timeInfo(for: sublayer) {
                            //
                            // If either start or end time field name is not available then
                            // set supportsRangeTimeFiltering to false
                            if timeInfo.startTimeField.count <= 0 || timeInfo.endTimeField.count <= 0 {
                                supportsRangeTimeFiltering = false
                            }
                            
                            // Need to find the largest time step interval from
                            // sub layers only if it is not available on the layer.
                            if timeStepInterval == nil, let interval1 = timeInfo.interval {
                                if let interval2 = timeInterval {
                                    timeInterval = interval1.isGreaterThan(otherTimeValue: interval2) ? interval1 : interval2
                                }
                                else {
                                    timeInterval = interval1
                                }
                            }
                        }
                    }
                    
                    // Update largest time step interval
                    // found from sub layers.
                    if timeStepInterval == nil, let timeInterval = timeInterval {
                        timeStepInterval = timeInterval
                    }
                }
                completion((timeStepInterval, supportsRangeTimeFiltering))
            })
        }
        else {
            //
            // If layer is not map image layer then find layer supports
            // range time filtering or not and set time step interval
            // from timeInfo if not available on the layer.
            if let timeAwareLayer = timeAwareLayer as? AGSLoadable, let timeInfo = timeInfo(for: timeAwareLayer) {
                if timeInfo.startTimeField.count <= 0 || timeInfo.endTimeField.count <= 0 {
                    supportsRangeTimeFiltering = false
                }
            }
            completion((timeStepInterval, supportsRangeTimeFiltering))
        }
    }
    
    // Returns layer's time info if available. The parameter cannot be of type AGSLayer because
    // ArcGISSublayer does not inherit from AGSLayer. It is expected that this function is
    // called on already loaded object
    private func timeInfo(for layer: AGSLoadable) -> AGSLayerTimeInfo? {
        //
        // The timeInfo is available on only raster, feature or sub layer.
        //
        // It is expected that this function is
        // called on already loaded object
        if layer.loadStatus == .loaded {
            if let sublayer = layer as? AGSArcGISSublayer {
                return sublayer.mapServiceSublayerInfo?.timeInfo
            }
            else if let featureLayer = layer as? AGSFeatureLayer, let featureTable = featureLayer.featureTable as? AGSArcGISFeatureTable {
                return featureTable.layerInfo?.timeInfo
            }
            else if let rasterLayer = layer as? AGSRasterLayer, let imageServiceRaster = rasterLayer.raster as? AGSImageServiceRaster {
                return imageServiceRaster.serviceInfo?.timeInfo
            }
        }
        return nil
    }
    
    // This function checks whether the observed value of operationalLayers
    // contains any time aware layer.
    private func changeContainsTimeAwareLayer(change: [NSKeyValueChangeKey : Any]?) -> Bool {
        let newValue = change?[NSKeyValueChangeKey.newKey] as? Array<AGSLayer>
        let oldValue = change?[NSKeyValueChangeKey.oldKey] as? Array<AGSLayer>
        
        if let newValue = newValue {
            for layer in newValue {
                if layer is AGSTimeAware {
                    return true
                }
            }
        }
        
        if let oldValue = oldValue {
            for layer in oldValue {
                if layer is AGSTimeAware {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Time Slider Thumb Layer

private class TimeSliderThumbLayer: CALayer {
    var isHighlighted = false {
        didSet {
            setNeedsDisplay()
        }
    }
    var isPinned = false {
        didSet {
            setNeedsDisplay()
        }
    }
    weak var timeSlider: TimeSlider?
    
    override func draw(in ctx: CGContext) {
        if let slider = timeSlider {
            var thumbFrame = bounds.insetBy(dx: 2.0, dy: 2.0)
            if isPinned {
                let size = CGSize(width: 12, height: 30)
                let origin = CGPoint(x: thumbFrame.midX - size.width / 2.0, y: thumbFrame.midY - size.height / 2.0)
                thumbFrame = CGRect(origin: origin, size: size)
            }
            let cornerRadius = thumbFrame.height * CGFloat(slider.thumbCornerRadius / 2.0)
            let thumbPath = UIBezierPath(roundedRect: thumbFrame, cornerRadius: cornerRadius)
            
            // Fill - with a subtle shadow
            let shadowColor = slider.thumbBorderColor.withAlphaComponent(0.4)
            let fillColor = isPinned ? slider.pinnedThumbFillColor.cgColor : slider.thumbFillColor.cgColor
            ctx.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 1.0, color: shadowColor.cgColor)
            ctx.setFillColor(fillColor)
            ctx.addPath(thumbPath.cgPath)
            ctx.fillPath()
            
            // Outline
            ctx.setStrokeColor(slider.thumbBorderColor.cgColor)
            ctx.setLineWidth(CGFloat(slider.thumbBorderWidth))
            ctx.addPath(thumbPath.cgPath)
            ctx.strokePath()
            
            if isHighlighted {
                ctx.setFillColor(UIColor(white: 0.0, alpha: 0.1).cgColor)
                ctx.addPath(thumbPath.cgPath)
                ctx.fillPath()
            }
        }
    }
}

// MARK: - Time Slider Track Layer

private class TimeSliderTrackLayer: CALayer {
    weak var timeSlider: TimeSlider?
    
    override func draw(in ctx: CGContext) {
        if let slider = timeSlider {
            //
            // Clip
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: 0.0)
            ctx.addPath(path.cgPath)
            
            // Fill the track
            ctx.setFillColor(slider.fullExtentFillColor.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            
            // Outline
            let outlineWidth = CGFloat(slider.fullExtentBorderWidth)
            ctx.setStrokeColor(slider.fullExtentBorderColor.cgColor)
            ctx.setLineWidth(outlineWidth)
            ctx.addPath(path.cgPath)
            ctx.strokePath()
            
            // Fill the layer track
            if let startTime = slider.layerExtent?.startTime, let endTime = slider.layerExtent?.endTime {
                let lowerValuePosition = CGFloat(slider.position(for: startTime.timeIntervalSince1970))
                let upperValuePosition = CGFloat(slider.position(for: endTime.timeIntervalSince1970))
                let rect = CGRect(x: lowerValuePosition, y: outlineWidth / 2.0, width: upperValuePosition - lowerValuePosition, height: bounds.height - outlineWidth)
                ctx.setFillColor(slider.layerExtentFillColor.cgColor)
                ctx.fill(rect)
            }
            
            // Fill the highlighted range
            ctx.setFillColor(slider.currentExtentFillColor.cgColor)
            if let startTime = slider.currentExtent?.startTime, let endTime = slider.currentExtent?.endTime {
                let lowerValuePosition = CGFloat(slider.position(for: startTime.timeIntervalSince1970))
                let upperValuePosition = CGFloat(slider.position(for: endTime.timeIntervalSince1970))
                let rect = CGRect(x: lowerValuePosition, y: outlineWidth, width: upperValuePosition - lowerValuePosition, height: bounds.height - (outlineWidth * 2.0))
                ctx.fill(rect)
            }
        }
    }
}

// MARK: - Time Slider Tick Layer

private class TimeSliderTickMarkLayer: CALayer {
    weak var timeSlider: TimeSlider?
    private let endTickLinWidth: CGFloat = 6.0
    private let intermediateTickLinWidth: CGFloat = 2.0
    private let paddingBetweenTickMarks: CGFloat = 4.0
    
    override func draw(in ctx: CGContext) {
        if let slider = timeSlider {
            //
            // Clip
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: 0.0)
            ctx.addPath(path.cgPath)
            
            // If tick marks available render them.
            if let tickMarks = slider.tickMarks, let tickMarksCount = slider.tickMarks?.count {
                //
                // Set the tick color
                ctx.setStrokeColor(slider.timeStepIntervalTickColor.cgColor)
                
                // If there is not enough space to
                // render all tick marks then only
                // render first and last.
                if !isThereEnoughSpaceForTickMarks() {
                    ctx.setLineWidth(endTickLinWidth)
                    
                    ctx.beginPath()
                    let firstTickMark = tickMarks[0]
                    if let tickX = firstTickMark.originX {
                        ctx.move(to: CGPoint(x: CGFloat(tickX), y:bounds.midY - CGFloat(slider.trackHeight / 2)))
                        ctx.addLine(to: CGPoint(x: CGFloat(tickX), y: bounds.midY + bounds.height / 2))
                    }
                    ctx.strokePath()
                    
                    ctx.beginPath()
                    let lastTickMark = tickMarks[tickMarksCount - 1]
                    if let tickX = lastTickMark.originX {
                        ctx.move(to: CGPoint(x: CGFloat(tickX), y:bounds.midY - CGFloat(slider.trackHeight / 2)))
                        ctx.addLine(to: CGPoint(x: CGFloat(tickX), y: bounds.midY + bounds.height / 2))
                    }
                    ctx.strokePath()
                }
                else {
                    // Loop through all tick marks
                    // and render them.
                    for i in 0..<tickMarksCount {
                        let tickMark = tickMarks[i]
                        if let tickX = tickMark.originX {
                            ctx.beginPath()
                            
                            // First and last tick marks are
                            // rendered differently than others
                            if i == 0 || i == tickMarksCount - 1  {
                                ctx.setLineWidth(endTickLinWidth)
                                ctx.move(to: CGPoint(x: CGFloat(tickX), y:bounds.midY - CGFloat(slider.trackHeight / 2)))
                                ctx.addLine(to: CGPoint(x: CGFloat(tickX), y: bounds.midY + bounds.height / 2))
                            }
                            else {
                                ctx.setLineWidth(intermediateTickLinWidth)
                                ctx.move(to: CGPoint(x: CGFloat(tickX), y:bounds.midY - CGFloat(slider.trackHeight / 2)))
                                let tickY = tickMark.isMajorTick ? bounds.midY - bounds.height / 2 : bounds.midY - bounds.height / 3
                                ctx.addLine(to: CGPoint(x: CGFloat(tickX), y: tickY))
                            }
                            ctx.strokePath()
                        }
                    }
                }
            }
        }
    }
    
    // Checks whether there is enough space to render all tick marks
    private func isThereEnoughSpaceForTickMarks() -> Bool {
        if let tickMarksCount = timeSlider?.tickMarks?.count {
            let requiredSpace = (CGFloat(tickMarksCount - 2) * (intermediateTickLinWidth + paddingBetweenTickMarks)) + (endTickLinWidth * 2.0)
            let availableSpace = bounds.width
            if availableSpace > requiredSpace {
                return true
            }
        }
        return false
    }
}

// MARK: - Tick Mark

private class TickMark {
    var originX: CGFloat?
    var value: Date?
    var isMajorTick: Bool = false
    var label: CATextLayer?
    
    init(originX: CGFloat, value: Date) {
        self.originX = originX
        self.value = value
    }
}

// MARK: - Image Extension

extension UIImage {
    //
    // Creates new image with given color
    func imageWithColor(_ color: UIColor) -> UIImage {
        //
        // Begin graphic image context and color
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        color.setFill()
        
        // Get the current context and apply
        // translate, scale and blend mode
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.translateBy(x: 0, y: size.height)
        ctx?.scaleBy(x: 1.0, y: -1.0)
        ctx?.setBlendMode(.normal)
        
        // Clip image to the size
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        if let cgImage = cgImage {
            ctx?.clip(to: rect, mask: cgImage)
        }
        
        // Fill with the current fill color.
        ctx?.fill(rect)
        
        // Create new image and end image context
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return self }
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

// MARK: - Calendar

private extension Calendar {
    //
    // Returns a date range between two provided dates with given component and step value
    func dateRange(startDate: Date, endDate: Date, component: Calendar.Component, step: Int) -> DateRange {
        let dateRange = DateRange(calendar: self, startDate: startDate, endDate: endDate, component: component, step: step, multiplier: 0, inclusive: true)
        return dateRange
    }
}

// MARK: - Date Range

private struct DateRange : Sequence, IteratorProtocol {
    var calendar: Calendar
    var startDate: Date
    var endDate: Date
    var component: Calendar.Component
    var step: Int
    var multiplier: Int
    var inclusive: Bool
    
    private func toSeconds(duration: Double, component: Calendar.Component) -> TimeInterval {
        switch component {
        case .era:
            break
        case .year:
            return TimeInterval(duration * 31556952)
        case .month:
            return TimeInterval(duration * 2629746)
        case .day:
            return TimeInterval(duration * 86400)
        case .hour:
            return TimeInterval(duration * 3600)
        case .minute:
            return TimeInterval(duration * 60)
        case .second:
            return TimeInterval(duration)
        case .weekday:
            break
        case .weekdayOrdinal:
            break
        case .quarter:
            break
        case .weekOfMonth:
            break
        case .weekOfYear:
            break
        case .yearForWeekOfYear:
            break
        case .nanosecond:
            return TimeInterval(duration / 1000000000)
        case .calendar:
            break
        case .timeZone:
            break
        }
        return 0
    }
    
    mutating func next() -> Date? {
        guard let nextDate = calendar.date(byAdding: component, value: step * multiplier, to: startDate) else {
            return nil
        }
        
        // If next date + half of the step value is greater than end date then return end date.
        // This will avoid the date being too close to the end date.
        if nextDate.timeIntervalSince1970 + (toSeconds(duration: Double(step), component: component) / 2.0) >= endDate.timeIntervalSince1970 {
            if inclusive {
                inclusive = false
                return endDate
            }
            else {
                return nil
            }
        } else {
            multiplier += 1
            return nextDate
        }
    }
}

// MARK: - Date Extension

extension Date {
    //
    // Returns the amount of years from another date
    func years(from date: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: date, to: self).year ?? 0
    }
    
    // Returns the amount of months from another date
    func months(from date: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }
    
    // Returns the amount of days from another date
    func days(from date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    // Returns the amount of hours from another date
    func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    
    // Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    
    // Returns the amount of seconds from another date
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    // Returns the amount of nanoseconds from another date
    func nanoseconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.nanosecond], from: date, to: self).nanosecond ?? 0
    }
    
    // Returns the a custom time interval and calender component from another date
    func offset(from date: Date) -> (duration: Int, component: Calendar.Component)? {
        if years(from: date)   > 0 { return (years(from: date), .year)   }
        if months(from: date)  > 0 { return (months(from: date), .month)  }
//        if days(from: date)    > 0 { return (days(from: date), .day)    }
//        if hours(from: date)   > 0 { return (hours(from: date), .hour)   }
//        if minutes(from: date) > 0 { return (minutes(from: date), .minute) }
        if seconds(from: date) > 0 { return (seconds(from: date), .second) }
        if nanoseconds(from: date) > 0 { return (nanoseconds(from: date), .nanosecond) }
        return nil
    }
    
}

// MARK: - Color Extension

extension UIColor {
    class func oceanBlue() -> UIColor {
        return UIColor(red: 0, green: 0.475, blue: 0.757, alpha: 1)
    }
    
    class func customBlue() -> UIColor {
        return UIColor(red: 0.0, green: 0.45, blue: 0.94, alpha: 1.0)
    }
    
    class func lightSkyBlue() -> UIColor {
        return UIColor(red: 0.529, green: 0.807, blue: 0.980, alpha: 1.0)
    }
}

// MARK: - Time Extent Extension

extension AGSTimeExtent {
    //
    // Union of two time extents
    func union(otherTimeExtent: AGSTimeExtent) -> AGSTimeExtent {
        if let startTime = startTime, let endTime = endTime, let otherStartTime = otherTimeExtent.startTime, let otherEndTime = otherTimeExtent.endTime {
            let newStartTime = startTime < otherStartTime ? startTime : otherStartTime
            let newEndTime = endTime > otherEndTime ? endTime : otherEndTime
            return AGSTimeExtent(startTime: newStartTime, endTime: newEndTime)
        }
        return self
    }
}

// MARK: - Time Value Extension

extension AGSTimeValue {
    //
    // Converts time value to the calender component values.
    public func toCalenderComponents() -> (duration: Double, component: Calendar.Component)? {
        switch unit {
        case .unknown:
            return nil
        case .centuries:
            return (duration * 100, Calendar.Component.year)
        case .days:
            return (duration, Calendar.Component.day)
        case .decades:
            return (duration * 10, Calendar.Component.year)
        case .hours:
            return (duration, Calendar.Component.hour)
        case .milliseconds:
            return (duration * 1000000, Calendar.Component.nanosecond)
        case .minutes:
            return (duration, Calendar.Component.minute)
        case .months:
            return (duration, Calendar.Component.month)
        case .seconds:
            return (duration, Calendar.Component.second)
        case .weeks:
            return (duration * 7, Calendar.Component.day)
        case .years:
            return (duration, Calendar.Component.year)
        }
    }
    
    // Compares two time values and returns result
    public func isGreaterThan(otherTimeValue: AGSTimeValue) -> Bool {
        return unit == otherTimeValue.unit ? duration > otherTimeValue.duration : toSeconds() > otherTimeValue.toSeconds()
    }
    
    // Converts time value to seconds
    public func toSeconds() -> TimeInterval {
        switch unit {
        case .unknown:
            return duration
        case .centuries:
            return duration * 3155695200
        case .days:
            return duration * 86400
        case .decades:
            return duration * 315569520
        case .hours:
            return duration * 3600
        case .milliseconds:
            return duration * 0.001
        case .minutes:
            return duration * 60
        case .months:
            return duration * 2629746
        case .seconds:
            return duration
        case .weeks:
            return duration * 604800
        case .years:
            return duration * 31556952
        }
    }
    
    // Returns time value generated from calender component and duration
    class func fromCalenderComponents(duration: Double, component: Calendar.Component) -> AGSTimeValue? {
        switch component {
        case .era:
            break
        case .year:
            return AGSTimeValue(duration: duration, unit: .years)
        case .month:
            return AGSTimeValue(duration: duration, unit: .months)
        case .day:
            return AGSTimeValue(duration: duration, unit: .days)
        case .hour:
            return AGSTimeValue(duration: duration, unit: .hours)
        case .minute:
            return AGSTimeValue(duration: duration, unit: .minutes)
        case .second:
            return AGSTimeValue(duration: duration, unit: .seconds)
        case .weekday:
            break
        case .weekdayOrdinal:
            break
        case .quarter:
            break
        case .weekOfMonth:
            break
        case .weekOfYear:
            break
        case .yearForWeekOfYear:
            break
        case .nanosecond:
            return AGSTimeValue(duration: duration / 1000000, unit: .milliseconds)
        case .calendar:
            break
        case .timeZone:
            break
        }
        return nil
    }
}