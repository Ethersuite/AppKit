import WalletConnectUtils
import Foundation
import Combine
import JSONRPC
import XCTest
@testable import WalletConnectRelay

final class RelayClientTests: XCTestCase {

    var sut: RelayClient!
    var dispatcher: DispatcherMock!

    override func setUp() {
        dispatcher = DispatcherMock()
        let logger = ConsoleLogger()
        sut = RelayClient(dispatcher: dispatcher, logger: logger, keyValueStorage: RuntimeKeyValueStorage())
    }

    override func tearDown() {
        sut = nil
        dispatcher = nil
    }

    func testNotifyOnSubscriptionRequest() {
        let subscriptionExpectation = expectation(description: "notifies with encoded message on a iridium subscription event")
        let topic = "0987"
        let message = "qwerty"
        let subscriptionId = "sub-id"
        let subscriptionParams = RelayJSONRPC.SubscriptionParams(id: subscriptionId, data: RelayJSONRPC.SubscriptionData(topic: topic, message: message))
        let subscriptionRequest = JSONRPCRequest<RelayJSONRPC.SubscriptionParams>(id: 12345, method: RelayJSONRPC.Method.subscription.method, params: subscriptionParams)
        sut.onMessage = { subscriptionTopic, subscriptionMessage in
            XCTAssertEqual(subscriptionMessage, message)
            XCTAssertEqual(subscriptionTopic, topic)
            subscriptionExpectation.fulfill()
        }
        dispatcher.onMessage?(try! subscriptionRequest.json())
        waitForExpectations(timeout: 0.001, handler: nil)
    }

    func testSubscribeRequestAcknowledge() {
        let acknowledgeExpectation = expectation(description: "")
        sut.subscribe(topic: "") { error in
            XCTAssertNil(error)
            acknowledgeExpectation.fulfill()
        }
        let request = dispatcher.getLastRequestSent()
        let response = RPCResponse(matchingRequest: request, result: "id")
        dispatcher.onMessage?(try! response.asJSONEncodedString())
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testPublishRequestAcknowledge() {
        let acknowledgeExpectation = expectation(description: "completion with no error on iridium request acknowledge after publish")
        sut.publish(topic: "", payload: "{}", tag: 0) { error in
            XCTAssertNil(error)
            acknowledgeExpectation.fulfill()
        }
        let request = dispatcher.getLastRequestSent()
        let response = RPCResponse(matchingRequest: request, result: true)
        dispatcher.onMessage?(try! response.asJSONEncodedString())
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testUnsubscribeRequestAcknowledge() {
        let acknowledgeExpectation = expectation(description: "completion with no error on iridium request acknowledge after unsubscribe")
        let topic = String.randomTopic()
        sut.subscriptions[topic] = ""
        sut.unsubscribe(topic: topic) { error in
            XCTAssertNil(error)
            acknowledgeExpectation.fulfill()
        }
        let request = dispatcher.getLastRequestSent()
        let response = RPCResponse(matchingRequest: request, result: true)
        dispatcher.onMessage?(try! response.asJSONEncodedString())
        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testSubscriptionRequestDeliveredOnce() {
        let expectation = expectation(description: "Request duplicate not delivered")
        let subscriptionParams = RelayJSONRPC.SubscriptionParams(id: "sub_id", data: RelayJSONRPC.SubscriptionData(topic: "topic", message: "message"))
        let subscriptionRequest = JSONRPCRequest<RelayJSONRPC.SubscriptionParams>(id: 12345, method: RelayJSONRPC.Method.subscription.method, params: subscriptionParams)
        sut.onMessage = { _, _ in
            expectation.fulfill()
        }
        dispatcher.onMessage?(try! subscriptionRequest.json())
        dispatcher.onMessage?(try! subscriptionRequest.json())
        waitForExpectations(timeout: 0.001, handler: nil)
    }

    func testSendOnPublish() {
        sut.publish(topic: "", payload: "", tag: 0, onNetworkAcknowledge: { _ in})
        XCTAssertTrue(dispatcher.sent)
    }

    func testSendOnSubscribe() {
        sut.subscribe(topic: "") {_ in }
        XCTAssertTrue(dispatcher.sent)
    }

    func testSendOnUnsubscribe() {
        let topic = "123"
        sut.subscriptions[topic] = ""
        sut.unsubscribe(topic: topic) {_ in }
        XCTAssertTrue(dispatcher.sent)
    }
}
