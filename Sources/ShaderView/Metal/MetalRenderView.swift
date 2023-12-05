//
//  MetalRenderView.swift
//A view for rendering graphics using Metal's shader and rendering capabilities.
//
//  Created by Pirita Minkkinen on 8/22/23.
//

import MetalKit
import SwiftUI
import Combine


/// `MetalRenderView` is a subclass of `MTKView` and conforms to `MTKViewDelegate`.
/// It is designed to integrate Metal's rendering capabilities into a SwiftUI environment.
///
/// - Note: This class is intended for use as part of the package and may not be suitable for standalone use.
///         It relies on other components in the package for full functionality.
class MetalRenderView: MTKView, MTKViewDelegate {
    @ObservedObject var shaderViewModel: ShaderViewModel
    private var shaderInputSubscription: AnyCancellable?
    
    private var vertexShaderName: String = "" //think of making these let
    private var fragmentShaderName: String = ""
    private var shaderInput: any ShaderInputProtocol
    //private var isTimeCountingActive: Bool = true
    
    var startTime: Date = Date()
    var elapsedTime: Float = 0.0
    
    private var vertexBuffer: MTLBuffer?
    var renderPipelineState: MTLRenderPipelineState?
    
    
    /// Initializes a `MetalRenderView` with a given shader view model.
    /// This initializer configures the view with necessary shader names and inputs for Metal rendering.
    /// - Parameters:
    ///   - shaderViewModel: A `ShaderViewModel` instance containing essential data like shader names and input parameters.
    init(shaderViewModel: ShaderViewModel) {
        self.shaderViewModel = shaderViewModel
        self.fragmentShaderName = shaderViewModel.fragmentShaderName
        self.vertexShaderName = shaderViewModel.vertexShaderName
        self.shaderInput = shaderViewModel.shaderInput.copy()
        super.init(frame: .zero, device: DeviceManager.shared.device)
        
       
        setupMetal()
        subscribeToShaderInput()
    }
    
    /// Required initializer for decoding. Not intended for direct use.
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the Metal environment for the view. This includes initializing the render pipeline state
    /// with vertex and fragment shaders from the shader library.
    /// - Note: Real-time shader compilation features, if added, may trigger errors captured here.
    private func setupMetal() {
        guard let device = DeviceManager.shared.device else {
            ShaderViewLogger.error("Metal is not supported on this device")
            fatalError("Metal is not supported on this device")
        }
        
        guard
            let vertexFunction = ShaderLibrary.shared.retrieveShader(forKey: vertexShaderName),
            let fragmentFunction = ShaderLibrary.shared.retrieveShader(forKey: fragmentShaderName)
        else {
            ShaderViewLogger.error("Metal is not supported on this device")
            fatalError("Failed to retrieve shaders")
        }
        
        // Set up the render pipeline, currently same for every shader but maybe consider making it changeable
        setupRenderPipeline(device: device, vertexFunction: vertexFunction, fragmentFunction: fragmentFunction)
    }
    
    
    /// Configures the render pipeline with specified vertex and fragment shaders.
    /// - Parameters:
    ///   - device: The Metal device used to create the pipeline.
    ///   - vertexFunction: The vertex shader function.
    ///   - fragmentFunction: The fragment shader function.
    /// - Note: This method currently sets a uniform pipeline for all shaders, but can be extended for more flexibility.
    private func setupRenderPipeline(device: MTLDevice, vertexFunction: MTLFunction, fragmentFunction: MTLFunction){
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError("Failed to create pipeline state, error: \(error)")
        }
    }
    
    
    /// Subscribes to changes in `shaderInput` from `ShaderViewModel`.
    /// Updates the view's shader input when a change occurs
    private func subscribeToShaderInput() {
        shaderInputSubscription = shaderViewModel.$shaderInput
            .sink { [weak self] newShaderInput in
                if !(newShaderInput is ShaderInput) {  // Check if newShaderInput is not of type ShaderInput
                    self?.updateShaderInput(newShaderInput)
                }
            }
    }
    
    
    /// Updates `shaderInput` in response to changes, preserving certain properties like time.
    /// - Parameters:
    ///   - newShaderInput: The updated shader input received from `ShaderViewModel`.
    private func updateShaderInput(_ newShaderInput: any ShaderInputProtocol) {
        // Update shaderInput and any other relevant properties
        let currentTime = shaderInput.time

        // Create a copy of newShaderInput
        self.shaderInput = newShaderInput.copy()

        // Restore the preserved time to the new copy
        self.shaderInput.time = currentTime

        // Trigger any necessary rendering update here
    }
    
    
    /// Renders content for each frame.
    /// - Parameter view: The `MTKView` responsible for displaying the content.
    func draw(in view: MTKView) {
        self.render()
    }
    
    
    /// Responds to changes in the view's drawable size.
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    /// Overrides `drawableSize` to trigger a redraw correctly on both macOS and iOS.
    override var drawableSize: CGSize {
        didSet {
#if os(macOS)
            needsDisplay = true
#else
            setNeedsDisplay()
#endif
            
        }
    }
    
    /// Executes the rendering process for the current frame.
    private func render() {
        guard let drawable = currentDrawable,
              let commandBuffer = DeviceManager.shared.commandQueue?.makeCommandBuffer(),
              let renderPipelineState = self.renderPipelineState else {
            ShaderViewLogger.error("Failed to get necessary Metal objects for rendering")
            return
        }
        
        //if(isTimeCountingActive){
        let currentTime = Date()
        self.elapsedTime = Float(currentTime.timeIntervalSince(startTime))
        shaderInput.time = elapsedTime
        //}
        
        
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Failed to create Render Command Encoder.")
            return
        }
        
        
        var viewport = Viewport(size: vector_float2(Float(self.drawableSize.width), Float(self.drawableSize.height)))
        
        
        
        let viewportBuffer = device?.makeBuffer(bytes: &viewport, length: MemoryLayout<Viewport>.size, options: [])
        
        
        //first buffer viewportbuffer second other stuff like variables
        renderEncoder.setVertexBuffer(viewportBuffer, offset: 0, index: 0)  // Use the next available index
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        
        //TODO: decide on the size, possibly set possibility to change its size
        let bufferSize = 3 * 1024 // 4KB in bytes should be more than enough for any 2d shader use, consider reducing
        let buffer = device?.makeBuffer(bytes: &shaderInput, length:  bufferSize, options: [])
        renderEncoder.setFragmentBuffer(viewportBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    
}


