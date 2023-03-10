import Foundation

public enum TinyLog {
  public static var stripParameters: Bool = true
  public static var isShowInfoLog = true
  public static var isShowErrorLog = true
  public static var filterString: String?
  
  static var isTestFlight: Bool {
    if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, appStoreReceiptURL.lastPathComponent == "sandboxReceipt" {
      return true
    } else {
      return false
    }
  }
  
  #if DEBUG
  public static var profilingStartTime: TimeInterval = 0
  public static var profilingTagTime: TimeInterval = 0
  #endif
  public static func startProfiling() {
    #if DEBUG
    profilingStartTime = Date().timeIntervalSince1970
    profilingTagTime = profilingStartTime
    print("[Profiling] Start")
    #endif
  }
  public static func tagProfiling(_ message: String? = nil) {
    #if DEBUG
    guard profilingStartTime > 0 else { return }
    let now = Date().timeIntervalSince1970
    let elapsed = TimeInterval(Int((now - profilingStartTime) * 1000)) / 1000
    let elapsedFromLastTag = TimeInterval(Int((now - profilingTagTime) * 1000)) / 1000
    profilingTagTime = now
    print("[Profiling][\(message ?? "")] Total: \(elapsed)s, Elapsed: \(elapsedFromLastTag)s")
    #endif
  }
  public static func stopProfiling() {
    #if DEBUG
    profilingStartTime = 0
    profilingTagTime = 0
    #endif
  }
  
  
  fileprivate static let queue = DispatchQueue(label: "TinyLog")
}

fileprivate class TinyLogDateFormatter {
  // MARK: Singleton
  fileprivate static let `default`: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()
}

fileprivate func fileName(_ filePath: String) -> String {
  let lastPathComponent = NSString(string: filePath).lastPathComponent
  if let name = lastPathComponent.components(separatedBy: ".").first {
    return name
  } else {
    return lastPathComponent
  }
}

fileprivate func functionNameByStrippingParameters(_ function: String) -> String {
  if let startIndex = function.firstIndex(of: "(") {
    return String(function[..<startIndex])
  } else {
    return function
  }
}

private func log(_ msg: Any? = nil, _ prefix: String = "???", _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  
  #if SIMULATOR
  let isUseConsoleLog: Bool = true
  #else
  #if DEBUG
  let isUseConsoleLog: Bool = true
  #else
  let isUseConsoleLog: Bool = false
  #endif
  #endif
  
  TinyLog.queue.sync(execute: DispatchWorkItem(block: {
    if let msg = msg {
      if let filterString = TinyLog.filterString, !filterString.isEmpty {
        if "\(msg)".contains(filterString) {
          if isUseConsoleLog {
            print("\(prefix) \(fileName(file)).\(TinyLog.stripParameters ? functionNameByStrippingParameters(function) : function):\(line) - \(msg)")
          }
        }
      } else {
        if isUseConsoleLog {
          print("\(prefix) \(fileName(file)).\(TinyLog.stripParameters ? functionNameByStrippingParameters(function) : function):\(line) - \(msg)")
        }
      }
    } else {
      if isUseConsoleLog {
        print("\(prefix) \(fileName(file)).\(TinyLog.stripParameters ? functionNameByStrippingParameters(function) : function):\(line)")
      }
    }
  }))
}

public func logi(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowInfoLog { log(msg, "????", file, function, line) }
}

public func logv(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowInfoLog { log(msg, "???", file, function, line) } // I put a black circle instead of black heart since it's available from iOS 10.2.
}

public func logd(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowInfoLog { log(msg, "???", file, function, line) }
}

public func logw(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowErrorLog {
    log(msg, "????", file, function, line)
  }
}

public func loge(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowErrorLog {
    log(msg, "????", file, function, line)
  }
}

public func logc(_ msg: Any? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowErrorLog {
    log(msg, "????", file, function, line)
  }
}

public func logPrettyJsonData(_ jsonData: Any?, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    if TinyLog.isShowInfoLog {
        if let data = jsonData as? Data {
            guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
                  let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return }
            log("\(prettyPrintedString as AnyObject)", "???", file, function, line)
        }
    }
}

public func logPrettyJsonString(_ jsonData: Any?, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
    if TinyLog.isShowInfoLog {
        if let jsonString = jsonData as? String, let data = jsonString.data(using: .utf8), let prettyJson = data.prettyJson {
            log("\(prettyJson as AnyObject)", "???", file, function, line)
        }
    }
}

func logDict(_ dict: Any?, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
  if TinyLog.isShowInfoLog {
    if let dict = dict as? Dictionary<AnyHashable, Any> {
      log("\(dict as AnyObject)", "???", file, function, line)
    }
  }
}

fileprivate extension Data {
    var prettyJson: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding:.utf8) else { return nil }
        
        return prettyPrintedString
    }
}
