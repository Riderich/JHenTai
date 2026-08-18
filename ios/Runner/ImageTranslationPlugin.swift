import Flutter
import UIKit
import Vision

final class ImageTranslationPlugin: NSObject, FlutterPlugin {
  private static let channelName = "top.jtmonster.jhentai.image_translation"
  private let workerQueue = DispatchQueue(
    label: "com.riderich.jhentai.translation.image-translation",
    qos: .userInitiated
  )

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = ImageTranslationPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "recognizeJapanese":
      recognize(call, result: result)
    case "renderTranslations":
      render(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func recognize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let imageData: Data
    do {
      imageData = try requiredImageData(from: call)
    } catch {
      result(flutterError(code: "INVALID_IMAGE", error: error))
      return
    }

    workerQueue.async {
      do {
        let regions = try self.recognizeJapanese(in: imageData)
        self.finish(result, value: regions)
      } catch {
        self.finish(
          result,
          value: self.flutterError(code: "OCR_FAILED", error: error)
        )
      }
    }
  }

  private func render(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let imageData: Data
    let regions: [[String: Any]]
    do {
      imageData = try requiredImageData(from: call)
      guard
        let arguments = call.arguments as? [String: Any],
        let decodedRegions = arguments["regions"] as? [[String: Any]]
      else {
        throw ImageTranslationError.missingRegions
      }
      regions = decodedRegions
    } catch {
      result(flutterError(code: "INVALID_ARGUMENTS", error: error))
      return
    }

    workerQueue.async {
      autoreleasepool {
        do {
          let output = try self.renderTranslations(
            on: imageData,
            regions: regions
          )
          self.finish(result, value: FlutterStandardTypedData(bytes: output))
        } catch {
          self.finish(
            result,
            value: self.flutterError(code: "RENDER_FAILED", error: error)
          )
        }
      }
    }
  }

  private func recognizeJapanese(in data: Data) throws -> [[String: Any]] {
    guard let decodedImage = UIImage(data: data) else {
      throw ImageTranslationError.unreadableImage
    }
    let image = try normalizedImage(decodedImage)
    guard let cgImage = image.cgImage else {
      throw ImageTranslationError.unreadableImage
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.minimumTextHeight = 0.002

    let supportedLanguages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
      for: .accurate,
      revision: request.revision
    )
    guard supportedLanguages.contains("ja-JP") else {
      throw ImageTranslationError.japaneseRecognitionUnavailable
    }
    request.recognitionLanguages = ["ja-JP"]

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
    try handler.perform([request])

    let pixelWidth = CGFloat(cgImage.width)
    let pixelHeight = CGFloat(cgImage.height)
    let regions = (request.results ?? []).compactMap { observation -> [String: Any]? in
      guard let candidate = observation.topCandidates(1).first else {
        return nil
      }
      let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else {
        return nil
      }

      let normalized = observation.boundingBox
      let x = max(0, Int((normalized.minX * pixelWidth).rounded()))
      let y = max(0, Int(((1 - normalized.maxY) * pixelHeight).rounded()))
      let width = min(
        Int(pixelWidth) - x,
        max(1, Int((normalized.width * pixelWidth).rounded()))
      )
      let height = min(
        Int(pixelHeight) - y,
        max(1, Int((normalized.height * pixelHeight).rounded()))
      )
      guard width > 1, height > 1 else {
        return nil
      }
      return [
        "text": text,
        "x": x,
        "y": y,
        "width": width,
        "height": height,
        "confidence": candidate.confidence,
      ]
    }

    return regions.sorted { lhs, rhs in
      let leftY = (lhs["y"] as? NSNumber)?.intValue ?? 0
      let rightY = (rhs["y"] as? NSNumber)?.intValue ?? 0
      if abs(leftY - rightY) > 8 {
        return leftY < rightY
      }
      let leftX = (lhs["x"] as? NSNumber)?.intValue ?? 0
      let rightX = (rhs["x"] as? NSNumber)?.intValue ?? 0
      return leftX > rightX
    }
  }

