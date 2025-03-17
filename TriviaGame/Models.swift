//
//  Models.swift
//  TriviaGame
//
//  Created by Julian Valencia on 3/15/25.
//

import Foundation

enum TriviaDifficulty: String, CaseIterable {
    case any = "any"
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var name: String {
        switch self {
        case .any: return "Any Difficulty"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

enum TriviaType: String, CaseIterable, Identifiable {
    case any = "any"
    case multiple = "multiple"
    case boolean = "boolean"
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .any: return "Any Type"
        case .multiple: return "Multiple Choice"
        case .boolean: return "True/False"
        }
    }
}

struct CategoryResponse: Codable {
    let triviaCategories: [APICategory]
    
    enum CodingKeys: String, CodingKey {
        case triviaCategories = "trivia_categories"
    }
}

struct APICategory: Codable, Identifiable {
    let id: Int
    let name: String
}

struct TriviaResponse: Codable {
    let responseCode: Int
    let results: [TriviaQuestion]
    
    enum CodingKeys: String, CodingKey {
        case responseCode = "response_code"
        case results
    }
}

struct TriviaQuestion: Codable, Identifiable {
    var id = UUID()
    var userAnswer: String?
    
    private let cachedAllAnswers: [String]
    
    let category: String
    let type: String
    let difficulty: String
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]
    
    var allAnswers: [String] {
        return cachedAllAnswers
    }
    
    init(category: String, type: String, difficulty: String, question: String, correctAnswer: String, incorrectAnswers: [String], id: UUID = UUID(), userAnswer: String? = nil) {
        self.category = category
        self.type = type
        self.difficulty = difficulty
        self.question = question
        self.correctAnswer = correctAnswer
        self.incorrectAnswers = incorrectAnswers
        self.id = id
        self.userAnswer = userAnswer
        
        var answers = incorrectAnswers
        answers.append(correctAnswer)
        self.cachedAllAnswers = answers.shuffled()
    }
    
    enum CodingKeys: String, CodingKey {
        case category, type, difficulty, question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        category = try container.decode(String.self, forKey: .category)
        type = try container.decode(String.self, forKey: .type)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        question = try container.decode(String.self, forKey: .question)
        correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        incorrectAnswers = try container.decode([String].self, forKey: .incorrectAnswers)
        
        id = UUID()
        userAnswer = nil
        
        var answers = incorrectAnswers
        answers.append(correctAnswer)
        cachedAllAnswers = answers.shuffled()
    }
    
}

extension String {
    var htmlDecoded: String? {
        guard let data = self.data(using: .utf8) else { return nil }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        return attributedString.string
    }
}

class TriviaManager: ObservableObject {
    @Published var questions: [TriviaQuestion] = []
    @Published var categories: [APICategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        fetchCategories()
    }
    
    func fetchCategories() {
        guard let url = URL(string: "https://opentdb.com/api_category.php") else {
            self.errorMessage = "Invalid category URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch categories: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No category data received"
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let categoryResponse = try decoder.decode(CategoryResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.categories = categoryResponse.triviaCategories
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode categories: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchTrivia(amount: Int = 10,
                     category: Int = 0,
                     difficulty: TriviaDifficulty = .any,
                     type: TriviaType = .any,
                     completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        var urlComponents = URLComponents(string: "https://opentdb.com/api.php")!
        
        var queryItems = [URLQueryItem(name: "amount", value: String(amount))]
        
        if category != 0 {
            queryItems.append(URLQueryItem(name: "category", value: String(category)))
        }
        
        if difficulty != .any {
            queryItems.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue))
        }
        
        if type != .any {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let triviaResponse = try decoder.decode(TriviaResponse.self, from: data)
                
                if triviaResponse.responseCode != 0 {
                    DispatchQueue.main.async {
                        self.errorMessage = "API Error: Response code \(triviaResponse.responseCode)"
                        self.isLoading = false
                        completion(false)
                    }
                    return
                }
                
                let cleanedQuestions = triviaResponse.results.map { question -> TriviaQuestion in
                    let decodedQuestion = question.question.htmlDecoded ?? question.question
                    let decodedCorrectAnswer = question.correctAnswer.htmlDecoded ?? question.correctAnswer
                    let decodedIncorrectAnswers = question.incorrectAnswers.map { $0.htmlDecoded ?? $0 }
                    
                    return TriviaQuestion(
                        category: question.category,
                        type: question.type,
                        difficulty: question.difficulty,
                        question: decodedQuestion,
                        correctAnswer: decodedCorrectAnswer,
                        incorrectAnswers: decodedIncorrectAnswers
                    )
                }
                
                DispatchQueue.main.async {
                    self.questions = cleanedQuestions
                    self.isLoading = false
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    self.isLoading = false
                    completion(false)
                }
            }
        }.resume()
    }
    
    func calculateScore() -> (score: Int, total: Int) {
        let correctAnswers = questions.filter { $0.userAnswer == $0.correctAnswer }.count
        return (correctAnswers, questions.count)
    }
}
