//
//  RatesDetailModel.swift
//  Calc
//
//

import Foundation

struct RatesDetailModel: Decodable {
    let base: String
    let date: String
    let rates: RateDetail
    
}

struct RateDetail: Decodable {
    
    typealias DestinationCurrency = String
    let currency : DestinationCurrency
    let value : Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String:Double].self)
        guard let key = dict.keys.first else {
            throw NSError(domain: "Decoder", code: 0, userInfo: [:])
        }
        currency = key
        value = dict[key] ?? -1
    }
}
