import Foundation

// Перечисление поддерживаемых HTTP методов
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
    case patch = "PATCH"
}

final class NetworkManager {
    
    // Общий URLSession для всех сетевых запросов
    static let session = URLSession(configuration: URLSessionConfiguration.default)
    
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    static let encoder: JSONEncoder = {
         let encoder = JSONEncoder()
         encoder.keyEncodingStrategy = .convertToSnakeCase
         return encoder
     }()
    
    // Замыкание для получения access token
    var accessTokenProvider: (() -> String?)?
    
    // Создает базовый URLRequest с указанным путем и токеном авторизации
    func request(path: String) throws -> URLRequest {
        let baseURL = "https://baseURL"
        let urlString = baseURL + path
        
        guard let url = URL(string: urlString) else {
            throw APIError(message: "Invalid network path")
        }
    
        var request = URLRequest(url: url)
        
        // Добавляем токен авторизации в заголовки, если он доступен
        if let token = accessTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

extension URLRequest {
    // Выполняет запрос и декодирует ответ в указанный тип
    func runAndDecode<T: Decodable>(type: T.Type = T.self) async throws -> T {
        let data = try await run()
        let response = try NetworkManager.decoder.decode(APIResponse<T>.self, from: data)
        return response.data
    }
    
    // Выполняет запрос и возвращает полученные данные
    @discardableResult
    func run() async throws -> Data {
        let (data, response) = try await NetworkManager.session.data(for: self)
        try validate(response: response)
        return data
    }
    
    // Проверяет статус код HTTP ответа
    private func validate(response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            return
        }
        
        let validStatusCodes = 200...299
        let statusCodeIsValid = validStatusCodes.contains(response.statusCode)
        
        if !statusCodeIsValid {
            throw APIError(message: "Invalid status code: \(response.statusCode)")
        }
    }
    
    // Добавляет тело запроса и устанавливает HTTP метод
    func withBody<T: Encodable>(_ body: T, method: HTTPMethod) throws -> URLRequest {
        var request = self
        request.httpMethod = method.rawValue
        request.httpBody = try NetworkManager.encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    // Добавляет параметр запроса в URL
    func withQuery(name: String, value: String) -> URLRequest {
        guard var urlComponents = URLComponents(url: url!, resolvingAgainstBaseURL: true) else {
            return self
        }
        
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: name, value: value))
        urlComponents.queryItems = queryItems
        var request = self
        request.url = urlComponents.url
        return request
    }
    
    // Устанавливает HTTP метод запроса
    func withMethod(_ method: HTTPMethod) throws -> URLRequest {
        var request = self
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

// Пример использования
/*
    func getProfiles() async throws -> [Profile] {
       try await networkManager
            .request(path: "/v0/profile")
            .runAndDecode()
    }
*/


