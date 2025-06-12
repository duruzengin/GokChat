//
//  ContentView.swift
//  LokumLeyla
//
//  Created by Deniz zengin on 12.06.2025.
//

import SwiftUI

// SwiftUI UDP Chat using Network.framework
// Save this as ContentView.swift in a SwiftUI Xcode project

// SwiftUI UDP Chat using Network.framework
// Save this as ContentView.swift in a SwiftUI Xcode project

import SwiftUI
import Network

class UDPChatManager: ObservableObject {
    @Published var messages: [String] = []
    @Published var remoteIP: String = ""

    private var connection: NWConnection?
    private let port: NWEndpoint.Port = 12345
    private var listener: NWListener?

    init() {
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
                    self?.messages.append("Onlar: \(message)")
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
        connection.send(content: data, completion: .contentProcessed({ error in
            if error == nil {
                DispatchQueue.main.async {
                    self.messages.append("Sen: \(message)")
                }
            }
        }))
    }
}

struct ContentView: View {
    @StateObject var chatManager = UDPChatManager()
    @State private var inputMessage: String = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("Karşı tarafın IP adresi", text: $chatManager.remoteIP)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(chatManager.messages, id: \ .self) { message in
                        Text(message.replacingOccurrences(of: "Sen: ", with: "").replacingOccurrences(of: "Onlar: ", with: ""))
                            .padding(10)
                            .foregroundColor(.white)
                            .background(message.hasPrefix("Sen") ? Color.blue : Color.pink)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: message.hasPrefix("Sen") ? .trailing : .leading)
                            .padding(.horizontal, 10)
                    }
                }
            }.padding(.vertical)

            HStack {
                TextField("Mesaj yaz...", text: $inputMessage, onCommit: {
                    sendMessage()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading)

                Button("Gönder") {
                    sendMessage()
                }
                .disabled(inputMessage.isEmpty || chatManager.remoteIP.isEmpty)
                .padding(.trailing)
            }
            .padding(.bottom)
        }
    }

    func sendMessage() {
        guard !inputMessage.isEmpty else { return }
        chatManager.send(message: inputMessage)
        inputMessage = ""
    }
}

#Preview {
    ContentView()
}
