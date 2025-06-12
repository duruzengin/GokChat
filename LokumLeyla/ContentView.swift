// SwiftUI UDP Chat using Network.framework for macOS
// Save this as ContentView.swift in a SwiftUI macOS Xcode project

import SwiftUI
import Network

class UDPChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var remoteIP: String = ""

    private let port: NWEndpoint.Port = 12345
    private var listener: NWListener?

    init() {
        loadMessages()
        startListening()
    }

    func startListening() {
        do {
            listener = try NWListener(using: .udp, on: port)
        } catch {
            print("Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] newConn in
            newConn.start(queue: .main)
            self?.receive(on: newConn)
        }

        listener?.start(queue: .main)
    }

    func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, _, _, error) in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let chatMessage = ChatMessage(content: message, isSentByMe: false, timestamp: Date())
                    self?.messages.append(chatMessage)
                    self?.saveMessages()
                }
            }
            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    func send(message: String) {
        guard let ip = IPv4Address(remoteIP) else { return }
        let endpoint = NWEndpoint.hostPort(host: .ipv4(ip), port: port)
        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: .main)

        let data = message.data(using: .utf8) ?? Data()
        connection.send(content: data, completion: .contentProcessed({ [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    let chatMessage = ChatMessage(content: message, isSentByMe: true, timestamp: Date())
                    self?.messages.append(chatMessage)
                    self?.saveMessages()
                }
            }
        }))
    }

    func saveMessages() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: "chatMessages")
        }
    }

    func loadMessages() {
        if let data = UserDefaults.standard.data(forKey: "chatMessages"),
           let savedMessages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            self.messages = savedMessages
        }
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id = UUID()
    let content: String
    let isSentByMe: Bool
    let timestamp: Date
}

struct ContentView: View {
    @StateObject var chatManager = UDPChatManager()
    @State private var inputMessage: String = ""
    @Namespace var bottomID

    var body: some View {
        VStack(spacing: 10) {
            TextField("Karşı tarafın IP adresi", text: $chatManager.remoteIP)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chatManager.messages) { message in
                            VStack(alignment: message.isSentByMe ? .trailing : .leading) {
                                Text(message.content)
                                    .padding(10)
                                    .foregroundColor(.white)
                                    .background(message.isSentByMe ? Color.blue : Color.pink)
                                    .cornerRadius(10)
                                    .frame(maxWidth: .infinity, alignment: message.isSentByMe ? .trailing : .leading)
                                Text(formattedDate(message.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: message.isSentByMe ? .trailing : .leading)
                            }
                        }
                        Spacer().id(bottomID)
                    }
                    .padding(.horizontal, 10)
                    .onChange(of: chatManager.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(minHeight: 300)

            HStack {
                TextField("Mesaj yaz...", text: $inputMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        sendMessage()
                    }

                Button("Gönder") {
                    sendMessage()
                }
                .disabled(inputMessage.isEmpty || chatManager.remoteIP.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
    }

    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        chatManager.send(message: inputMessage.trimmingCharacters(in: .whitespaces))
        inputMessage = ""
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
