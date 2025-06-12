import SwiftUI

struct ContentView: View {
    @StateObject private var delt = DeviceDelegate()
    @State private var isDownloadingAll = false
    @State private var bulkStatus: String = ""
    @State private var selectedVideoID: String?

    var body: some View {
        VStack {
            if let deviceName = delt.connectedDeviceName {
                Text("Connected Device: \(deviceName)")
                    .font(.headline)
                    .padding(.bottom, 8)
            } else {
                Text("No device connected")
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }

            Button("Download All Videos") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.prompt = "Choose Folder"
                panel.begin { resp in
                    guard resp == .OK, let dir = panel.url else { return }
                    isDownloadingAll = true
                    bulkStatus = "Starting download..."
                    delt.downloadAll(to: dir, progress: { done, total in
                        bulkStatus = "Downloaded \(done) of \(total)"
                    }, completion: { errors in
                        isDownloadingAll = false
                        if errors.contains(where: { $0 != nil }) {
                            print("Errors: \(errors)")
                            bulkStatus = "Completed with some errors"
                        } else {
                            bulkStatus = "All downloads completed!"
                        }
                    })
                }
            }
            .disabled(isDownloadingAll)

            if isDownloadingAll {
                ProgressView(bulkStatus)
                    .padding(.vertical)
            } else if !bulkStatus.isEmpty {
                Text(bulkStatus)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}