  private func renderTranslations(
    on data: Data,
    regions: [[String: Any]]
  ) throws -> Data {
    guard let decodedImage = UIImage(data: data) else {
      throw ImageTranslationError.unreadableImage
    }
    let image = try normalizedImage(decodedImage)
    guard let cgImage = image.cgImage else {
      throw ImageTranslationError.unreadableImage
    }

    let canvasSize = CGSize(
      width: CGFloat(cgImage.width),
      height: CGFloat(cgImage.height)
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
    let rendered = renderer.image { context in
      let bounds = CGRect(origin: .zero, size: canvasSize)
      image.draw(in: bounds)
      for region in regions {
        self.draw(region: region, in: bounds, context: context.cgContext)
      }
    }
    guard let output = rendered.pngData(), !output.isEmpty else {
      throw ImageTranslationError.emptyRenderedImage
    }
    return output
  }

  private func draw(
    region: [String: Any],
    in canvasBounds: CGRect,
    context: CGContext
  ) {
    let translation = (region["translation"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !translation.isEmpty else {
      return
    }

    let x = number(region["x"])
    let y = number(region["y"])
    let width = number(region["width"])
    let height = number(region["height"])
    let padding = max(4, min(canvasBounds.width, canvasBounds.height) / 500)
    let requestedRect = CGRect(
      x: x - padding,
      y: y - padding,
      width: width + padding * 2,
      height: height + padding * 2
    )
    let rect = requestedRect.intersection(canvasBounds).integral
    guard !rect.isNull, rect.width > 1, rect.height > 1 else {
      return
    }

    context.saveGState()
    context.setFillColor(UIColor.white.cgColor)
    context.fill(rect)
    context.restoreGState()

    let font = fittedFont(for: translation, in: rect.size)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byCharWrapping
    paragraph.lineSpacing = font.pointSize * 0.08
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: UIColor.black,
      .paragraphStyle: paragraph,
    ]
    let textBounds = (translation as NSString).boundingRect(
      with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    ).integral
    let drawRect = CGRect(
      x: rect.minX,
      y: rect.midY - min(textBounds.height, rect.height) / 2,
      width: rect.width,
      height: rect.height
    )
    (translation as NSString).draw(
      with: drawRect,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
  }

  private func fittedFont(for text: String, in size: CGSize) -> UIFont {
    var fontSize = min(160, max(12, min(size.width, size.height)))
    while fontSize >= 10 {
      let font = UIFont.systemFont(ofSize: fontSize)
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byCharWrapping
      paragraph.lineSpacing = fontSize * 0.08
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraph,
      ]
      let bounds = (text as NSString).boundingRect(
        with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes,
        context: nil
      )
      if bounds.height <= size.height && bounds.width <= size.width + 1 {
        return font
      }
      fontSize -= 2
    }
    return UIFont.systemFont(ofSize: 10)
  }

  private func normalizedImage(_ image: UIImage) throws -> UIImage {
    let pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
    let pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)
    guard pixelWidth > 0, pixelHeight > 0 else {
      throw ImageTranslationError.unreadableImage
    }
    if image.imageOrientation == .up, image.cgImage != nil {
      return image
    }

    let size = CGSize(width: pixelWidth, height: pixelHeight)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  private func requiredImageData(from call: FlutterMethodCall) throws -> Data {
    guard
      let arguments = call.arguments as? [String: Any],
      let typedData = arguments["image"] as? FlutterStandardTypedData,
      !typedData.data.isEmpty
    else {
      throw ImageTranslationError.missingImage
    }
    return typedData.data
  }

  private func number(_ value: Any?) -> CGFloat {
    CGFloat((value as? NSNumber)?.doubleValue ?? 0)
  }

  private func finish(_ result: @escaping FlutterResult, value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  private func flutterError(code: String, error: Error) -> FlutterError {
    FlutterError(
      code: code,
      message: error.localizedDescription,
      details: String(describing: error)
    )
  }
}

private enum ImageTranslationError: LocalizedError {
  case missingImage
  case missingRegions
  case unreadableImage
  case japaneseRecognitionUnavailable
  case emptyRenderedImage

  var errorDescription: String? {
    switch self {
    case .missingImage:
      return "Missing manga image data"
    case .missingRegions:
      return "Missing translated text regions"
    case .unreadableImage:
      return "Unable to decode the manga page"
    case .japaneseRecognitionUnavailable:
      return "Japanese OCR is unavailable on this iOS version"
    case .emptyRenderedImage:
      return "The iOS renderer returned an empty image"
    }
  }
}
