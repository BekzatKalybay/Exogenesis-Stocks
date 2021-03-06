//
//  APIManager.swift
//  EG Stocks
//
//  Created by Bekzat Kalybayev on 23.02.2022.
//

import Foundation

/// Object to manage API calls
final class APIManager {
    /// Singleton
    public static let shared = APIManager()
    
    /// Constants
    private struct Constants {
        static let apiKey = "c8b6rpiad3ieig9ouup0"
        static let sandboxApiKey = "sandbox_c8b6rpiad3ieig9ouupg"
        static let baseUrl = "https://finnhub.io/api/v1/"
        static let day: TimeInterval = 3600 * 24
    }
    
    /// Private constructor
    private init() {}
    
    //MARK: - Public
    
    /// Search for a company
    /// - Parameters:
    ///   - query: Query string (symbol or name)
    ///   - compleation: Callback for result
    public func search(
        query: String,
        compleation: @escaping (Result<SearchResponse, Error>) -> Void
    ) {
        // This (safeQuery) allows to use spaces while typing
        guard let safeQuery = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) else { return }
        request(
            url: url(for: .search, queryParams: ["q":safeQuery]),
            expecting: SearchResponse.self,
            completion: compleation)
    }
    
    /// Gets news for type
    /// - Parameters:
    ///   - type: Company or top stories
    ///   - completion: Result callback
    public func news(
        for type: NewsViewController.`Type`,
        completion: @escaping (Result<[NewsStory], Error>) -> Void
    ) {
        switch type {
        case .topStories:
            request(url: url(for: .topStories, queryParams: ["category": "general"]),
                    expecting: [NewsStory].self,
                    completion: completion
            )
        case .company(let symbol):
            let today = Date()
            let oneMonthBack = today.addingTimeInterval(-(Constants.day * 7))
            request(url: url(
                for: .companyNews,
                   queryParams: [
                    "symbol": symbol,
                    "from": DateFormatter.newsDateFormatter.string(from: oneMonthBack),
                    "to": DateFormatter.newsDateFormatter.string(from: today)
                   ]
            ),
                    expecting: [NewsStory].self,
                    completion: completion
            )
        }
    }
    
    /// Gets market data
    /// - Parameters:
    ///   - symbol: Given symbol
    ///   - numberOfDays: Number of days back from today
    ///   - completion: Result callback
    public func marketData(
        for symbol: String,
        numberOfDays: TimeInterval = 7,
        completion: @escaping (Result<MarketDataResponse, Error>) -> Void
    ) {
        // Important to give yesterday's date to get data
        let today = Date().addingTimeInterval(-(Constants.day))
        let prior = today.addingTimeInterval(-(Constants.day * numberOfDays))
        request(
            url: url(
                for: .marketData,
                queryParams: [
                    "symbol": symbol,
                    "resolution": "1",
                    "from": "\(Int(prior.timeIntervalSince1970))",
                    "to": "\(Int(today.timeIntervalSince1970))"
                ]
            ),
            expecting: MarketDataResponse.self,
            completion: completion
        )
    }
    
    /// Gets financial metrics
    /// - Parameters:
    ///   - symbol: Symbol of company
    ///   - completion: Result callback
    public func financialMetrics(
        for symbol: String,
        completion: @escaping (Result<FinancialMetricsResponse, Error>) -> Void
    ) {
        request(
            url: url(for: .financials,
                        queryParams: ["symbol": symbol, "metric": "all"]),
            expecting: FinancialMetricsResponse.self,
            completion: completion)
    }
    
    //MARK: - Private
    
    /// API Endpoints
    private enum Endpoint: String {
        case search
        case topStories = "news"
        case companyNews = "company-news"
        case marketData = "stock/candle"
        case financials = "stock/metric"
    }
    
    /// API Errors
    private enum APIError: Error {
        case noDataReturned
        case invalidUrl
    }
    
    /// Try to create url for endpoint
    /// - Parameters:
    ///   - endpoint: Endpoint to create for
    ///   - queryParams: Additional query arguments
    /// - Returns: Optional URL
    private func url(
        for endpoint: Endpoint,
        queryParams: [String: String] = [:]
    ) -> URL? {
        var ulrString = Constants.baseUrl + endpoint.rawValue
        
        var queryItems = [URLQueryItem]()
        // Add any parameters
        for (name, value) in queryParams {
            queryItems.append(.init(name: name, value: value))
        }
        
        // Add token
        queryItems.append(.init(name: "token", value: Constants.apiKey))
        
        // Convert query items to suffix string
        ulrString += "?" + queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        
        return URL(string: ulrString)
    }
    
    /// Perform API calls
    private func request<T: Codable>(
        url: URL?,
        expecting: T.Type,
        completion: @escaping (Result<T, Error>) -> Void) {
            guard let url = url else {
                // Invalid URL
                completion(.failure(APIError.invalidUrl))
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data = data, error == nil else {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(APIError.noDataReturned))
                    }
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(expecting, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        }
}
