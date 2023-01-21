//
//  Settings.swift
// 
//
//

class GlobalSettings {
    static let shared = GlobalSettings()

    // Rates Exchange API key [YOUR_API_KEY]
    // Get your own api key from https://ratesexchange.eu
    // It's totally free!
    let ratesExchangeApiKey = "f1895751-49b0-4bb4-9d59-6964f1572c72"
}

struct Routes {
    private static let s = GlobalSettings.shared
    
    static let apiBaseUrl = "https://api.ratesexchange.eu/client"
    static let apiCheckOnLine = "\(apiBaseUrl)/checkapi"
    static let apiKeyParam = "?apiKey=\(s.ratesExchangeApiKey)"
    static let latestDetailedRatesUri = "\(apiBaseUrl)/latestdetails\(apiKeyParam)"
    static let currenciesUri = "\(apiBaseUrl)/currencies\(apiKeyParam)"
    static let convertRatesUri = "\(apiBaseUrl)/latest\(apiKeyParam)"
    static let currencyHistoryRatesUri = "\(apiBaseUrl)/historydates\(apiKeyParam)"
    static let historyRatesForCurrency = "\(apiBaseUrl)/historydetails\(apiKeyParam)"
}
