import Foundation

class ReservationAPIService {
    static let shared = ReservationAPIService()
    
    private var baseURL: String {
        return AppConfig.shared.apiBaseURL
    }
    private let getReservationsEndpoint = "/get-reservations"
    private let saveReservationEndpoint = "/save-reservation"
    private let updateReservationStatusEndpoint = "/update-reservation-status"
    private let deleteReservationEndpoint = "/delete-reservation"
    
    private init() {}
    
    func getReservations(completion: @escaping ([Reservation]?, Error?) -> Void) {
        guard let url = URL(string: baseURL + getReservationsEndpoint) else {
            completion(nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("casanova-reserve-app-key", forHTTPHeaderField: "x-api-key")  // Added required API key
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "No data received", code: 500, userInfo: nil))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let reservations = try decoder.decode([Reservation].self, from: data)
                completion(reservations, nil)
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    func updateReservationStatus(reservation: Reservation, status: ReservationStatus, completion: @escaping (Error?) -> Void) {
        guard let reservationId = reservation.id else {
            completion(NSError(domain: "Missing reservation ID", code: 400, userInfo: nil))
            return
        }
        
        // Format date for display
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.locale = Locale(identifier: "fr_FR")
        let formattedDate = dateFormatter.string(from: reservation.date)
        
        // Create URL with real customer data
        var urlComponents = URLComponents(string: "\(baseURL)/ios-confirm.html")!
        urlComponents.queryItems = [
            URLQueryItem(name: "auto", value: "true"),
            URLQueryItem(name: "id", value: reservationId),
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "apikey", value: "casanova-reserve-app-key"),
            // Real customer data
            URLQueryItem(name: "name", value: reservation.name),
            URLQueryItem(name: "email", value: reservation.email),
            URLQueryItem(name: "phone", value: reservation.phone),
            URLQueryItem(name: "date", value: formattedDate),
            URLQueryItem(name: "time", value: reservation.time),
            URLQueryItem(name: "guests", value: "\(reservation.numberOfPeople)"),
            URLQueryItem(name: "notes", value: reservation.specialRequests ?? "Aucune note")
        ]
        
        guard let url = urlComponents.url else {
            completion(NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Use GET request for static HTML page
        request.addValue("text/html", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(NSError(domain: "Invalid response", code: 500, userInfo: nil))
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Parse response to get detailed status
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   let message = json["message"] as? String {
                    
                    if success {
                        print("✅ \(message)")
                        print("✅ Reservation \(reservationId) status updated to \(status.rawValue)")
                        
                        if let emailSent = json["emailSent"] as? Bool, emailSent {
                            print("✅ Confirmation email sent successfully")
                        } else {
                            print("⚠️ Firestore updated but email sending failed")
                        }
                    }
                }
                completion(nil)
            } else {
                completion(NSError(domain: "HTTP Error \(httpResponse.statusCode)", code: httpResponse.statusCode, userInfo: nil))
            }
        }.resume()
    }
    
    func deleteReservation(reservationId: String, completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: baseURL + deleteReservationEndpoint) else {
            completion(NSError(domain: "Invalid URL", code: 400, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("casanova-reserve-app-key", forHTTPHeaderField: "x-api-key")  // Added required API key
        
        let body: [String: Any] = [
            "id": reservationId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }
}
