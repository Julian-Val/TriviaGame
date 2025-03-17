//
//  ContentView.swift
//  TriviaGame
//
//  Created by Julian Valencia on 3/15/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var triviaManager = TriviaManager()
    
    @State private var numberOfQuestionsText = "10"
    @State private var selectedCategory: Int = 0
    @State private var difficultyValue = 1.0
    @State private var selectedType: TriviaType = .any
    @State private var timerDuration = 120
    @State private var showingTrivia = false
    
    @State private var selectedAnswers: [UUID: String] = [:]
    @State private var timeRemaining = 120
    @State private var isTimerRunning = false
    @State private var answersSubmitted = false
    @State private var showScorePopup = false
    @State private var showTimeUpAlert = false
    @State private var score: (score: Int, total: Int) = (0, 0)
    @State private var alertType: AlertType = .none
    
    enum AlertType {
        case none
        case score
        case timeUp
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            if showingTrivia {
                VStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 8)
                            .opacity(0.3)
                            .foregroundColor(Color.gray)
                        
                        Rectangle()
                            .frame(width: CGFloat(timeRemaining) / CGFloat(timerDuration) * UIScreen.main.bounds.width, height: 8)
                            .foregroundColor(timerColor)
                    }
                    .cornerRadius(4)
                    .padding(.horizontal)
                    
                    Text("\(timeFormatted(timeRemaining))")
                        .font(.caption)
                        .foregroundColor(timerColor)
                        .padding(.bottom, 8)
                    
                    List {
                        ForEach(triviaManager.questions) { question in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(question.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(question.difficulty.capitalized)
                                        .font(.caption)
                                        .padding(5)
                                        .background(difficultyColor(question.difficulty).opacity(0.2))
                                        .cornerRadius(5)
                                }
                                
                                Text(question.question)
                                    .font(.headline)
                                    .padding(.vertical, 8)
                                
                                VStack(spacing: 8) {
                                    ForEach(question.allAnswers, id: \.self) { answer in
                                        Button(action: {
                                            if !answersSubmitted {
                                                selectAnswer(question: question, answer: answer)
                                            }
                                        }) {
                                            HStack {
                                                Text(answer)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                
                                                if answersSubmitted {
                                                    if answer == question.correctAnswer {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                    } else if selectedAnswers[question.id] == answer {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                } else if selectedAnswers[question.id] == answer {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(getBorderColor(question: question, answer: answer), lineWidth: 1)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(getAnswerBackgroundColor(question: question, answer: answer))
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Button(action: submitAnswers) {
                        Text("Submit Answers")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .disabled(answersSubmitted)
                }
                .navigationTitle("Trivia Challenge")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading: Button("Back") {
                    resetGame()
                })
                .onReceive(timer) { _ in
                    if isTimerRunning && timeRemaining > 0 {
                        timeRemaining -= 1
                        if timeRemaining == 0 {
                            alertType = .timeUp
                            showScorePopup = true
                            isTimerRunning = false
                        }
                    }
                }
                .onAppear {
                    isTimerRunning = true
                }
                .sheet(isPresented: $showScorePopup) {
                    if alertType == .score {
                        ScorePopupView(score: score, onDismiss: {
                            showScorePopup = false
                        })
                    } else if alertType == .timeUp {
                        TimeUpPopupView(onSubmit: {
                            submitAnswers()
                            showScorePopup = false
                        })
                    }
                }
            } else {
                VStack {
                    Form {
                        Section(header: Text("Trivia Options")) {
                            HStack {
                                Text("Number of Questions:")
                                Spacer()
                                TextField("1-50", text: $numberOfQuestionsText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            if triviaManager.categories.isEmpty {
                                HStack {
                                    Text("Categories")
                                    Spacer()
                                    ProgressView()
                                }
                            } else {
                                Picker("Category", selection: $selectedCategory) {
                                    Text("Any Category").tag(0)
                                    ForEach(triviaManager.categories) { category in
                                        Text(category.name).tag(category.id)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Difficulty")
                                HStack {
                                    Text("Easy")
                                        .font(.caption)
                                    Slider(value: $difficultyValue, in: 0...2, step: 1)
                                    Text("Hard")
                                        .font(.caption)
                                }
                                HStack {
                                    Spacer()
                                    Text(selectedDifficulty.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Picker("Question Type", selection: $selectedType) {
                                ForEach(TriviaType.allCases) { type in
                                    Text(type.name).tag(type)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Timer Duration: \(timerDuration) seconds")
                                Slider(value: Binding(
                                    get: { Double(timerDuration) },
                                    set: { timerDuration = Int($0) }
                                ), in: 30...300, step: 30)
                            }
                        }
                        
                        Section {
                            Button(action: startGame) {
                                HStack {
                                    Spacer()
                                    if triviaManager.isLoading {
                                        ProgressView()
                                            .padding(.trailing, 5)
                                    }
                                    Text("Start Trivia Game")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                            }
                            .disabled(triviaManager.isLoading)
                        }
                    }
                    
                    if let error = triviaManager.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .navigationTitle("Trivia Challenge")
            }
        }
    }
    
    private var selectedDifficulty: TriviaDifficulty {
        switch Int(difficultyValue) {
        case 0:
            return .easy
        case 1:
            return .medium
        case 2:
            return .hard
        default:
            return .any
        }
    }
    
    private func startGame() {
        guard let numQuestions = Int(numberOfQuestionsText), numQuestions > 0, numQuestions <= 50 else {
            triviaManager.errorMessage = "Please enter a valid number of questions (1-50)"
            return
        }
        
        timeRemaining = timerDuration
        
        triviaManager.fetchTrivia(
            amount: numQuestions,
            category: selectedCategory,
            difficulty: selectedDifficulty,
            type: selectedType
        ) { success in
            if success {
                showingTrivia = true
            }
        }
    }
    
    private func selectAnswer(question: TriviaQuestion, answer: String) {
        selectedAnswers[question.id] = answer
        
        if let index = triviaManager.questions.firstIndex(where: { $0.id == question.id }) {
            var updatedQuestion = triviaManager.questions[index]
            updatedQuestion.userAnswer = answer
            triviaManager.questions[index] = updatedQuestion
        }
    }
    
    private func submitAnswers() {
        score = triviaManager.calculateScore()
        answersSubmitted = true
        isTimerRunning = false
        
        alertType = .score
        showScorePopup = true
    }
    
    private func resetGame() {
        showingTrivia = false
        answersSubmitted = false
        selectedAnswers = [:]
        timeRemaining = timerDuration
        isTimerRunning = false
        alertType = .none
    }
    
    private func getAnswerBackgroundColor(question: TriviaQuestion, answer: String) -> Color {
        if !answersSubmitted {
            return selectedAnswers[question.id] == answer ? Color.blue.opacity(0.1) : Color.white
        } else {
            if answer == question.correctAnswer {
                return Color.green.opacity(0.2)
            } else if selectedAnswers[question.id] == answer {
                return Color.red.opacity(0.2)
            } else {
                return Color.white
            }
        }
    }
    
    private func getBorderColor(question: TriviaQuestion, answer: String) -> Color {
        if !answersSubmitted {
            return selectedAnswers[question.id] == answer ? Color.blue : Color.gray
        } else {
            if answer == question.correctAnswer {
                return Color.green
            } else if selectedAnswers[question.id] == answer {
                return Color.red
            } else {
                return Color.gray
            }
        }
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy":
            return Color.green
        case "medium":
            return Color.orange
        case "hard":
            return Color.red
        default:
            return Color.gray
        }
    }
    
    private func timeFormatted(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timerColor: Color {
        let quarterTime = timerDuration / 4
        let halfTime = timerDuration / 2
        
        if timeRemaining < quarterTime {
            return .red
        } else if timeRemaining < halfTime {
            return .orange
        } else {
            return .green
        }
    }
}

struct ScorePopupView: View {
    let score: (score: Int, total: Int)
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quiz Results")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You got \(score.score) out of \(score.total) questions correct!")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Your score: \(Int((Double(score.score) / Double(score.total)) * 100))%")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
            
            Button("OK") {
                onDismiss()
            }
            .padding()
            .frame(minWidth: 100)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 20)
        }
        .padding(30)
    }
    
    private var scoreColor: Color {
        let percentage = Double(score.score) / Double(score.total)
        if percentage >= 0.8 {
            return .green
        } else if percentage >= 0.6 {
            return .blue
        } else if percentage >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimeUpPopupView: View {
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Time's Up!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your answers will be automatically submitted.")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button("See Results") {
                onSubmit()
            }
            .padding()
            .frame(minWidth: 100)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 20)
        }
        .padding(30)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
