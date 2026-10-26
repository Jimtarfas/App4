import Foundation
import UIKit

/// Sends the coin photos to the Coin Values identification service.
struct CoinIdentifier {
    enum IdentifyError: LocalizedError {
        case subscriptionRequired
        case notACoin
        case rateLimited
        case offline
        case server

        var errorDescription: String? {
            switch self {
            case .subscriptionRequired: "An active Coin Values Pro subscription is needed to identify coins."
            case .notACoin: "We couldn't find a coin in these photos. Try again with the coin centered, in good light."
            case .rateLimited: "You've scanned a lot of coins in the last hour. Please wait a little and try again."
            case .offline: "You appear to be offline. Connect to the internet and try again."
            case .server: "Something went wrong while identifying your coin. Please try again."
            }
        }
    }

    struct Request: Encodable {
        let front: String
        let back: String?
        let transaction: String?
    }

    var transactionJWS: String?

    func identify(front: Data, back: Data?) async throws -> CoinIdentification {
        var request = URLRequest(url: Links.api)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #if DEBUG
        if let token = Bundle.main.object(forInfoDictionaryKey: "DevBypassToken") as? String, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Dev-Token")
        }
        #endif
        request.httpBody = try JSONEncoder().encode(Request(
            front: front.base64EncodedString(),
            back: back?.base64EncodedString(),
            transaction: transactionJWS
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(error.code) {
            throw IdentifyError.offline
        } catch {
            throw IdentifyError.server
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            guard let result = try? JSONDecoder().decode(CoinIdentification.self, from: data) else { throw IdentifyError.server }
            guard result.isCoin, !result.name.isEmpty else { throw IdentifyError.notACoin }
            return result
        case 402: throw IdentifyError.subscriptionRequired
        case 422: throw IdentifyError.notACoin
        case 429: throw IdentifyError.rateLimited
        default: throw IdentifyError.server
        }
    }
}

enum ImageProcessing {
    /// Longest side of the photos sent for identification. The server rejects anything over 800 px.
    static let uploadSize: CGFloat = 768

    /// Crops the square around the on-screen guide circle (plus a margin) and scales it down.
    /// The preview fills the screen (aspect fill), so both are centred on the same point.
    static func prepareCameraPhoto(_ image: UIImage, previewSize: CGSize, guideDiameter: CGFloat) -> UIImage {
        let upright = image.normalizedOrientation()
        guard let cgImage = upright.cgImage, previewSize.width > 0, previewSize.height > 0 else { return upright }
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let previewScale = max(previewSize.width / width, previewSize.height / height)
        let side = min(min(width, height), guideDiameter * 1.25 / previewScale)
        let rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side).integral
        guard let cropped = cgImage.cropping(to: rect) else { return upright }
        return UIImage(cgImage: cropped).scaled(toMaxSide: uploadSize)
    }

    /// Library photos are scaled without cropping, since the coin may be anywhere in the frame.
    static func prepareLibraryPhoto(_ image: UIImage) -> UIImage {
        image.normalizedOrientation().scaled(toMaxSide: uploadSize)
    }

    static func jpeg(_ image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.82)
    }
}

extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(at: .zero) }
    }

    func scaled(toMaxSide maxSide: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale, pixelHeight = size.height * scale
        let factor = min(1, maxSide / max(pixelWidth, pixelHeight))
        let target = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
