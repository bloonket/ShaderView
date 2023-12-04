    //
    //  File.swift
    //
    //
    //  Created by Pirita Minkkinen on 11/19/23.
    //

    import Foundation
    import XCTest
    @testable import ShaderView

    class MetalSwiftUIViewTests: XCTestCase {

       let shaderView = ShaderView()
        let customShaderInput = ShaderInput()
        let representable = MetalNSViewRepresentable(drawableSize: CGSize(width: 100, height: 100), fragmentShaderName: "defaultVertex", vertexShaderName: "defult", shaderInput: ShaderInput())
        //let metalRender = MetalRenderView<Input: ShaderInput()>(coder: NSCoder())
        
        func testShaderViewInit() {
            XCTAssertNotNil(shaderView, "ShaderView should be able to initialize.")
        }
     

    }
