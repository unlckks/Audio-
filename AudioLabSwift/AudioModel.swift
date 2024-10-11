import Foundation
import Accelerate

class AudioModel {
    // MARK: - Properties
    private var BUFFER_SIZE: Int           // Buffer size for audio processing
    var timeData: [Float]                  // Time-domain audio data
    var fftData: [Float]                   // Frequency-domain data (FFT result)
    var maxDataSize20: [Float]             // Array to hold maximum frequency amplitude data

    var sineFrequency: Float = 17000.0     // Sine wave frequency for playback
    private var sinePhase: Float = 0.0     // Sine wave phase for audio output
    private var sineWaveBuffer: [Float]    // Buffer to store sine wave samples
    
    private var lastDetectedFrequencies: (Float, Float)? = nil  // Stores last detected prominent frequencies
                  

    // Initializer
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
        maxDataSize20 = Array(repeating: 0.0, count: 20)
        sineWaveBuffer = Array(repeating: 0.0, count: BUFFER_SIZE)
    }
    
    // MARK: - Public Methods
    // Start microphone processing at a given frames-per-second (FPS) rate
    func startMicrophoneProcessing(withFps: Double) {
        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }
    
    // Start sine wave processing for playback at a specific frequency
    func startProcessingSinewaveForPlayback(withFreq frequency: Float) {
        self.sineFrequency = frequency
        self.audioManager?.outputBlock = self.handleOutputSinewave
    }
    
    // Update the sine wave frequency in real-time
    func updateSineFrequency(_ frequency: Float) {
        print("Updating sine frequency to: \(frequency)")  // Debugging: Ensure the method is called
        self.sineFrequency = frequency
    }

    // Play audio
    func play() {
        self.audioManager?.play()
    }
    
    // Pause audio
    func pause() {
        self.audioManager?.pause()
    }
    
    
    func getMaxToneFromFFT() -> (Float, Float)? {
        let sampleRate: Float = 44100.0
        let minThreshold: Float = 0.1  // Minimum magnitude threshold to filter out noise
        let minSeparation: Float = 50.0  // Minimum frequency separation in Hz
        var maxTone1: (index: Int, magnitude: Float)? = nil
        var maxTone2: (index: Int, magnitude: Float)? = nil

        // Flag to detect if any valid tones were found
        var foundValidTones = false

        for i in 1..<fftData.count {
            let magnitude = fftData[i]

            // Only consider magnitudes above the noise threshold
            guard magnitude >= minThreshold else { continue }

            foundValidTones = true // We found a valid tone

            if let currentMax1 = maxTone1 {
                // If current magnitude is larger than maxTone1, shift it to maxTone2
                if magnitude > currentMax1.magnitude {
                    maxTone2 = maxTone1
                    maxTone1 = (i, magnitude)
                } else if let currentMax2 = maxTone2 {
                    // Update maxTone2 if magnitude is larger and separated from maxTone1
                    if magnitude > currentMax2.magnitude && abs(Float(i - currentMax1.index)) * sampleRate / Float(BUFFER_SIZE) >= minSeparation {
                        maxTone2 = (i, magnitude)
                    }
                } else if abs(Float(i - currentMax1.index)) * sampleRate / Float(BUFFER_SIZE) >= minSeparation {
                    // Directly update maxTone2 if there's a valid separation and no previous maxTone2
                    maxTone2 = (i, magnitude)
                }
            } else {
                // Initialize maxTone1 with the first valid magnitude
                maxTone1 = (i, magnitude)
            }
        }

        // Ensure both maxTone1 and maxTone2 are set, else return the last detected frequencies
        if foundValidTones, let frequency1 = maxTone1, let frequency2 = maxTone2 {
            // Convert indices to actual frequency values
            let freq1 = Float(frequency1.index) * sampleRate / Float(BUFFER_SIZE)
            let freq2 = Float(frequency2.index) * sampleRate / Float(BUFFER_SIZE)
            // Store the result for future use
            lastDetectedFrequencies = (freq1, freq2)
            return lastDetectedFrequencies
        }

        // Return nil if no valid tones were found
        return nil
    }


    

    // MARK: - Private Methods
    private lazy var audioManager: Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper: FFTHelper? = {
        return FFTHelper(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer: CircularBuffer? = {
        return CircularBuffer(numChannels: Int64(self.audioManager!.numInputChannels),
                              andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    // Periodic function to process the microphone input and perform FFT
    private func runEveryInterval() {
        if inputBuffer != nil {
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
        }
    }
    
    // Handle microphone input and add data to the input buffer
    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    // Handle sine wave output for playback
    private func handleOutputSinewave(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        guard let data = data else { return }
        let sineWaveFrequency = sineFrequency
        let samplingRate = Float(audioManager?.samplingRate ?? 44100)
        
        for i in 0..<Int(numFrames) {
            let sample = sin(2.0 * .pi * sinePhase)
            sinePhase += sineWaveFrequency / samplingRate
            if sinePhase > 1.0 { sinePhase -= 1.0 }
            
            for j in 0..<Int(numChannels) {
                data[i * Int(numChannels) + j] = sample
            }
        }
    }
}
