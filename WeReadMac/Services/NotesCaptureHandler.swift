import WebKit
import os

final class NotesCaptureHandler: NSObject, WKScriptMessageHandler {
    private let logger = Logger(subsystem: "com.wereadmac.app", category: "NotesCaptureHandler")
    private let captureService: NotesCaptureService

    init(captureService: NotesCaptureService) {
        self.captureService = captureService
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            logger.warning("Received malformed message from JS bridge")
            return
        }

        let payload = body["body"] as? [String: Any] ?? [:]

        switch type {
        case "highlight":
            captureService.processHighlight(payload: payload, rawMessage: body)
        case "deleteHighlight":
            captureService.processDeleteHighlight(payload: payload)
        case "thought":
            captureService.processThought(payload: payload, rawMessage: body)
        case "updateThought":
            captureService.processThoughtUpdate(payload: payload, rawMessage: body)
        case "deleteThought":
            captureService.processDeleteThought(payload: payload)
        case "thoughtReviewId":
            captureService.processThoughtReviewId(payload: payload)
        case "bookInfo":
            captureService.processBookInfo(payload: payload)
        case "chapterInfos":
            captureService.processChapterInfos(payload: payload)
        case "bookmarkList":
            captureService.processBookmarkList(payload: payload)
        default:
            logger.info("Unknown message type: \(type)")
        }
    }
}
