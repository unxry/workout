import UIKit

struct PreparedImagePayload: Equatable {
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int

    var dataURLPrefix: String {
        "data:\(mimeType);base64,"
    }
}

enum ImagePreparationService {
    static func prepareJPEG(from image: UIImage, maxPixel: CGFloat = 1_280, compression: CGFloat = 0.78) throws -> PreparedImagePayload {
        let resized = resize(image, maxPixel: maxPixel)
        guard let data = resized.jpegData(compressionQuality: compression) else {
            throw ImagePreparationError.encodingFailed
        }
        return PreparedImagePayload(
            data: data,
            mimeType: "image/jpeg",
            pixelWidth: Int(resized.size.width * resized.scale),
            pixelHeight: Int(resized.size.height * resized.scale)
        )
    }

    static func resize(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longestSide = max(pixelWidth, pixelHeight)

        guard longestSide > maxPixel else { return image.normalizedOrientation() }

        let scaleRatio = maxPixel / longestSide
        let targetPixelSize = CGSize(width: pixelWidth * scaleRatio, height: pixelHeight * scaleRatio)
        let targetPointSize = CGSize(width: targetPixelSize.width / image.scale, height: targetPixelSize.height / image.scale)

        let renderer = UIGraphicsImageRenderer(size: targetPointSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPointSize))
        }
    }
}

enum ImagePreparationError: LocalizedError, Equatable {
    case encodingFailed

    var errorDescription: String? {
        "Не удалось подготовить изображение."
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
