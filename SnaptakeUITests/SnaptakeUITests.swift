//
//  SnaptakeUITests.swift
//  SnaptakeUITests
//
//  Created by Stephan Lerner on 14.04.18.
//  Copyright © 2018 Stephan Lerner. All rights reserved.
//

import XCTest

class SnaptakeUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        snapshot("0Launch")
    }
    
}
