//
//  AudioModelB.swift
//  Created by mingyun zhang on 10/2/24.
//
//

import Foundation

class AudioModelB: NSObject {
    
    // MARK: - Properties
    public var sineFrequency: Float          // Frequency for sine wave generation
    private var bufferSize: Int              // Buffer size for audio processing
    private var leftMovement = false         // Tracks movement towards the microphone
    private var rightMovement = false        // Tracks movement away from the microphone
    private var motionCheckAllowed = true    // Ensures motion detection is not too frequent
    private var peakIndex = 0                // Index of the peak frequency in FFT data
    private let motionWindow = 10            // Window size for motion detection
    var timeData: [Float]                    // Buffer for time-domain data (raw audio)
    var fftData: [Float]                     // Buffer for frequency-domain data (FFT result)
    
    // Lazy-loaded audio manager and FFT helpers
    private lazy var audioManager: Novocaine? = Novocaine.audioManager()
    private lazy var fftHelper: FFTHelper? = FFTHelper(fftSize: Int32(bufferSize))
    private lazy var inputBuffer: CircularBuffer? = CircularBuffer(numChannels: Int64(audioManager?.numInputChannels ?? 1), andBufferSize: Int64(bufferSize))
    
    // Peak frequency history for detecting motion
    var peakFrequencyHistory: [Float] = []   // Stores recent peak frequencies
    let historyLength = 5                    // Length of history used for motion detection
    let frequencyThreshold: Float = 10.0     // Threshold for detecting significant frequency change
    
    // MARK: - Initializer
    init(bufferSize: Int, sineFrequency: Float) {
        self.bufferSize = bufferSize
        self.sineFrequency = sineFrequency
        self.timeData = Array(repeating: 0.0, count: bufferSize)
        self.fftData = Array(repeating: 0.0, count: bufferSize / 2)
    }

    // MARK: - Accessors for movement detection
    func getLeftMovement() -> Bool { return leftMovement }
    func getRightMovement() -> Bool { return rightMovement }

    // MARK: - Set Frequency
    // Adjust sine wave frequency for Doppler effect detection
    func setFrequency(frequency: Float) {
        self.sineFrequency = frequency
    }

    // MARK: - Start Audio Processing
    // Start processing microphone input and generating sinewave output
    func startMicrophoneProcessing(withFps fps: Double) {
        audioManager?.inputBlock = handleMicrophoneInput
        audioManager?.outputBlock = handleSinewaveOutput

        // Schedule a repeating task to process audio data at the specified FPS
        Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            self.processAudioData()
        }
    }

    // Play the sine wave audio
    func play() {
        audioManager?.play()
    }

    // MARK: - Audio Data Processing
    // Fetch new audio data, perform FFT, and calculate motion
    private func processAudioData() {
        inputBuffer?.fetchFreshData(&timeData, withNumSamples: Int64(bufferSize))
        fftHelper?.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
        calculateMotion()
    }

    // MARK: - Calculate Motion
    // Detects motion towards or away from the microphone using frequency changes
    func calculateMotion() {
        guard let samplingRate = audioManager?.samplingRate else { return }

        // Find the index of the peak frequency in FFT data
        guard let maxIndex = fftData.firstIndex(of: fftData.max() ?? 0) else { return }
        
        // Convert the index to actual frequency
        let frequencyResolution = Float(samplingRate) / Float(fftData.count)
        let peakFrequency = Float(maxIndex) * frequencyResolution
        
        // Update peak frequency history
        peakFrequencyHistory.append(peakFrequency)
        if peakFrequencyHistory.count > historyLength {
            peakFrequencyHistory.removeFirst()
        }
        
        // Check if we have enough history to detect a trend
        if peakFrequencyHistory.count == historyLength {
            // Calculate frequency change over time
            let frequencyChange = peakFrequencyHistory.last! - peakFrequencyHistory.first!
            
            if frequencyChange > frequencyThreshold {
                // Frequency increased: moving towards the microphone
                leftMovement = true
                rightMovement = false
            } else if frequencyChange < -frequencyThreshold {
                // Frequency decreased: moving away from the microphone
                leftMovement = false
                rightMovement = true
            } else {
                // No significant frequency change detected
                leftMovement = false
                rightMovement = false
            }
        }
        
        // Limit motion detection frequency to avoid continuous checking
        motionCheckAllowed = false
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.motionCheckAllowed = true
        }
    }

    // MARK: - Microphone Input Handling
    // Handle microphone input data and store it in the input buffer
    private func handleMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
        inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    // MARK: - Sinewave Output Handling
    // Generate sinewave audio output for Doppler effect detection
    private func handleSinewaveOutput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
        guard let outputData = data else { return }

        let amplitude: Float = 10.0
        let phaseIncrement = Float(2 * Double.pi * Double(sineFrequency) / (audioManager?.samplingRate ?? 44100.0))
        var phase: Float = 0.0

        for i in 0..<Int(numFrames) {
            outputData[i] = sin(phase) * amplitude
            phase += phaseIncrement
            if phase >= Float(2 * Double.pi) { phase -= Float(2 * Double.pi) }
        }
    }
}
