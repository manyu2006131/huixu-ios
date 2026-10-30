import XCTest
final class HuixuUITests:XCTestCase {
    func testTextLayerPersistenceAndUndo() throws {
        continueAfterFailure=false
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(app.buttons["添加文字"].waitForExistence(timeout:10))
        app.buttons["添加文字"].tap()
        let text=app.textFields["输入文字"];XCTAssertTrue(text.waitForExistence(timeout:5))
        text.tap();text.typeText("Magic editor")
        app.alerts.buttons["添加"].tap()
        app.buttons["图层与调整"].tap()
        XCTAssertTrue(app.buttons["文字 · Magic editor"].waitForExistence(timeout:5))
        app.buttons["完成"].tap()
        app.buttons["撤销"].tap()
        app.buttons["图层与调整"].tap()
        XCTAssertTrue(app.staticTexts["还没有图层"].waitForExistence(timeout:5))
        app.buttons["完成"].tap();app.buttons["重做"].tap()
        app.buttons["一键清空涂鸦"].tap()
        app.buttons["清空笔迹及文字"].tap()
        app.buttons["图层与调整"].tap()
        XCTAssertTrue(app.staticTexts["还没有图层"].waitForExistence(timeout:5))
        app.buttons["完成"].tap();app.buttons["撤销"].tap()
        app.terminate();app.launch();app.buttons["图层与调整"].tap()
        XCTAssertTrue(app.buttons["文字 · Magic editor"].waitForExistence(timeout:5))
    }
}
