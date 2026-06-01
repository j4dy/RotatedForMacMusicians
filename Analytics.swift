import Foundation

class AppAnalytics {
    static let shared = AppAnalytics()
    
    private let measurementID = "G-CGXT9FXJJ7"
    
    // An API Secret must be generated under Admin > Data Streams > Measurement Protocol API secrets
    // If you don't have an API Secret set up, you can leave this blank, but events might be filtered by GA.
    private let apiSecret = "YOUR_API_SECRET_VALUE"
    
    private var clientID: String {
        if let saved = UserDefaults.standard.string(forKey: "analytics_client_id") {
            return saved
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "analytics_client_id")
        return newID
    }
    
    /// Tracks custom desktop events via the Google Analytics v4 Measurement Protocol
    func trackEvent(name: String, parameters: [String: Any] = [:]) {
        let urlString = "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementID)&api_secret=\(apiSecret)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var eventParams = parameters
        eventParams["engagement_time_msec"] = 100
        eventParams["session_id"] = String(Int(Date().timeIntervalSince1970))
        eventParams["platform"] = "macOS"
        
        let payload: [String: Any] = [
            "client_id": clientID,
            "events": [
                [
                    "name": name,
                    "params": eventParams
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // Fire-and-forget asynchronous collection
            URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
        } catch {
            print("Failed to serialize analytics event: \(error)")
        }
    }
    
    /// Tracks screen views in the digital stand interface
    func trackScreenView(screenName: String) {
        trackEvent(name: "screen_view", parameters: [
            "firebase_screen": screenName,
            "firebase_screen_class": screenName
        ])
    }
}
